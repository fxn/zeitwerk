# frozen_string_literal: true

require "mkmf"

# https://docs.ruby-lang.org/en/4.0/MakeMakefile.html

preconditions_hold = -> () do
  # These headers are available in POSIX or POSIX-compatible platforms, you
  # cannot assume they exist otherwise.
  return false unless have_header("dirent.h")
  return false unless have_header("sys/stat.h")

  # The dirent structure is only guaranteed to have members d_ino and d_name, we
  # need the common extension d_type.
  return false unless have_struct_member("struct dirent", "d_type", "dirent.h")

  # If d_type is present, these constants probably exist too, but they are not
  # technically guaranteed.
  return false unless have_const("DT_UNKNOWN", "dirent.h")
  return false unless have_const("DT_LNK", "dirent.h")
  return false unless have_const("DT_DIR", "dirent.h")
  return false unless have_const("DT_REG", "dirent.h")

  # The function fstatat() is not guaranteed to exist either, even if the header
  # is present.
  return false unless have_func("fstatat", "sys/stat.h")

  true
end

if %w(ruby truffleruby).include?(RUBY_ENGINE) && preconditions_hold.call
  append_cflags(["-O3", "-std=c99"])
  create_makefile("zeitwerk/zeitwerk_native")
else
  # Keep an eye on https://bugs.ruby-lang.org/issues/20152.
  dummy_makefile("zeitwerk/zeitwerk_native")
end
