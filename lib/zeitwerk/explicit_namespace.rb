# frozen_string_literal: true

module Zeitwerk
  # Centralizes the logic needed to descend into matching subdirectories right
  # after the constant for an explicit namespace has been defined.
  #
  # The implementation assumes an explicit namespace is managed by one loader.
  # Loaders that reopen namespaces owned by other projects are responsible for
  # loading their constant before setup. This is documented.
  module ExplicitNamespace # :nodoc: all
    # Maps cpaths of explicit namespaces with their corresponding loader.
    # Entries are added as the namespaces are found, and removed as they are
    # autoloaded.
    #
    # @sig Hash[String => Zeitwerk::Loader]
    @cpaths = {}

    class << self
      include RealModName
      extend Internal

      # Registers `cpath` as being the constant path of an explicit namespace
      # managed by `loader`.
      #
      # @sig (String, Zeitwerk::Loader) -> void
      internal def register(cpath, loader)
        @cpaths[cpath] = loader
      end

      # @sig (String) -> Zeitwerk::Loader?
      internal def loader_for(mod, cname)
        cpath = mod.equal?(Object) ? cname.name : "#{real_mod_name(mod)}::#{cname}"
        @cpaths.delete(cpath)
      end

      # @sig (Zeitwerk::Loader) -> void
      internal def unregister_loader(loader)
        @cpaths.delete_if { _2.equal?(loader) }
      end

      # This is an internal method only used by the test suite.
      #
      # @sig (String) -> Zeitwerk::Loader?
      internal def registered?(cpath)
        @cpaths[cpath]
      end

      # This is an internal method only used by the test suite.
      #
      # @sig () -> void
      internal def clear
        @cpaths.clear
      end

      module Synchronized
        extend Internal

        MUTEX = Mutex.new

        internal def register(...)
          MUTEX.synchronize { super }
        end

        internal def loader_for(...)
          MUTEX.synchronize { super }
        end

        internal def unregister_loader(...)
          MUTEX.synchronize { super }
        end

        internal def registered?(...)
          MUTEX.synchronize { super }
        end

        internal def clear
          MUTEX.synchronize { super }
        end
      end

      prepend Synchronized unless RUBY_ENGINE == "ruby"
    end
  end
end
