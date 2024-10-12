# frozen_string_literal: true

# This private class encapsulates pairs (mod, cname).
#
# Objects represent the constant cname in the class or module object mod, and
# have API to manage them that encapsulates the constants API. Examples:
#
#   cref.path
#   cref.set(value)
#   cref.get
#
# The constant may or may not exist in mod.
class Zeitwerk::Cref
  include Zeitwerk::RealModName

  # @sig Module
  attr_reader :mod

  # @sig Symbol
  attr_reader :cname

  # The type of the first argument is Module because Class < Module, class
  # objects are also valid.
  #
  # @sig (Module, Symbol) -> void
  def initialize(mod, cname)
    @mod   = mod
    @cname = cname
    @path  = nil
  end

  # @sig () -> String
  def path
    @path ||= Object.equal?(@mod) ? @cname.name : "#{real_mod_name(@mod)}::#{@cname.name}".freeze
  end

  # @sig () -> String?
  def autoload?
    @mod.autoload?(@cname, false)
  end

  # @sig (String) -> bool
  def autoload(abspath)
    @mod.autoload(@cname, abspath)
  end

  # @sig () -> bool
  def defined?
    @mod.const_defined?(@cname, false)
  end

  # @sig (Object) -> Object
  def set(value)
    @mod.const_set(@cname, value)
  end

  # @raise [NameError]
  # @sig () -> Object
  def get
    @mod.const_get(@cname, false)
  end

  # @raise [NameError]
  # @sig () -> void
  def remove
    @mod.__send__(:remove_const, @cname)
  end
end
