#: frozen_string_literal: true

# @private
class Zeitwerk::Loader::FileSystemScanner # :nodoc:
  def initialize(loader)
    @loader = loader
    @logger = loader.logger
  end

  #: (String) { (String, String, Symbol) -> void } -> void
  def ls(dir)
    children = scan_dir(dir)

    # The order in which a directory is listed depends on the file system.
    #
    # Since client code may run on different platforms, it seems convenient to
    # sort directory entries. This provides more deterministic behavior, with
    # consistent eager loading in particular.
    children.sort_by!(&:first)

    children.each do |basename, abspath, ftype|
      if ftype == :directory && !has_at_least_one_ruby_file?(abspath)
        @loader.log("directory #{abspath} is ignored because it has no Ruby files") if @logger
        next
      end

      yield basename, abspath, ftype
    end
  end

  #: (String) { (String) -> void } -> void
  def walk_up(abspath)
    loop do
      yield abspath
      abspath, basename = File.split(abspath)
      break if basename == "/"
    end
  end

  #: (String) -> bool
  def ruby?(path)
    path.end_with?(".rb")
  end

  #: (String) -> bool
  def hidden?(basename)
    basename.start_with?(".")
  end

  # Encodes the documented conventions.
  #
  #: (String) -> Symbol?
  def supported_ftype?(abspath)
    if ruby?(abspath)
      :file # By convention, we can avoid a syscall here.
    elsif dir?(abspath)
      :directory
    end
  end

  # Looks for a Ruby file using breadth-first search. This type of search is
  # important to list as less directories as possible and return fast in the
  # common case in which there are Ruby files in the given directory.
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
      next if @loader.hidden?(basename)

      abspath = File.join(dir, basename)
      next if @loader.ignored_path?(abspath)

      ftype = supported_ftype?(abspath)
      next unless ftype

      # Conceptually, root directories start separate trees.
      next if :directory == ftype && @loader.root_dir?(abspath)

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

  #: (String) -> bool
  private def dir?(path)
    File.directory?(path)
  end
end
