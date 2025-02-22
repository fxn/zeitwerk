module Zeitwerk::Registry
  class Autoloads # :nodoc:
    # @sig () -> void
    def initialize
      @autoloads = {} # @sig Hash[String, Zeitwerk::Loader]
    end

    # @sig (String, Zeitwerk::Loader) -> Zeitwerk::Loader
    def register(abspath, loader)
      @autoloads[abspath] = loader
    end

    # @sig (String) -> Zeitwerk::Loader?
    def registered?(path)
      @autoloads[path]
    end

    # @sig (String) -> Zeitwerk::Loader?
    def unregister(abspath)
      @autoloads.delete(abspath)
    end

    # @sig (Zeitwerk::Loader) -> void
    def unregister_loader(loader)
      @autoloads.delete_if { _2 == loader }
    end

    # @sig () -> bool
    def empty? # for tests
      @autoloads.empty?
    end

    # @sig () -> void
    def clear # for tests
      @autoloads.clear
    end
  end
end
