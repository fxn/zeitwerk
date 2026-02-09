# frozen_string_literal: true

module Zeitwerk::Loader::Helpers
  # --- Logging -----------------------------------------------------------------------------------

  #: (to_s() -> String) -> void
  private def log(message)
    method_name = logger.respond_to?(:debug) ? :debug : :call
    logger.send(method_name, "Zeitwerk@#{tag}: #{message}")
  end

  # --- Files and directories ---------------------------------------------------------------------

  #: (String) { (String, String, Symbol) -> void } -> void
  private def ls(dir)
    children = scan_dir(dir)

    # The order in which a directory is listed depends on the file system.
    #
    # Since client code may run on different platforms, it seems convenient to
    # sort directory entries. This provides more deterministic behavior, with
    # consistent eager loading in particular.
    children.sort_by!(&:first)

    children.each do |basename, abspath, ftype|
      if ftype == :directory && !has_at_least_one_ruby_file?(abspath)
        log("directory #{abspath} is ignored because it has no Ruby files") if logger
        next
      end

      yield basename, abspath, ftype
    end
  end

  # Looks for a Ruby file using breadth-first search. This type of search is
  # important to list as less directories as possible and return fast in the
  # common case in which there are Ruby files.
  #
  #: (String) -> bool
  private def has_at_least_one_ruby_file?(dir)
    to_visit = [dir]

    while (dir = to_visit.shift)
      scan_dir(dir) do |_, abspath, ftype|
        return true if ftype == :file
        to_visit << abspath
      end
    end

    false
  end

  # This is a low-level method to scan directories. It filters out some stuff
  # the loader is never interested in, and passes the ftype up. The rest of the
  # library should generally use `ls`.
  #
  # Keep an eye on https://bugs.ruby-lang.org/issues/21800.
  #
  #: (String) { (String, String, Symbol) -> void } -> void
  #: (String) -> [[String, String, Symbol]]
  private def scan_dir(dir)
    children = [] unless block_given?

    Dir.each_child(dir) do |basename|
      next if hidden?(basename)

      abspath = File.join(dir, basename)
      next if ignored_path?(abspath)

      ftype = supported_ftype?(abspath)
      next unless ftype

      # Conceptually, root directories start separate trees.
      next if :directory == ftype && root_dir?(abspath)

      # We freeze abspath because that saves allocations when passed later to
      # File methods. See https://github.com/fxn/zeitwerk/pull/125.
      if block_given?
        yield basename, abspath.freeze, ftype
      else
        children << [basename, abspath.freeze, ftype]
      end
    end

    children unless block_given?
  end

  # Encodes the documented conventions.
  #
  #: (String) -> Symbol?
  private def supported_ftype?(abspath)
    if ruby?(abspath)
      :file # By convention, we can avoid a syscall here.
    elsif dir?(abspath)
      :directory
    end
  end

  #: (String) -> bool
  private def ruby?(path)
    path.end_with?(".rb")
  end

  #: (String) -> bool
  private def dir?(path)
    File.directory?(path)
  end

  #: (String) -> bool
  private def hidden?(basename)
    basename.start_with?(".")
  end

  #: (String) { (String) -> void } -> void
  private def walk_up(abspath)
    loop do
      yield abspath
      abspath, basename = File.split(abspath)
      break if basename == "/"
    end
  end

  # --- Inflection --------------------------------------------------------------------------------

  CNAME_VALIDATOR = Module.new #: Module
  private_constant :CNAME_VALIDATOR

  #: (String, String) -> Symbol ! Zeitwerk::NameError
  private def cname_for(basename, abspath)
    cname = inflector.camelize(basename, abspath)

    unless cname.is_a?(String)
      raise TypeError, "#{inflector.class}#camelize must return a String, received #{cname.inspect}"
    end

    if cname.include?("::")
      raise Zeitwerk::NameError.new(<<~MESSAGE, cname)
        wrong constant name #{cname} inferred by #{inflector.class} from

          #{abspath}

        #{inflector.class}#camelize should return a simple constant name without "::"
      MESSAGE
    end

    begin
      CNAME_VALIDATOR.const_defined?(cname, false)
    rescue ::NameError => error
      path_type = ruby?(abspath) ? "file" : "directory"

      raise Zeitwerk::NameError.new(<<~MESSAGE, error.name)
        #{error.message} inferred by #{inflector.class} from #{path_type}

          #{abspath}

        Possible ways to address this:

          * Tell Zeitwerk to ignore this particular #{path_type}.
          * Tell Zeitwerk to ignore one of its parent directories.
          * Rename the #{path_type} to comply with the naming conventions.
          * Modify the inflector to handle this case.
      MESSAGE
    end

    cname.to_sym
  end
end
