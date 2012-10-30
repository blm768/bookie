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

//To do:
//Verify that allocations succeed?

VALUE mPacct;
VALUE cFile;
VALUE cEntry;

//Ruby's Time class
VALUE cTime;
//Ruby's SystemCallError class
VALUE cSystemCallError;

//Identifiers
ID id_at;
ID id_new;

//System parameters
int pageSize;
long ticksPerSecond;

//Converts a comp_t to a long
long comp_t_to_long(comp_t c) {
  return (c & 0x1fff) << (((c >> 13) & 0x7) * 3);
}

//Converts a comp_t to a Ruby number
VALUE comp_t_to_num(comp_t c) {
  return INT2NUM(comp_t_to_long(c));
}

//Called when an exception is thrown in the block passed to each_entry()
//This doesn't really seem to be needed, but it seems safer to have it.
VALUE rescue(VALUE args, VALUE exception) {
  rb_exc_raise(exception);
  
  assert(0);
}

typedef struct {
  FILE* file;
  long numEntries;
} PacctFile;

static VALUE pacct_file_free(void* p) {
  PacctFile* file = (PacctFile*) p;
  if(file->file)
    {fclose(file->file);}
  free(p);
  return Qnil;
}

/*
 *call-seq:
 *  new(filename)
 *
 *Creates a new Pacct::File using the given accounting file
 */
static VALUE pacct_file_new(VALUE class, VALUE filename) {
  VALUE file;
  PacctFile* ptr;// = ALLOC(PacctFile);
  file = Data_Make_Struct(class, PacctFile, 0, pacct_file_free, ptr);
  
  rb_obj_call_init(file, 1, &filename);
  return file;
}

static VALUE pacct_file_init(VALUE self, VALUE filename) {
  PacctFile* file;
  long length;
  char* cFilename = StringValueCStr(filename);
  FILE* acct = fopen(cFilename, "r+b");
  //If that didn't work, try to create the file.
  if(!acct) {
    acct = fopen(cFilename, "w+b");
  }
  //If that didn't work either, we have a problem.
  if(!acct) {
    char buf[512] = "Unable to open file ";
    size_t len = strlen(buf);
    strncpy(buf + len, cFilename, 511 - len);  
    rb_raise(rb_eIOError, buf);
  }
  
  Data_Get_Struct(self, PacctFile, file);
  
  file->file = acct;
  
  fseek(acct, 0, SEEK_END);
  length = ftell(acct);
  rewind(acct);
  
  if(length % sizeof(struct acct_v3) != 0) {
    fclose(file->file);
    rb_raise(rb_eIOError, "Accounting file appears to be the wrong size.");
  }
  
  file->numEntries = length / sizeof(struct acct_v3);
  
  return self;
}

static VALUE pacct_entry_new(PacctFile* file) {
  VALUE entry;
  struct acct_v3* ptr = ALLOC(struct acct_v3);
  if(file) {
    size_t entriesRead = fread(ptr, sizeof(struct acct_v3), 1, file->file);
    if(entriesRead != 1) {
      rb_raise(rb_eIOError, "Unable to read record from accounting file");
    }
  } else {
    memset(ptr, 0, sizeof(struct acct_v3));
  }
  entry = Data_Wrap_Struct(cEntry, 0, free, ptr);
  
  return entry;
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
  PacctFile* file;
  VALUE start_value;
  long start = 0;
  int i = 0;
  
  rb_scan_args(argc, argv, "01", &start_value);
  if(argc && start_value != Qnil) {
    start = NUM2INT(start_value);
  }
  
  Data_Get_Struct(self, PacctFile, file);
  
  if(start > file->numEntries) {
    char buf[100];
    snprintf(buf, 100, "Index %li is out of range", start);
    rb_raise(rb_eRangeError, buf);
  }
  
  fseek(file->file, start * sizeof(struct acct_v3), SEEK_SET);
  
  for(i = start; i < file->numEntries; ++i) {
    VALUE entry = pacct_entry_new(file);
    rb_yield_values(2, entry, INT2NUM(i));
  }

  return Qnil;
}

/*
 *Returns the last entry in the file
 */
