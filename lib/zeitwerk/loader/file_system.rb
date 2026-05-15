# frozen_string_literal: true

# This private class encapsulates interactions with the file system.
#
# It is used to list directories and check file types, and it encodes the
# conventions documented in the README.
#
# @private
class Zeitwerk::Loader::FileSystem # :nodoc:
  #: (Zeitwerk::Loader) -> void
  def initialize(loader)
    @loader = loader
  end

  # This method lists directories, filtering out the following:
  #
  # - Hidden entries.
  # - Ignored entries.
  # - Files whose extension is not `.rb`.
  # - Nested root directories, since they represent separate trees.
  # - Subdirectories that (recursively) contain no Ruby files.
  #
  # If `collapse` is true, collapsed directories are not yielded, instead, the
  # method recurses so that the caller gets a conceptually flat listing.
  #
  # For every entry that is not excluded, `ls` yields its basename, absolute
  # path, and file type, which can only be :file or :directory.
  #
  #: (String) { (String, String, Symbol) -> void } -> void
  def ls(dir, collapse: true, &)
    children = relevant_dir_entries(dir)

    # The order in which a directory is listed depends on the file system.
    #
    # Since client code may run on different platforms, it seems convenient to
    # sort directory entries. This provides more deterministic behavior, with
    # consistent eager loading in particular.
    children.sort_by!(&:first)

    children.each do |basename, abspath, ftype|
      if ftype == :directory
        if !has_at_least_one_ruby_file?(abspath)
          @loader.__log { "directory #{abspath} is ignored because it has no Ruby files" }
          next
        elsif collapse && @loader.__collapse?(abspath)
          ls(abspath, collapse: collapse, &)
          next
        end
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

  # If `dir` has a nsfile, returns its absolute path. Otherwise, returns `nil`.
  #
  # This predicate accounts for arbitrarily nested collapsed subdirectories. For
  # example, `dir/collapsed/collapsed/ns.rb` is considered to be a nsfile in
  # `dir` and its absolute path is returned.
  #
  #: (String) -> String?
  def has_a_nsfile?(dir)
    return unless @loader.nsfile

    # Optimistic lookup.
    #
    # If `dir` has no collapsed subdirectories, which is common, this is the
    # only possible candidate. Otherwise, this is still worth checking first.
    nsfile_abspath = File.join(dir, @loader.nsfile)
    if File.exist?(nsfile_abspath) && !@loader.__ignored_path?(nsfile_abspath)
      return nsfile_abspath
    end

    return unless @loader.__collapse_parent?(dir)

    # Let's see if the nsfile is in any collapsed subdirectory. We could skip
    # scanning `dir`, since we saw above it does not have the nsfile, but we'd
    # need more caching for that. It is an edge case, let's KISS it for now.
    to_visit = [dir]
    while (dir = to_visit.shift)
      relevant_dir_entries(dir) do |basename, abspath, ftype|
        if ftype == :file && basename == @loader.nsfile
          return abspath
        elsif ftype == :directory && @loader.__collapse?(abspath)
          to_visit << abspath
        end
      end
    end

    nil
  end

  # Encodes the documented conventions.
  #
  #: (String) -> Symbol?
  def supported_ftype?(abspath)
    if rb_extension?(abspath)
      :file # By convention, we can avoid a syscall here.
    elsif dir?(abspath)
      :directory
    end
  end

  #: (String) -> bool
  def rb_extension?(path)
    path.end_with?(".rb")
  end

  #: (String) -> bool
  def dir?(path)
    File.directory?(path)
  end

  #: (String) -> bool
  def hidden?(basename)
    basename.start_with?(".")
  end

  private

  # Looks for a Ruby file using breadth-first search. This type of search is
  # important to list as less directories as possible and return fast in the
  # common case in which there are Ruby files in the passed directory.
  #
  #: (String) -> bool
  def has_at_least_one_ruby_file?(dir)
    to_visit = [dir]

    while (dir = to_visit.shift)
      relevant_dir_entries(dir) do |_, abspath, ftype|
        return true if ftype == :file
        to_visit << abspath
      end
    end

    false
  end

  #: (String) { (String, String, Symbol) -> void } -> void
  #: (String) -> [[String, String, Symbol]]
  def relevant_dir_entries(dir)
    return enum_for(__method__, dir).to_a unless block_given?

    each_ruby_file_or_directory(dir) do |basename, abspath, ftype|
      next if @loader.__ignored_path?(abspath)

      if ftype == :file
        yield basename, abspath, ftype
      else
        # Conceptually, root directories represent a separate project tree.
        yield basename, abspath, ftype unless @loader.__root_dir?(abspath)
      end
    end
  end

  # Dir.scan is more efficient in common platforms, but it is going to take a
  # while for it to be available.
  #
  # The following compatibility methods have the same semantics but are written
  # to favor the performance of the Ruby fallback, which can save syscalls.
  #
  # In particular, by convention, any directory entry with a .rb extension is
  # assumed to be a file or a symlink to a file.
  #
  # These methods also freeze abspaths because that saves allocations when
  # passed later to File methods. See https://github.com/fxn/zeitwerk/pull/125.

  if Dir.respond_to?(:scan) # Available in Ruby 4.1.
    #: (String) { (String, String, Symbol) -> void } -> void
    def each_ruby_file_or_directory(dir)
      Dir.scan(dir) do |basename, ftype|
        next if hidden?(basename)

        if rb_extension?(basename)
          abspath = File.join(dir, basename).freeze
          yield basename, abspath, :file # By convention.
        elsif ftype == :directory
          abspath = File.join(dir, basename).freeze
          yield basename, abspath, :directory
        elsif ftype == :link
          abspath = File.join(dir, basename).freeze
          yield basename, abspath, :directory if dir?(abspath)
        end
      end
    end
  else
    #: (String) { (String, String, Symbol) -> void } -> void
    def each_ruby_file_or_directory(dir)
      Dir.each_child(dir) do |basename|
        next if hidden?(basename)

        if rb_extension?(basename)
          abspath = File.join(dir, basename).freeze
          yield basename, abspath, :file # By convention.
        else
          abspath = File.join(dir, basename).freeze
          yield basename, abspath, :directory if dir?(abspath)
        end
      end
    end
  end
end
