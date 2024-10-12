# frozen_string_literal: true

module Zeitwerk::RealModName
  UNBOUND_METHOD_MODULE_NAME = Module.instance_method(:name)
  private_constant :UNBOUND_METHOD_MODULE_NAME

  # Returns the real name of the class or module, as set after the first
  # constant to which it was assigned (or nil).
  #
  # The name method can be overridden, hence the indirection in this method.
  #
  # @sig (Module) -> String?
  if RUBY_ENGINE == 'truffleruby' && (RUBY_ENGINE_VERSION.split('.').map(&:to_i) <=> [24, 2, 0]) < 0
    def real_mod_name(mod)
      name = UNBOUND_METHOD_MODULE_NAME.bind_call(mod)
      # https://github.com/oracle/truffleruby/issues/3683
      if name && name.start_with?('Object::')
        name = name[8..-1]
      end
      name
    end
  else
    def real_mod_name(mod)
      UNBOUND_METHOD_MODULE_NAME.bind_call(mod)
    end
  end
end
