module Zeitwerk
  class SimpleInflector < GemInflector # :nodoc:
    # @param inflections [Hash, nil]
    def initialize(inflections = nil)
      @inflections = inflections || {}
    end

    # @param basename [String]
    # @param class_name [String]
    # @return [String]
    def inflect(basename, class_name)
      @inflections[basename] = class_name
    end

    # @param basename [String]
    # @param abspath [String]
    # @return [String]
    def camelize(basename, _abspath)
      @inflections[basename] || super
    end
  end
end
