# frozen_string_literal: true

module Zeitwerk
  class GemInflector < Inflector
    # @param root_file [String]
    def initialize(root_file)
      namespace     = File.basename(root_file, ".rb")
      lib_dir       = File.dirname(root_file)
      @version_file = File.join(lib_dir, namespace, "version.rb")
    end

    # @param basename [String]
    # @param _cpath [String]
    # @param abspath [String]
    # @return [String]
    def camelize(basename, _cpath, abspath)
      (basename == "version" && abspath == @version_file) ? "VERSION" : super
    end
  end
end
