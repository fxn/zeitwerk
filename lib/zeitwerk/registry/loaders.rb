module Zeitwerk::Registry
  class Loaders # :nodoc:
    # @sig () -> void
    def initialize
      @loaders = [] # @sig Array[Zeitwerk::Loader]
    end

    # @sig ({ (Zeitwerk::Loader) -> void }) -> void
    def each(&block)
      @loaders.each(&block)
    end

    # @sig (String, Zeitwerk::Loader) -> Zeitwerk::Loader
    def register(loader)
      @loaders << loader
    end

    # @sig (Zeitwerk::Loader) -> Zeitwerk::Loader?
    def unregister(loader)
      @loaders.delete(loader)
    end

    # @sig (Zeitwerk::Loader) -> bool
    def registered?(loader) # for tests
      @loaders.include?(loader)
    end

    # @sig (void) -> void
    def clear # for tests
      @loaders.clear
    end
  end
end
