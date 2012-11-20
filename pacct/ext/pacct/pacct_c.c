#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

#include <grp.h>
#include <pwd.h>
#include <unistd.h>
#include <sys/acct.h>
#include <sys/types.h>

#include "ruby.h"

static char const* validFileModes[] = {
  "rb",
  "wb",
  "r+b",
  "w+b",
};

//To do:
//Verify that allocations succeed?

VALUE mPacct;
VALUE cLog;
VALUE cEntry;

//Ruby's Time class
VALUE cTime;
//Ruby's SystemCallError class
VALUE cSystemCallError;

//Identifiers
ID id_at;
ID id_new;
ID id_to_i;

//System parameters
int pageSize;
long ticksPerSecond;

//Converts a comp_t to a long
long comp_t_to_long(comp_t c) {
  return (c & 0x1fff) << (((c >> 13) & 0x7) * 3);
}

//Converts a long to a comp_t
//To do: make sure the value is positive?
//To do: overflow checks?
comp_t long_to_comp_t(long l) {
  size_t bits = 0;
  unsigned long l2 = l;
  while(l2 >>= 1) {
    ++bits;
  }
  if(bits <= 13) {
    return (l & 0x1fff);
  } else {
    size_t div_bits, rem_bits;
    bits -= 13;
    div_bits = bits / 3;
    rem_bits = bits - div_bits * 3;
    if(rem_bits) {
      div_bits += 1;
    }
    return (l >> (bits + rem_bits) & 0x1fff) | ((div_bits & 0x7) << 13);
  }
}

typedef struct {
  FILE* file;
  long numEntries;
} PacctLog;

static VALUE pacct_log_free(void* p) {
  PacctLog* log = (PacctLog*) p;
  if(log->file) {
    fclose(log->file);
    log->file = NULL;
  }
  free(p);
  return Qnil;
}

/*
 *call-seq:
 *  new(filename)
 *
 *Creates a new Pacct::Log using the given accounting file
 */
static VALUE pacct_log_new(int argc, VALUE* argv, VALUE class) {
  VALUE log;
  VALUE init_args[2];
  PacctLog* ptr;
  
  init_args[1] = Qnil;
  rb_scan_args(argc, argv, "11", init_args, init_args + 1);
  
  log = Data_Make_Struct(class, PacctLog, 0, pacct_log_free, ptr);
  
  ptr->file = NULL;
  ptr->numEntries = 0;
  
  rb_obj_call_init(log, 2, init_args);
  return log;
}

//To do: make mode actually do something?
static VALUE pacct_log_init(VALUE self, VALUE filename, VALUE mode) {
  PacctLog* log;
  FILE* acct;
  long length;
  char* cFilename = StringValueCStr(filename);
  const char* cMode = "rb";
  
  if(mode != Qnil) {
    int isValidMode = 0;
    size_t i;
    cMode = StringValueCStr(mode);
    for(i = 0; i < sizeof(validFileModes) / sizeof(char*); ++i) {
      if(strcmp(cMode, validFileModes[i]) == 0) {
        isValidMode = 1;
        break;
      }
    }
    if(!isValidMode) {
      char buf[512];
      snprintf(buf, sizeof(buf), "Invalid mode for Pacct::File: '%s'", cMode);
      rb_raise(rb_eArgError, buf);
    }
  }
  
  acct = fopen(cFilename, cMode);
  if(!acct) {
    char buf[512] = "Unable to open file ";
    size_t len = strlen(buf);
    strncpy(buf + len, cFilename, 511 - len);  
    rb_raise(rb_eIOError, buf);
  }
  
  Data_Get_Struct(self, PacctLog, log);
  
  log->file = acct;
  
  fseek(acct, 0, SEEK_END);
  length = ftell(acct);
  rewind(acct);
  
  if(length % sizeof(struct acct_v3) != 0) {
    rb_raise(rb_eIOError, "Accounting file appears to be the wrong size.");
  }
  
  log->numEntries = length / sizeof(struct acct_v3);
  
  return self;
}

static VALUE pacct_log_close(VALUE self) {
  PacctLog* log;
  
  Data_Get_Struct(self, PacctLog, log);
  
  if(log->file) {
    fclose(log->file);
    log->file = NULL;
  }
}

