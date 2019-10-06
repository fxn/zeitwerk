# frozen_string_literal: true

module Zeitwerk
  class Inflector
    def initialize
      # This ivar has two leading underscores for backwards compatibility.
      #
      # Goal is to avoid conflicts with existing subclasses, in case they have
      # an @inflections ivar, and a camelize calling super. Of course, an ivar
      # with two underscores could be being used by such subclasses, in which
      # case there would be a conflict, but that is assumed to be very unlikely.
      @__inflections = {}
    end

    # Very basic snake case -> camel case conversion.
    #
    #   inflector = Zeitwerk::Inflector.new
    #   inflector.camelize("post", ...)             # => "Post"
    #   inflector.camelize("users_controller", ...) # => "UsersController"
    #   inflector.camelize("api", ...)              # => "Api"
    #
    # Takes into account hard-coded mappings configured with `inflect`.
    #
    # @param basename [String]
    # @param _abspath [String]
    # @return [String]
    def camelize(basename, _abspath)
      @__inflections[basename] || basename.split('_').map!(&:capitalize).join
    end

    # Configures hard-coded mappings:
    #
    #   inflector = Zeitwerk::Inflector.new
    #   inflector.inflect(
    #     "html_parser"   => "HTMLParser",
    #     "mysql_adapter" => "MySQLAdapter"
    #   )
    #
    #   inflector.camelize("mysql_adapter", abspath)    # => "MySQLAdapter"
    #   inflector.camelize("users_controller", abspath) # => "PostsController"
    #
    # @param inflections [{String => String}]
    # @return [void]
    def inflect(inflections)
      @__inflections.merge!(inflections)
    end
  end
end
