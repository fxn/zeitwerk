class Zeitwerk::NullInflector
  # @sig (String, String) -> String
  def camelize(basename, _abspath)
    basename
  end
end
