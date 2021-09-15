# frozen_string_literal: true

module Zeitwerk
  # @private
  class Autoloads
    # Maps crefs for which an autoload has been defined to the corresponding
    # absolute path.
    #
    #   [Object, :User]  => "/Users/fxn/blog/app/models/user.rb"
    #   [Object, :Hotel] => "/Users/fxn/blog/app/models/hotel"
    #   ...
    #
    # This colection is transient, callbacks delete its entries as autoloads get
    # executed.
    #
    # @sig Hash[[Module, Symbol], String]
    attr_reader :c2a

    # This is the inverse of c2a, for inverse lookups.
    #
    # @sig Hash[String, [Module, Symbol]]
    attr_reader :a2c

    # @sig () -> void
    def initialize
      @c2a = {}
      @a2c = {}
    end

    # @sig (Module, Symbol, String) -> void
    def define(parent, cname, abspath)
      parent.autoload(cname, abspath)
      cref = [parent, cname]
      c2a[cref] = abspath
      a2c[abspath] = cref
    end

    # @sig () { () -> [[Module, Symbol], String] } -> void
    def each(&block)
      c2a.each(&block)
    end

    # @sig (Module, Symbol) -> String?
    def abspath_for(parent, cname)
      c2a[[parent, cname]]
    end

    # @sig (String) -> [Module, Symbol]?
    def cref_for(abspath)
      a2c[abspath]
    end

    # @sig (String) -> [Module, Symbol]?
    def delete(abspath)
      cref = a2c.delete(abspath)
      c2a.delete(cref)
      cref
    end

    # @sig () -> void
    def clear
      c2a.clear
      a2c.clear
    end

    # @sig () -> bool
    def empty?
      c2a.empty? && a2c.empty?
    end
  end
end
