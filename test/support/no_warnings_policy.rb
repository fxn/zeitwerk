module NoWarningsPolicy
  def warn(*, **)
    super
    abort("This test suite aborts on warnings, please fix the one above.")
  end
end

module Warning
  prepend NoWarningsPolicy
end
