module Zeitwerk::Registry
  # Loaders know their own inceptions, but there is a use case in which we need
  # to know if a given cpath is an inception globally. This is what this
  # registry is for.
  module Inceptions # :nodoc: all
    # @sig Hash[String, String]
    @inceptions = {}

    class << self
      # @sig (String, String) -> void
      def register(cpath, autoload_path)
        @inceptions[cpath] = autoload_path
      end

      # @sig (String) -> String?
      def registered?(cpath)
        @inceptions[cpath]
      end

      # @sig (String) -> void
      def unregister(cpath)
        @inceptions.delete(cpath)
      end

      # @sig () -> void
      def clear # for tests
        @inceptions.clear
      end

      module Synchronized
        extend Zeitwerk::Internal

        MUTEX = Mutex.new

        def register(...)
          MUTEX.synchronize { super }
        end

        def registered?(...)
          MUTEX.synchronize { super }
        end

        def unregister(...)
          MUTEX.synchronize { super }
        end

        def clear
          MUTEX.synchronize { super }
        end
      end

      prepend Synchronized unless RUBY_ENGINE == "ruby"
    end
  end
end
