# frozen_string_literal: true

module Zeitwerk::Registry
  # A registry for namespaces.
  #
  # When a namespace is autoloaded, our global const_added callback retrieves
  # its loader by calling loader_for. The loader then scans the subdirectories
  # that conform the namespace and sets autoloads for their expected constants.
  #
  # The implementation assumes each namespace is managed by one single loader.
  # Loaders that reopen namespaces owned by other projects are responsible for
  # loading their constant before setup. This is documented.
  #
  # @private
  class Namespaces # :nodoc: all
    #: () -> void
    def initialize
      # Maps crefs of explicit namespaces with their corresponding loader.
      #
      # Entries are added as the namespaces are found, and removed as they are
      # autoloaded.
      @loaders = Zeitwerk::Cref::Map.new
    end

    #: (Zeitwerk::Cref, Zeitwerk::Loader) -> void
    def register(cref, loader)
      @loaders[cref] = loader
    end

    #: (Module, Symbol) -> Zeitwerk::Loader?
    def loader_for(mod, cname)
      @loaders.delete_mod_cname(mod, cname)
    end

      #: (Zeitwerk::Cref) -> Zeitwerk::Loader?
    def unregister_cref(cref)
      @loaders.delete(cref)
    end

    #: (Zeitwerk::Loader) -> void
    def unregister_loader(loader)
      @loaders.delete_by_value(loader)
    end

    #: (Zeitwerk::Cref) -> Zeitwerk::Loader?
    def registered?(cref) # for tests
      @loaders[cref]
    end

    #: () -> void
    def clear # for tests
      @loaders.clear
    end
  end
end