static VALUE pacct_entry_new(PacctLog* log) {
  VALUE entry;
  struct acct_v3* ptr = ALLOC(struct acct_v3);
  if(log) {
    size_t entriesRead = fread(ptr, sizeof(struct acct_v3), 1, log->file);
    if(entriesRead != 1) {
      rb_raise(rb_eIOError, "Unable to read record from accounting file");
    }
  } else {
    memset(ptr, 0, sizeof(struct acct_v3));
  }
  entry = Data_Wrap_Struct(cEntry, 0, free, ptr);
  
  return entry;
}

//This is the version of pacct_entry_new that is actually exposed to Ruby.
static VALUE ruby_pacct_entry_new(VALUE self) {
  return pacct_entry_new(NULL);
}

/*
 *call-seq:
 *  each_entry([start]) {|entry, index| ...}
 *
 *Yields each entry in the file to the given block and its index in the file
 *
 *If start is given, iteration starts at the entry with that index.
 */
static VALUE each_entry(int argc, VALUE* argv, VALUE self) {
  PacctLog* log;
  VALUE start_value;
  long start = 0;
  int i = 0;
  
  rb_scan_args(argc, argv, "01", &start_value);
  if(argc && start_value != Qnil) {
    start = NUM2INT(start_value);
  }
  
  Data_Get_Struct(self, PacctLog, log);
  
  if(start > log->numEntries) {
    char buf[100];
    snprintf(buf, 100, "Index %li is out of range", start);
    rb_raise(rb_eRangeError, buf);
  }
  
  fseek(log->file, start * sizeof(struct acct_v3), SEEK_SET);
  
  for(i = start; i < log->numEntries; ++i) {
    VALUE entry = pacct_entry_new(log);
    rb_yield_values(2, entry, INT2NUM(i));
  }

  return Qnil;
}

/*
 *Returns the last entry in the file
 */
static VALUE last_entry(VALUE self) {
  PacctLog* log;
  long pos;
  VALUE entry;
  
  Data_Get_Struct(self, PacctLog, log);
  
  if(log->numEntries == 0) {
    return Qnil;
  }
  
  //To do: error checking on file operations?
  pos = ftell(log->file);
  fseek(log->file, -sizeof(struct acct_v3), SEEK_END);
  
  entry = pacct_entry_new(log);
  
  fseek(log->file, pos, SEEK_SET);
  
  return entry;
}

/*
 *Returns the number of entries in the file
 */
static VALUE get_num_entries(VALUE self) {
  PacctLog* log;
  
  Data_Get_Struct(self, PacctLog, log);
  
  return INT2NUM(log->numEntries);
}

/*
 *call-seq:
 *  write_entry(entry)
 *
 * Appends the given entry to the file
 */
static VALUE write_entry(VALUE self, VALUE entry) {
  //To do: verification?
  //To do: unit testing
  PacctLog* log;
  long pos;
  struct acct_v3* acct;
  
  Data_Get_Struct(self, PacctLog, log);
  Data_Get_Struct(entry, struct acct_v3, acct);
  
  pos = ftell(log->file);
  assert(!fseek(log->file, 0, SEEK_END));
  
  //To do: error checking! (also on reads, etc.)
  assert(fwrite(acct, sizeof(struct acct_v3), 1, log->file) == 1);
  
  ++(log->numEntries);
  
  fseek(log->file, pos, SEEK_SET);
  
  return Qnil;
}

//Methods of Pacct::Entry
/*
 *Returns the process ID
 */
static VALUE get_process_id(VALUE self) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  return INT2NUM(data->ac_pid);
}

//Unused
static VALUE set_process_id(VALUE self, VALUE pid) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  data->ac_pid = NUM2INT(pid);
  
  return Qnil;
}

/*
 *Returns the ID of the user who executed the command
 */
static VALUE get_user_id(VALUE self) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  return INT2NUM(data->ac_uid);
}

/*
 *Returns the name of the user who executed the command
 */
static VALUE get_user_name(VALUE self) {
  struct acct_v3* data;
  struct passwd* pw_data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  errno = 0;
  pw_data = getpwuid(data->ac_uid);
  if(!pw_data) {
    char buf[512];
    VALUE err;
    int e = errno;
    snprintf(buf, 512, "Unable to obtain user name for ID %u", data->ac_uid);
    //To do: clearer messages when errno == 0?
    if(e == 0) {
        e = ENODATA;
    }
    err = rb_funcall(cSystemCallError, id_new, 2, rb_str_new2(buf), INT2NUM(e));
    rb_exc_raise(err);
  }
  
  return rb_str_new2(pw_data->pw_name);
}

