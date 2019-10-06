# frozen_string_literal: true

module Zeitwerk
  class Inflector # :nodoc:
    # Very basic snake case -> camel case conversion.
    #
    #   inflector = Zeitwerk::Inflector.new
    #   inflector.camelize("post", ...)             # => "Post"
    #   inflector.camelize("users_controller", ...) # => "UsersController"
    #   inflector.camelize("api", ...)              # => "Api"
    #
    # @param basename [String]
    # @param _abspath [String]
    # @return [String]
    def camelize(basename, _abspath)
      __inflections[basename] || basename.split('_').map!(&:capitalize).join
    end

    # @param inflections [Hash]
    # @return [Hash]
    def inflect(inflections)
      __inflections.merge!(inflections)
    end

    private

    def __inflections
      @__inflections ||= {}
    end
  end
end
