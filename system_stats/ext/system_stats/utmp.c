#include <stdio.h>
#include <string.h>
#include <utmp.h>

#include "ruby.h"

VALUE SystemStatsModule;
VALUE UtmpModule;

/*
 *call-seq:
 *  users(filename)
 *
 *Opens and parses the given file as a set of records in UTMP format and returns an array
 *of the username fields for all entries with the USER_PROCESS type.
 *This function is most useful when used to read /var/run/utmp.
*/

static VALUE module_function_users(VALUE self, VALUE filename) {
  StringValue(filename);
  //DON'T FREE THIS! Ruby still uses it!
  char* cFilename = StringValueCStr(filename);
  VALUE users = rb_ary_new();
  FILE *file;
  size_t fileSize;
  struct utmp utmp_buf;

  //Open file.
  file = fopen(cFilename, "rb");
  if(!file) {
    char buf[512] = "Unable to open ";
    //Copy into the message buffer.
    strncpy(buf + strlen(buf), cFilename, 512 - 1 - strlen(buf));
    //Make sure the buffer ends with a null character.
    buf[511] = '\0';
    rb_raise(rb_eIOError, buf);
  }

  //Get file size.
  fseek(file, 0L, SEEK_END);
  fileSize = ftell(file);
  rewind(file);
  
  if((fileSize % sizeof(struct utmp)) != 0) {
    rb_raise(rb_eException, "/var/run/utmp appears to be the wrong size.");
  }
  
  //Read each entry.
  while(fread(&utmp_buf, sizeof(struct utmp), 1, file) == 1) {
    if( utmp_buf.ut_type == USER_PROCESS) {
      rb_ary_push(users, rb_str_new2(utmp_buf.ut_user));
    }
  }
  
  fclose(file);

  return users;
}

void Init_utmp() {
  SystemStatsModule = rb_define_module("SystemStats");
  /*
   *A module containing routines for parsing UTMP data
   */
  UtmpModule = rb_define_module_under(SystemStatsModule, "Utmp");
  rb_define_module_function(UtmpModule, "users", module_function_users, 1);
}