/*
 *Sets the name of the user who executed the command
 */
static VALUE set_user_name(VALUE self, VALUE name) {
  struct acct_v3* data;
  struct passwd* pw_data;
  char* cName = StringValueCStr(name);
  Data_Get_Struct(self, struct acct_v3, data);
  
  errno = 0;
  pw_data = getpwnam(cName);
  if(!pw_data) {
    char buf[512];
    VALUE err;
    int e = errno;
    snprintf(buf, 512, "Unable to obtain user ID for name '%s'", cName);
    if(e == 0) {
        e = ENODATA;
    }
    err = rb_funcall(cSystemCallError, id_new, 2, rb_str_new2(buf), INT2NUM(e));
    rb_exc_raise(err);
  }
  
  data->ac_uid = pw_data->pw_uid;
  
  return Qnil;
}

/*
 *Returns the group ID of the user who executed the command
 */
static VALUE get_group_id(VALUE self) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  return INT2NUM(data->ac_gid);
}

/*
 *Returns the group name of the user who executed the command
 */
static VALUE get_group_name(VALUE self) {
  struct acct_v3* data;
  struct group* group_data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  errno = 0;
  group_data = getgrgid(data->ac_gid);
  if(!group_data) {
    char buf[512];
    VALUE err;
    int e = errno;
    snprintf(buf, 512, "Unable to obtain group name for ID %u", data->ac_gid);
    if(e == 0) {
      e = ENODATA;
    }
    err = rb_funcall(cSystemCallError, id_new, 2, rb_str_new2(buf), INT2NUM(e));
    rb_exc_raise(err);
  }
  
  return rb_str_new2(group_data->gr_name);
}

/*
 *Sets the group name of the user who executed the command
 */
static VALUE set_group_name(VALUE self, VALUE name) {
  struct acct_v3* data;
  struct group* group_data;
  char* cName = StringValueCStr(name);
  Data_Get_Struct(self, struct acct_v3, data);
  
  errno = 0;
  group_data = getgrnam(cName);
  if(!group_data) {
    char buf[512];
    VALUE err;
    int e = errno;
    snprintf(buf, 512, "Unable to obtain group ID for name '%s'", cName);
    if(e == 0) {
      e = ENODATA;
    } 
    err = rb_funcall(cSystemCallError, id_new, 2, rb_str_new2(buf), INT2NUM(e));
    rb_exc_raise(err);
  }
  
  data->ac_gid = group_data->gr_gid;
  
  return Qnil;
}

/*
 *Returns the task's total user CPU time in seconds
 */
static VALUE get_user_time(VALUE self) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  return INT2NUM(comp_t_to_long(data->ac_utime) / ticksPerSecond);
}

/*
 *Sets the task's total user CPU time
 */
static VALUE set_user_time(VALUE self, VALUE value) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  data->ac_utime = long_to_comp_t(NUM2LONG(value) * ticksPerSecond);
  
  return Qnil;
}

/*
 *Returns the task's total system CPU time in seconds
 */
static VALUE get_system_time(VALUE self) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  return INT2NUM(comp_t_to_long(data->ac_stime) / ticksPerSecond);
}

/*
 *Sets the task's total system CPU time
 */
static VALUE set_system_time(VALUE self, VALUE value) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  data->ac_stime = long_to_comp_t(NUM2LONG(value) * ticksPerSecond);
  
  return Qnil;
}

/*
 *Returns the task's total CPU time in seconds
 */
static VALUE get_cpu_time(VALUE self) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  return INT2NUM((comp_t_to_long(data->ac_utime) + comp_t_to_long(data->ac_stime)) / ticksPerSecond);
}

/*
 *Returns the task's total wall time in seconds
 */
static VALUE get_wall_time(VALUE self) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  return rb_float_new(data->ac_etime);
}

/*
 *Sets the task's total wall time
 */
static VALUE set_wall_time(VALUE self, VALUE value) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  data->ac_etime = NUM2DBL(value);
  
  return Qnil;
}

/*
 *Returns the task's start time
 */
static VALUE get_start_time(VALUE self) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  return rb_funcall(cTime, id_at, 1, INT2NUM(data->ac_btime));
}

/*
 *Sets the task's start time
 */
static VALUE set_start_time(VALUE self, VALUE value) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  data->ac_btime = NUM2INT(rb_funcall(value, id_to_i, 0));
  
  return Qnil;
}

