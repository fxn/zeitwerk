# frozen_string_literal: true

module Kernel
  module_function

  # We cannot decorate with prepend + super because Kernel has already been
  # included in Object, and changes in ancestors don't get propagated into
  # already existing ancestor chains.
  alias_method :zeitwerk_original_require, :require

  # @param path [String]
  # @return [Boolean]
  def require(path)
    if loader = Zeitwerk::Registry.loader_for(path)
      if path.end_with?(".rb")
        zeitwerk_original_require(path).tap do |required|
          loader.on_file_autoloaded(path) if required
        end
      else
        loader.on_dir_autoloaded(path)
      end
    else
      zeitwerk_original_require(path).tap do |required|
        if required
          realpath = $LOADED_FEATURES.last
          if loader = Zeitwerk::Registry.loader_for(realpath)
            loader.on_file_autoloaded(realpath)
          end
        end
      end
    end
  end

  # By now, I have seen no way so far to decorate require_relative.
  #
  # For starters, at least in CRuby, require_relative does not delegate to
  # require. Both require and require_relative delegate the bulk of their work
  # to an internal C function called rb_require_safe. So, our require wrapper is
  # not executed.
  #
  # On the other hand, we cannot use the aliasing technique above because
  # require_relative receives a path relative to the directory of the file in
  # which the call is performed. If a wrapper here invoked the original method,
  # Ruby would resolve the relative path taking lib/zeitwerk as base directory.
  #
  # A workaround could be to extract the base directory from caller_locations,
  # but what if someone else decorated require_relative before us? You can't
  # really know with certainty where's the original call site in the stack.
end
