# frozen_string_literal: true

module NoWarningsPolicy
  MESSAGE = "This test suite aborts on warnings, please fix the one above."

  if Warning.method(:warn).arity == 1
    def warn(*)
      super
      abort(MESSAGE)
    end
  else
    def warn(*, **)
      super
      abort(MESSAGE)
    end
  end
end

Warning.extend(NoWarningsPolicy)
