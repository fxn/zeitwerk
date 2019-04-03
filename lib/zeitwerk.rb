# frozen_string_literal: true

module Zeitwerk
  class << self
    # Kernel#require will apply String#-@ on paths before registering them in $LOADED_FEATURES.
    # That method tries to intern the string to avoid holding onto multiple copies of it.
    # However there is a couple problem that prevent the deduplication from happening in the vast
    # majority of cases.
    #
    # First tainted string can't be interned, and `File.expand_path` do return tained string.
    #
    # Secondly, `Kernel#require` rebuilds a string from what is returned by the file system,
    # and most of the time that string encoding isn't the application default encoding.
    PATHS_ENCODING = $LOADED_FEATURES.first.encoding
    def intern_path!(path)
      -(path.untaint.force_encoding(PATHS_ENCODING))
    end

    CPATHS_ENCODING = Object.name.encoding
    def intern_cname!(cpath)
      -(cpath.dup.untaint.force_encoding(CPATHS_ENCODING))
    end
  end

  require_relative "zeitwerk/loader"
  require_relative "zeitwerk/registry"
  require_relative "zeitwerk/explicit_namespace"
  require_relative "zeitwerk/inflector"
  require_relative "zeitwerk/gem_inflector"
  require_relative "zeitwerk/kernel"
  require_relative "zeitwerk/conflicting_directory"
end
