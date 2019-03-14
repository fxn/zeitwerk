# frozen_string_literal: true

require "set"
require "securerandom"

module Zeitwerk
  class Loader
    require_relative "loader/callbacks"
    include Callbacks

    # @return [String]
    attr_reader :tag

    # @return [#camelize]
    attr_accessor :inflector

    # @return [#call, #debug, nil]
    attr_accessor :logger

    # Absolute paths of the root directories. Stored in a hash to preserve
    # order, easily handle duplicates, and also be able to have a fast lookup,
    # needed for detecting nested paths.
    #
    #   "/Users/fxn/blog/app/assets"   => true,
    #   "/Users/fxn/blog/app/channels" => true,
    #   ...
    #
    # This is a private collection maintained by the loader. The public
    # interface for it is `push_dir` and `dirs`.
    #
    # @private
    # @return [{String => true}]
    attr_reader :root_dirs

    # Absolute paths of files or directories that have to be preloaded.
    #
    # @private
    # @return [<String>]
    attr_reader :preloads

    # Absolute paths of files, directories, of glob patterns to be totally
    # ignored.
    #
    # @private
    # @return [Set<String>]
    attr_reader :ignored

    # The actual collection of absolute file and directory names at the time the
    # ignored glob patterns were expanded. Computed on setup, and recomputed on
    # reload.
    #
    # @private
    # @return [Set<String>]
    attr_reader :ignored_paths

    # Keeps track of shadowed files.
    #
    # A shadowed file is a file managed by this autoloader that is skipped
    # because its matching constant path has already been seen. Think $LOAD_PATH
    # and require, only the first occurrence of a given relative name is loaded.
    #
    # If the existing occurrence is an autoload, we map the file name to the
    # shadowing autoload path. If the existing occurrence is an already defined
    # constant, the file name is mapped to the constant path, meaning it was
    # loaded elsewhere.
    #
    # @private
    # @return [{String => String}]
    attr_reader :shadowed

    # Maps real absolute paths for which an autoload has been set to their
    # corresponding parent class or module and constant name.
    #
    #   "/Users/fxn/blog/app/models/user.rb"          => [Object, "User"],
    #   "/Users/fxn/blog/app/models/hotel/pricing.rb" => [Hotel, "Pricing"]
    #   ...
    #
    # @private
    # @return [{String => (Module, String)}]
    attr_reader :autoloads

    # Constant paths loaded so far.
    #
    # @private
    # @return [Set<String>]
    attr_reader :loaded

    # Maps constant paths of namespaces to arrays of corresponding directories.
    #
    # For example, given this mapping:
    #
    #   "Admin" => [
    #     "/Users/fxn/blog/app/controllers/admin",
    #     "/Users/fxn/blog/app/models/admin",
    #     ...
    #   ]
    #
    # when `Admin` gets defined we know that it plays the role of a namespace and
    # that its children are spread over those directories. We'll visit them to set
    # up the corresponding autoloads.
    #
    # @private
    # @return [{String => <String>}]
    attr_reader :lazy_subdirs

    # @private
    # @return [Mutex]
    attr_reader :mutex

    def initialize
      @initialized_at = Time.now

      @tag       = SecureRandom.hex(3)
      @inflector = Inflector.new
      @logger    = self.class.default_logger

      @root_dirs     = {}
      @preloads      = []
      @ignored       = Set.new
      @ignored_paths = Set.new
      @autoloads     = {}
      @loaded        = Set.new
      @lazy_subdirs  = {}
      @shadowed      = {}

      @mutex        = Mutex.new
      @setup        = false
      @eager_loaded = false

      Registry.register_loader(self)
    end

    # Sets a tag for the loader, useful for logging.
    #
    # @return [void]
    def tag=(tag)
      @tag = tag.to_s
    end

    # Absolute paths of the root directories. This is a read-only collection,
    # please push here via `push_dir`.
    #
    # @return [<String>]
    def dirs
      root_dirs.keys.freeze
    end

    # Pushes `paths` to the list of root directories.
    #
    # @param path [<String, Pathname>]
    # @return [void]
    def push_dir(path)
      abspath = File.expand_path(path)
      if dir?(abspath)
        raise_if_conflicting_directory(abspath)
        root_dirs[abspath] = true
      else
        raise ArgumentError, "the root directory #{abspath} does not exist"
      end
    end

    # Files or directories to be preloaded instead of lazy loaded.
    #
    # @param paths [<String, Pathname, <String, Pathname>>]
    # @return [void]
    def preload(*paths)
      mutex.synchronize do
        expand_paths(paths).each do |abspath|
          preloads << abspath
          do_preload_abspath(abspath) if @setup
        end
      end
    end

    # Configure files, directories, or glob patterns to be totally ignored.
    #
    # @param paths [<String, Pathname, <String, Pathname>>]
    # @return [void]
    def ignore(*paths)
      mutex.synchronize { ignored.merge(expand_paths(paths)) }
    end

    # @private
    # @return [void]
    def expand_ignored_glob_patterns
      # Note that Dir.glob works with regular file names just fine. That is,
      # glob patterns technically need no wildcards.
      ignored_paths.replace(ignored.flat_map { |path| Dir.glob(path) })
    end

    # Sets autoloads in the root namespace and preloads files, if any.
    #
    # @return [void]
    def setup
      mutex.synchronize do
        break if @setup

        expand_ignored_glob_patterns
        non_ignored_root_dirs.each { |root_dir| set_autoloads_in_dir(root_dir, Object) }
        do_preload

        @setup = true
      end
    end

    # Removes loaded constants and configured autoloads.
    #
    # The objects the constants stored are no longer reachable through them. In
    # addition, since said objects are normally not referenced from anywhere
    # else, they are eligible for garbage collection, which would effectively
    # unload them.
    #
    # @private
    # @return [void]
    def unload
      mutex.synchronize do
        autoloads.each do |path, (parent, cname)|
          if parent.autoload?(cname)
            parent.send(:remove_const, cname)
            log("autoload for #{cpath(parent, cname)} removed") if logger
          elsif cdef?(parent, cname)
            parent.send(:remove_const, cname)
            log("#{cpath(parent, cname)} unloaded") if logger
          end

          # Let Kernel#require load the same path later again by removing it
          # from $LOADED_FEATURES. We check the extension to avoid unnecessary
          # array lookups, since directories are not stored in $LOADED_FEATURES.
          $LOADED_FEATURES.delete(path) if ruby?(path)
        end

        autoloads.clear
        loaded.clear
        lazy_subdirs.clear
        shadowed.clear

        Registry.on_unload(self)
        ExplicitNamespace.unregister(self)

        @setup = false
      end
    end

    # Unloads all loaded code, and calls setup again so that the loader is able
    # to pick any changes in the file system.
    #
    # This method is not thread-safe, please see how this can be achieved by
    # client code in the README of the project.
    #
    # @return [void]
    def reload
      unload
      setup
    end

    # Eager loads all files in the root directories, recursively. Files do not
    # need to be in `$LOAD_PATH`, absolute file names are used. Ignored files
    # are not eager loaded.
    #
    # @return [void]
    def eager_load
      mutex.synchronize do
        break if @eager_loaded

        queue = non_ignored_root_dirs
        while dir = queue.shift
          each_abspath(dir) do |abspath|
            if ruby?(abspath)
              require abspath unless shadowed.key?(abspath)
            elsif dir?(abspath)
              queue << abspath
            end
          end
        end

        @eager_loaded = true
      end
    end

    # Says if the given constant path has been loaded.
    #
    # @param cpath [String]
    # @return [Boolean]
    def loaded?(cpath)
      loaded.member?(cpath)
    end

    # --- Class methods ---------------------------------------------------------------------------

    class << self
      # @return [#call, #debug, nil]
      attr_accessor :default_logger

      # @private
      # @return [Mutex]
      attr_accessor :mutex

      # This is a shortcut for
      #
      #   require "zeitwerk"
      #   loader = Zeitwerk::Loader.new
      #   loader.tag = File.basename(__FILE__, ".rb")
      #   loader.inflector = Zeitwerk::GemInflector.new
      #   loader.push_dir(__dir__)
      #
      # except that this method returns the same object in subsequent calls from
      # the same file, in the unlikely case the gem wants to be able to reload.
      #
      # @return [Zeitwerk::Loader]
      def for_gem
        called_from = caller[0].split(':')[0]
        Registry.loader_for_gem(called_from)
      end

      # Broadcasts `eager_load` to all loaders.
      #
      # @return [void]
      def eager_load_all
        Registry.loaders.each(&:eager_load)
      end

      # Returns an array with the absolute paths of the root directories of all
      # registered loaders. This is a read-only collection.
      #
      # @return [<String>]
      def all_dirs
        Registry.loaders.flat_map(&:dirs).freeze
      end
    end

    self.mutex = Mutex.new

    private # -------------------------------------------------------------------------------------

    # @return [<String>]
    def non_ignored_root_dirs
      root_dirs.keys.delete_if { |root_dir| ignored_paths.member?(root_dir) }
    end

    # @param dir [String]
    # @param parent [Module]
    # @return [void]
    def set_autoloads_in_dir(dir, parent)
      each_abspath(dir) do |abspath|
        cname = inflector.camelize(File.basename(abspath, ".rb"), abspath)
        if ruby?(abspath)
          autoload_file(parent, cname, abspath)
        elsif dir?(abspath)
          # In a Rails application, `app/models/concerns` is a subdirectory of
          # `app/models`, but both of them are root directories.
          #
          # To resolve the ambiguity file name -> constant path this introduces,
          # the `app/models/concerns` directory is totally ignored as a namespace,
          # it counts only as root. The guard checks that.
          autoload_subdir(parent, cname, abspath) unless root_dirs.key?(abspath)
        end
      end
    end

    # @param parent [Module]
    # @param cname [String]
    # @param subdir [String]
    # @return [void]
    def autoload_subdir(parent, cname, subdir)
      if autoload_path = autoload_for?(parent, cname)
        cpath = cpath(parent, cname)
        register_explicit_namespace(cpath) if ruby?(autoload_path)
        # We do not need to issue another autoload, the existing one is enough
        # no matter if it is for a file or a directory. Just remember the
        # subdirectory has to be visited if the namespace is used.
        (lazy_subdirs[cpath] ||= []) << subdir
      elsif !cdef?(parent, cname)
        # First time we find this namespace, set an autoload for it.
        (lazy_subdirs[cpath(parent, cname)] ||= []) << subdir
        set_autoload(parent, cname, subdir)
      else
        # For whatever reason the constant that corresponds to this namespace has
        # already been defined, we have to recurse.
        set_autoloads_in_dir(subdir, parent.const_get(cname))
      end
    end

    # @param parent [Module]
    # @param cname [String]
    # @param file [String]
    # @return [void]
    def autoload_file(parent, cname, file)
      if autoload_path = autoload_for?(parent, cname)
        # First autoload for a Ruby file wins, just ignore subsequent ones.
        shadowed[file] = autoload_path and return if ruby?(autoload_path)

        # Override autovivification, we want the namespace to become the
        # class/module defined in this file.
        autoloads.delete(autoload_path)
        Registry.unregister_autoload(autoload_path)

        set_autoload(parent, cname, file)
        register_explicit_namespace(cpath(parent, cname))
      elsif cdef?(parent, cname)
        shadowed[file] = cpath(parent, cname)
      else
        set_autoload(parent, cname, file)
      end
    end

    # @param parent [Module]
    # @param cname [String]
    # @param abspath [String]
    # @return [void]
    def set_autoload(parent, cname, abspath)
      # $LOADED_FEATURES stores real paths since Ruby 2.4.4. We set and save the
      # real path to be able to delete it from $LOADED_FEATURES on unload, and to
      # be able to do a lookup later in Kernel#require for manual require calls.
      realpath = File.realpath(abspath)
      parent.autoload(cname, realpath)
      if logger
        if ruby?(realpath)
          log("autoload set for #{cpath(parent, cname)}, to be loaded from #{realpath}")
        else
          log("autoload set for #{cpath(parent, cname)}, to be autovivified from #{realpath}")
        end
      end

      autoloads[realpath] = [parent, cname]
      Registry.register_autoload(self, realpath)

      # See why in the documentation of Zeitwerk::Registry.inceptions.
      unless parent.autoload?(cname)
        Registry.register_inception(cpath(parent, cname), realpath, self)
      end
    end

    # @param parent [Module]
    # @param cname [String]
    # @return [String, nil]
    def autoload_for?(parent, cname)
      strict_autoload_path(parent, cname) || Registry.inception?(cpath(parent, cname))
    end

    # The autoload? predicate takes into account the ancestor chain of the
    # receiver, like const_defined? and other methods in the constants API do.
    #
    # For example, given
    #
    #   class A
    #     autoload :X, "x.rb"
    #   end
    #
    #   class B < A
    #   end
    #
    # B.autoload?(:X) returns "x.rb".
    #
    # We need a way to strictly check in parent ignoring ancestors.
    #
    # @param parent [Module]
    # @param cname [String]
    # @return [String, nil]
    def strict_autoload_path(parent, cname)
      if autoload_path = parent.autoload?(cname)
        # Due to the use cases we have, we are done if parent is a Module.
        return autoload_path unless parent.is_a?(Class)
        # Since file and constant names match, if both parent and one of its
        # ancestors have an autoload for the same cname, their autoload paths
        # cannot be equal.
        return autoload_path unless parent.superclass.autoload?(cname) == autoload_path
      end
    end

    # This method is called this way because I prefer `preload` to be the method
    # name to configure preloads in the public interface.
    #
    # @return [void]
    def do_preload
      preloads.each do |abspath|
        do_preload_abspath(abspath)
      end
    end

    # @param abspath [String]
    # @return [void]
    def do_preload_abspath(abspath)
      if ruby?(abspath)
        do_preload_file(abspath)
      elsif dir?(abspath)
        do_preload_dir(abspath)
      end
    end

    # @param dir [String]
    # @return [void]
    def do_preload_dir(dir)
      each_abspath(dir) do |abspath|
        do_preload_abspath(abspath)
      end
    end

    # @param file [String]
    # @return [Boolean]
    def do_preload_file(file)
      log("preloading #{file}") if logger
      require file
    end

    # @param parent [Module]
    # @param cname [String]
    # @return [String]
    def cpath(parent, cname)
      parent.equal?(Object) ? cname : "#{parent.name}::#{cname}"
    end

    # @param dir [String]
    # @yieldparam path [String]
    # @return [void]
    def each_abspath(dir)
      Dir.foreach(dir) do |entry|
        next if entry.start_with?(".")
        abspath = File.join(dir, entry)
        yield abspath unless ignored_paths.member?(abspath)
      end
    end

    # @param path [String]
    # @return [Boolean]
    def ruby?(path)
      path.end_with?(".rb")
    end

    # @param path [String]
    # @return [Boolean]
    def dir?(path)
      File.directory?(path)
    end

    # @param paths [<String, Pathname, <String, Pathname>>]
    # @return [<String>]
    def expand_paths(paths)
      Array(paths).flatten.map { |path| File.expand_path(path) }
    end

    # @param message [String]
    # @return [void]
    def log(message)
      method_name = logger.respond_to?(:debug) ? :debug : :call
      logger.send(method_name, "Zeitwerk@#{tag}: #{message}")
    end

    def cdef?(parent, cname)
      parent.const_defined?(cname, false)
    end

    def register_explicit_namespace(cpath)
      ExplicitNamespace.register(cpath, self)
    end

    def raise_if_conflicting_directory(dir)
      self.class.mutex.synchronize do
        Registry.loaders.each do |loader|
          next if loader == self

          loader.dirs.each do |already_managed_dir|
            if dir.start_with?(already_managed_dir) || already_managed_dir.start_with?(dir)
              require "pp"
              raise ConflictingDirectory,
                "loader\n\n#{pretty_inspect}\n\nwants to manage directory #{dir}," \
                " which is already managed by\n\n#{loader.pretty_inspect}\n"
              EOS
            end
          end
        end
      end
    end
  end
end
