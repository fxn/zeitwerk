def Warning.warn(*, **)
  super
  abort("This test suite aborts on warnings, please fix the one above.")
end