static VALUE last_entry(VALUE self) {
  PacctFile* file;
  long pos;
  VALUE entry;
  
  Data_Get_Struct(self, PacctFile, file);
  
  if(file->numEntries == 0) {
    rb_raise(rb_eRangeError, "No last entry in file");
  }
  
  //To do: error checking on file operations?
  pos = ftell(file->file);
  fseek(file->file, -sizeof(struct acct_v3), SEEK_END);
  
  entry = pacct_entry_new(file);
  
  fseek(file->file, pos, SEEK_SET);
  
  return entry;
}

/*
 *Returns the number of entries in the file
 */
static VALUE get_num_entries(VALUE self) {
  PacctFile* file;
  
  Data_Get_Struct(self, PacctFile, file);
  
  return INT2NUM(file->numEntries);
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
  PacctFile* file;
  long pos;
  struct acct_v3* acct;
  
  Data_Get_Struct(self, PacctFile, file);
  Data_Get_Struct(entry, struct acct_v3, acct);
  
  pos = ftell(file->file);
  fseek(file->file, 0, SEEK_END);
  
  fwrite(acct, sizeof(struct acct_v3), 1, file->file);
  
  ++(file->numEntries);
  
  fseek(file->file, pos, SEEK_SET);
  
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
    snprintf(buf, 512, "Unable to obtain user name for ID %u", data->ac_uid);
    err = rb_funcall(cSystemCallError, id_new, 2, rb_str_new2(buf), INT2NUM(errno));
    rb_exc_raise(err);
  }
  
  return rb_str_new2(pw_data->pw_name);
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
    snprintf(buf, 512, "Unable to obtain group name for ID %u", data->ac_gid);
    err = rb_funcall(cSystemCallError, id_new, 2, rb_str_new2(buf), INT2NUM(errno));
    rb_exc_raise(err);
  }
  
  return rb_str_new2(group_data->gr_name);
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
 *Returns the task's total system CPU time in seconds
 */
static VALUE get_system_time(VALUE self) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  return INT2NUM(comp_t_to_long(data->ac_stime) / ticksPerSecond);
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
 *Returns the task's start time
 */
static VALUE get_start_time(VALUE self) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  return rb_funcall(cTime, id_at, 1, INT2NUM(data->ac_btime));
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
 *Returns the first 16 characters of the command name
 */
static VALUE get_command_name(VALUE self) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  return rb_str_new2(data->ac_comm);
}

/*
 *Returns the command's exit code
 */
static VALUE get_exit_code(VALUE self) {
  struct acct_v3* data;
  Data_Get_Struct(self, struct acct_v3, data);
  
  return INT2NUM(data->ac_exitcode);
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

  //Define Ruby modules/objects/methods.
  mPacct = rb_define_module("Pacct");
  /*
   *Represents an accounting file in acct(5) format
   */
  cFile = rb_define_class_under(mPacct, "File", rb_cObject);
  /*
   *Document-class: Pacct::Entry
   *
   *Represents an entry in a Pacct::File
   */
  cEntry = rb_define_class_under(mPacct, "Entry", rb_cObject);
  rb_define_singleton_method(cFile, "new", pacct_file_new, 1);
  rb_define_method(cFile, "initialize", pacct_file_init, 1);
  rb_define_method(cFile, "each_entry", each_entry, -1);
  rb_define_method(cFile, "last_entry", last_entry, 0);
  rb_define_method(cFile, "num_entries", get_num_entries, 0);
  rb_define_method(cFile, "write_entry", write_entry, 1);
  
  rb_define_method(cEntry, "process_id", get_process_id, 0);
  rb_define_method(cEntry, "user_id", get_user_id, 0);
  rb_define_method(cEntry, "user_name", get_user_name, 0);
  rb_define_method(cEntry, "group_id", get_group_id, 0);
  rb_define_method(cEntry, "group_name", get_group_name, 0);
  rb_define_method(cEntry, "user_time", get_user_time, 0);
  rb_define_method(cEntry, "system_time", get_system_time, 0);
  rb_define_method(cEntry, "cpu_time", get_cpu_time, 0);
  rb_define_method(cEntry, "wall_time", get_wall_time, 0);
  rb_define_method(cEntry, "start_time", get_start_time, 0);
  rb_define_method(cEntry, "memory", get_average_mem_usage, 0);
  rb_define_method(cEntry, "exit_code", get_exit_code, 0);
  rb_define_method(cEntry, "command_name", get_command_name, 0);
}