/*
 *Returns the task's average memory usage in kilobytes
 */
static VALUE get_average_mem_usage(VALUE self) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  //Why divided by page size?
  return INT2NUM(comp_t_to_long(data->ac_mem) * 1024 / pageSize);
}

/*
 *Sets the task's average memory usage in kilobytes
 */
static VALUE set_average_mem_usage(VALUE self, VALUE value) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  data->ac_mem = long_to_comp_t(NUM2LONG(value) * pageSize / 1024);
  
  return Qnil;
}

/*
 *Returns the first 15 characters of the command name
 */
static VALUE get_command_name(VALUE self) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  return rb_str_new2(data->ac_comm);
}

/*
 *Sets the first 15 characters of the command name
 */
static VALUE set_command_name(VALUE self, VALUE name) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  strncpy(data->ac_comm, StringValueCStr(name), ACCT_COMM - 1);
  data->ac_comm[ACCT_COMM - 1] = '\0';
  
  return Qnil;
}

/*
 *Returns the command's exit code
 */
static VALUE get_exit_code(VALUE self) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  return INT2NUM(data->ac_exitcode);
}

/*
 *Sets the command's exit code
 */
static VALUE set_exit_code(VALUE self, VALUE value) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  data->ac_exitcode = NUM2INT(value);
  
  return Qnil;
}

void Init_pacct_c() {
  //Get system parameters
  pageSize = getpagesize();
  ticksPerSecond = sysconf(_SC_CLK_TCK);

  //Get Ruby objects.
  cTime = rb_eval_string("Time");
  cSystemCallError = rb_eval_string("SystemCallError");
  id_at = rb_intern("at");
  id_new = rb_intern("new");
  id_to_i = rb_intern("to_i");

  //Define Ruby modules/objects/methods.
  mPacct = rb_define_module("Pacct");
  /*
   *Represents an accounting file in acct(5) format
   */
  cLog = rb_define_class_under(mPacct, "Log", rb_cObject);
  /*
   *Document-class: Pacct::Entry
   *
   *Represents an entry in a Pacct::File
   */
  cEntry = rb_define_class_under(mPacct, "Entry", rb_cObject);
  rb_define_singleton_method(cLog, "new", pacct_log_new, -1);
  rb_define_method(cLog, "initialize", pacct_log_init, 2);
  rb_define_method(cLog, "each_entry", each_entry, -1);
  rb_define_method(cLog, "last_entry", last_entry, 0);
  rb_define_method(cLog, "num_entries", get_num_entries, 0);
  rb_define_method(cLog, "write_entry", write_entry, 1);
  rb_define_method(cLog, "close", pacct_log_close, 0);
  
  rb_define_singleton_method(cEntry, "new", ruby_pacct_entry_new, 0);
  rb_define_method(cEntry, "process_id", get_process_id, 0);
  rb_define_method(cEntry, "process_id=", set_process_id, 1);
  rb_define_method(cEntry, "user_id", get_user_id, 0);
  rb_define_method(cEntry, "user_name", get_user_name, 0);
  rb_define_method(cEntry, "user_name=", set_user_name, 1);
  rb_define_method(cEntry, "group_id", get_group_id, 0);
  rb_define_method(cEntry, "group_name", get_group_name, 0);
  rb_define_method(cEntry, "group_name=", set_group_name, 1);
  rb_define_method(cEntry, "user_time", get_user_time, 0);
  rb_define_method(cEntry, "user_time=", set_user_time, 1);
  rb_define_method(cEntry, "system_time", get_system_time, 0);
  rb_define_method(cEntry, "system_time=", set_system_time, 1);
  rb_define_method(cEntry, "cpu_time", get_cpu_time, 0);
  rb_define_method(cEntry, "wall_time", get_wall_time, 0);
  rb_define_method(cEntry, "wall_time=", set_wall_time, 1);
  rb_define_method(cEntry, "start_time", get_start_time, 0);
  rb_define_method(cEntry, "start_time=", set_start_time, 1);
  rb_define_method(cEntry, "memory", get_average_mem_usage, 0);
  rb_define_method(cEntry, "memory=", set_average_mem_usage, 1);
  rb_define_method(cEntry, "exit_code", get_exit_code, 0);
  rb_define_method(cEntry, "exit_code=", set_exit_code, 1);
  rb_define_method(cEntry, "command_name", get_command_name, 0);
  rb_define_method(cEntry, "command_name=", set_command_name, 1);
}