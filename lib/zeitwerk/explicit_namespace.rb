# frozen_string_literal: true

module Zeitwerk
  # Centralizes the logic needed to descend into matching subdirectories right
  # after the constant for an explicit namespace has been defined.
  #
  # The implementation assumes an explicit namespace is managed by one loader.
  # Loaders that reopen namespaces owned by other projects are responsible for
  # loading their constant before setup. This is documented.
  module ExplicitNamespace # :nodoc: all
    # Maps cnames or cpaths of explicit namespaces with their corresponding
    # loader. They are symbols if the namespace lives in Object, or qualified
    # paths as strings otherwise. Entries are added as the namespaces are found,
    # and removed as they are autoloaded.
    #
    # @sig Hash[(Symbol | String) => Zeitwerk::Loader]
    @loaders = {}

    class << self
      include RealModName
      extend Internal

      # Registers `cref` as being the constant path of an explicit namespace
      # managed by `loader`.
      #
      # @sig (String, Zeitwerk::Loader) -> void
      internal def register(cref, loader)
        if Object.equal?(cref.mod)
          @loaders[cref.cname] = loader
        else
          @loaders[cref.path] = loader
        end
      end

      # @sig (String) -> Zeitwerk::Loader?
      internal def loader_for(mod, cname)
        if Object.equal?(mod)
          @loaders.delete(cname)
        else
          @loaders.delete("#{real_mod_name(mod)}::#{cname}")
        end
      end

      # @sig (Zeitwerk::Loader) -> void
      internal def unregister_loader(loader)
        @loaders.delete_if { _2.equal?(loader) }
      end

      # This is an internal method only used by the test suite.
      #
      # @sig (String) -> Zeitwerk::Loader?
      internal def registered?(cname_or_cpath)
        @loaders[cname_or_cpath]
      end

      # This is an internal method only used by the test suite.
      #
      # @sig () -> void
      internal def clear
        @loaders.clear
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
