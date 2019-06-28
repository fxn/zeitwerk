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
      basename.split('_').map!(&:capitalize).join
    end
  end
end
