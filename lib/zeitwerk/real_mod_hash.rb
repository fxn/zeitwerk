# frozen_string_literal: true

module Zeitwerk::RealModHash
  UNBOUND_METHOD_MODULE_HASH = Module.instance_method(:hash)
  private_constant :UNBOUND_METHOD_MODULE_HASH

  # We need this because users may override Module#hash in concrete classes and
  # modules, as we saw in https://github.com/fxn/zeitwerk/issues/188.
  #
  # @sig (Module) -> Integer
  def real_mod_hash(mod)
    UNBOUND_METHOD_MODULE_HASH.bind_call(mod)
  end
end
