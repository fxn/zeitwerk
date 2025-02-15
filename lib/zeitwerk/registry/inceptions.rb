module Zeitwerk::Registry
  # Loaders know their own inceptions, but there is a use case in which we need
  # to know if a given cpath is an inception globally. This is what this
  # registry is for.
  module Inceptions # :nodoc: all
    # @sig Zeitwerk::Cref::Map[String]
    @inceptions = Zeitwerk::Cref::Map.new

    class << self
      # @sig (Zeitwerk::Cref, String) -> void
      def register(cref, autoload_path)
        @inceptions[cref] = autoload_path
      end

      # @sig (String) -> String?
      def registered?(cref)
        @inceptions[cref]
      end

      # @sig (String) -> void
      def unregister(cref)
        @inceptions.delete(cref)
      end

      # @sig () -> void
      def clear # for tests
        @inceptions.clear
      end
    end
  end
end
