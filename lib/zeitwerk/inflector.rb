# frozen_string_literal: true

module Zeitwerk
  class Inflector # :nodoc:
    # Very basic snake case -> camel case conversion.
    #
    #   Zeitwerk::Inflector.camelize("post", ...)             # => "Post"
    #   Zeitwerk::Inflector.camelize("users_controller", ...) # => "UsersController"
    #   Zeitwerk::Inflector.camelize("api", ...)              # => "Api"
    #
    # @param basename [String]
    # @param _abspath [String]
    # @return [String]
    def camelize(basename, _abspath)
      basename.split('_').map!(&:capitalize!).join
    end
  end
end
