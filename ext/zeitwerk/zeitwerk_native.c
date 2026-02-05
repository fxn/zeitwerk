#include "ruby.h"
#include <errno.h>
#include <dirent.h>
#include <stdbool.h>
#include <string.h>
#include <sys/stat.h>

/*
 * This file borrows ideas from
 *
 *   https://github.com/rails/bootsnap/blob/main/ext/bootsnap/bootsnap.c
 *
 * References:
 *
 *   https://silverhammermba.github.io/emberb/c/
 *   https://docs.ruby-lang.org/en/4.0/extension_rdoc.html
 *   https://github.com/ruby/ruby/blob/master/doc/extension.rdoc
 */

static ID id_file;
static ID id_directory;

static bool
zw_has_rb_extension(const char *name, size_t len)
{
    return len > 3 && name[len - 3] == '.' && name[len - 2] == 'r' && name[len - 1] == 'b';
}

RBIMPL_ATTR_NORETURN()
static void
zw_syserr_fail_path(const char *func_name, int err, const char* path)
{
    rb_syserr_fail_str(err, rb_sprintf("%s @ %s", func_name, path));
}

RBIMPL_ATTR_NORETURN()
static void
zw_syserr_fail_dir_entry(const char *func_name, int err, const char* dir, const char *d_name)
{
    rb_syserr_fail_str(err, rb_sprintf("%s @ %s/%s", func_name, dir, d_name));
}

static VALUE
zw_filtered_dir_entries_with_type(VALUE self, VALUE abspath)
{
    const char* cstr_abspath = StringValueCStr(abspath);

    DIR *dirp = opendir(cstr_abspath);
    if (dirp == NULL) {
        zw_syserr_fail_path("opendir", errno, cstr_abspath);
        return Qundef;
    }

    VALUE sym_file = ID2SYM(id_file);
    VALUE sym_directory = ID2SYM(id_directory);
    VALUE result = rb_ary_new();

    struct dirent *entry;
    int dfd = -1;

    while (1) {
        errno = 0;

        entry = readdir(dirp);
        if (entry == NULL) break;

        if (entry->d_name[0] == '.') continue;

        int type = entry->d_type;

        if (RB_UNLIKELY(type == DT_UNKNOWN || type == DT_LNK)) {
            struct stat st;

            if (dfd < 0) {
                dfd = dirfd(dirp);
                if (dfd < 0) {
                    int err = errno;
                    closedir(dirp);
                    zw_syserr_fail_path("dirfd", err, cstr_abspath);
                    return Qundef;
                }
            }

            if (fstatat(dfd, entry->d_name, &st, 0)) {
                int err = errno;
                closedir(dirp);
                zw_syserr_fail_dir_entry("fstatat", err, cstr_abspath, entry->d_name);
                return Qundef;
            }

            if (S_ISREG(st.st_mode)) {
                type = DT_REG;
            } else if (S_ISDIR(st.st_mode)) {
                type = DT_DIR;
            }
        }

        if (type == DT_REG) {
            size_t len = strlen(entry->d_name);
            if (zw_has_rb_extension(entry->d_name, len)) {
                VALUE tuple = rb_assoc_new(rb_utf8_str_new(entry->d_name, len), sym_file);
                rb_ary_push(result, tuple);
            }
        } else if (type == DT_DIR) {
            VALUE tuple = rb_assoc_new(rb_utf8_str_new_cstr(entry->d_name), sym_directory);
            rb_ary_push(result, tuple);
        }
    }

    if (errno) {
        int err = errno;
        closedir(dirp);
        zw_syserr_fail_path("readdir", err, cstr_abspath);
        return Qundef;
    }

    if (closedir(dirp)) {
        zw_syserr_fail_path("closedir", errno, cstr_abspath);
        return Qundef;
    }

    return result;
}

void Init_zeitwerk_native(void)
{

    id_file = rb_intern("file");
    id_directory = rb_intern("directory");

    VALUE zw_mZeitwerk = rb_const_get_at(rb_cObject, rb_intern("Zeitwerk"));
    VALUE zw_cLoader = rb_const_get_at(zw_mZeitwerk, rb_intern("Loader"));
    VALUE zw_mHelpers = rb_const_get_at(zw_cLoader, rb_intern("Helpers"));

    VALUE zw_mHelpers_Native = rb_define_module_under(zw_mHelpers, "Native");
    rb_define_private_method(zw_mHelpers_Native, "filtered_dir_entries_with_type", zw_filtered_dir_entries_with_type, 1);
    rb_prepend_module(zw_mHelpers, zw_mHelpers_Native);
}
