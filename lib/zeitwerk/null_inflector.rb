class Zeitwerk::NullInflector
  # Experimental inflector that does not change anything.
  #
  # inflector = Zeitwerk::NullInflector.new
  # inflector.camelize("post", ...)             # => "post"
  # inflector.camelize("UsersController", ...)  # => "UsersController"
  # inflector.camelize("api", ...)              # => "api"
  #
  # @sig (String, String?) -> String
  def camelize(basename, _abspath = nil)
    basename
  end
end
