module Zeitwerk::Registry
  # Loaders know their own inceptions, but there is a use case in which we need
  # to know if a given cpath is an inception globally. This is what this
  # registry is for.
  class Inceptions # :nodoc:
    # @sig () -> void
    def initialize
      # @sig Zeitwerk::Cref::Map[String]
      @inceptions = Zeitwerk::Cref::Map.new
    end

    # @sig (Zeitwerk::Cref, String) -> void
    def register(cref, abspath)
      @inceptions[cref] = abspath
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
