# frozen_string_literal: true

require "set"

module Zeitwerk
  class Loader
    require_relative "loader/helpers"
    require_relative "loader/callbacks"
    require_relative "loader/config"
    require_relative "loader/eager_load"

    include RealModName
    include Callbacks
    include Helpers
    include Config
    include EagerLoad

    MUTEX = Mutex.new
    private_constant :MUTEX

    # Maps absolute paths for which an autoload has been set ---and not
    # executed--- to their corresponding parent class or module and constant
    # name.
    #
    #   "/Users/fxn/blog/app/models/user.rb"          => [Object, :User],
    #   "/Users/fxn/blog/app/models/hotel/pricing.rb" => [Hotel, :Pricing]
    #   ...
    #
    # @private
    # @sig Hash[String, [Module, Symbol]]
    attr_reader :autoloads

    # We keep track of autoloaded directories to remove them from the registry
    # at the end of eager loading.
    #
    # Files are removed as they are autoloaded, but directories need to wait due
    # to concurrency (see why in Zeitwerk::Loader::Callbacks#on_dir_autoloaded).
    #
    # @private
    # @sig Array[String]
    attr_reader :autoloaded_dirs

    # Stores metadata needed for unloading. Its entries look like this:
    #
    #   "Admin::Role" => [".../admin/role.rb", [Admin, :Role]]
    #
    # The cpath as key helps implementing unloadable_cpath? The file name is
    # stored in order to be able to delete it from $LOADED_FEATURES, and the
    # pair [Module, Symbol] is used to remove_const the constant from the class
    # or module object.
    #
    # If reloading is enabled, this hash is filled as constants are autoloaded
    # or eager loaded. Otherwise, the collection remains empty.
    #
    # @private
    # @sig Hash[String, [String, [Module, Symbol]]]
    attr_reader :to_unload

    # Maps namespace constant paths to their respective directories.
    #
    # For example, given this mapping:
    #
    #   "Admin" => [
    #     "/Users/fxn/blog/app/controllers/admin",
    #     "/Users/fxn/blog/app/models/admin",
    #     ...
    #   ]
    #
    # when `Admin` gets defined we know that it plays the role of a namespace
    # and that its children are spread over those directories. We'll visit them
    # to set up the corresponding autoloads.
    #
    # @private
    # @sig Hash[String, Array[String]]
    attr_reader :namespace_dirs

    # A shadowed file is a file managed by this loader that is ignored when
    # setting autoloads because its matching constant is already taken.
    #
    # This private set is populated as we descend. For example, if the loader
    # has only scanned the top-level, `shadowed_files` does not have shadowed
    # files that may exist deep in the project tree yet.
    #
    # @private
    # @sig Set[String]
    attr_reader :shadowed_files

    # @private
    # @sig Mutex
    attr_reader :mutex

    # @private
    # @sig Mutex
    attr_reader :mutex2

    def initialize
      super

      @autoloads       = {}
      @autoloaded_dirs = []
      @to_unload       = {}
      @namespace_dirs  = Hash.new { |h, cpath| h[cpath] = [] }
      @shadowed_files  = Set.new
      @mutex           = Mutex.new
      @mutex2          = Mutex.new
      @setup           = false
      @eager_loaded    = false

      Registry.register_loader(self)
    end

    # Sets autoloads in the root namespaces.
    #
    # @sig () -> void
    def setup
      mutex.synchronize do
        break if @setup

        actual_roots.each do |root_dir, root_namespace|
          set_autoloads_in_dir(root_dir, root_namespace)
        end

        on_setup_callbacks.each(&:call)

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
    # This method is public but undocumented. Main interface is `reload`, which
    # means `unload` + `setup`. This one is available to be used together with
    # `unregister`, which is undocumented too.
    #
    # @sig () -> void
    def unload
      mutex.synchronize do
        raise SetupRequired unless @setup

        # We are going to keep track of the files that were required by our
        # autoloads to later remove them from $LOADED_FEATURES, thus making them
        # loadable by Kernel#require again.
        #
        # Directories are not stored in $LOADED_FEATURES, keeping track of files
        # is enough.
        unloaded_files = Set.new

        autoloads.each do |abspath, (parent, cname)|
          if parent.autoload?(cname)
            unload_autoload(parent, cname)
          else
            # Could happen if loaded with require_relative. That is unsupported,
            # and the constant path would escape unloadable_cpath? This is just
            # defensive code to clean things up as much as we are able to.
            unload_cref(parent, cname)
            unloaded_files.add(abspath) if ruby?(abspath)
          end
        end

        to_unload.each do |cpath, (abspath, (parent, cname))|
          unless on_unload_callbacks.empty?
            begin
              value = cget(parent, cname)
            rescue ::NameError
              # Perhaps the user deleted the constant by hand, or perhaps an
              # autoload failed to define the expected constant but the user
              # rescued the exception.
            else
              run_on_unload_callbacks(cpath, value, abspath)
            end
          end

          unload_cref(parent, cname)
          unloaded_files.add(abspath) if ruby?(abspath)
        end

        unless unloaded_files.empty?
          # Bootsnap decorates Kernel#require to speed it up using a cache and
          # this optimization does not check if $LOADED_FEATURES has the file.
          #
          # To make it aware of changes, the gem defines singleton methods in
          # $LOADED_FEATURES:
          #
          #   https://github.com/Shopify/bootsnap/blob/master/lib/bootsnap/load_path_cache/core_ext/loaded_features.rb
          #
          # Rails applications may depend on bootsnap, so for unloading to work
          # in that setting it is preferable that we restrict our API choice to
          # one of those methods.
          $LOADED_FEATURES.reject! { |file| unloaded_files.member?(file) }
        end

        autoloads.clear
        autoloaded_dirs.clear
        to_unload.clear
        namespace_dirs.clear
        shadowed_files.clear

        Registry.on_unload(self)
        ExplicitNamespace.__unregister_loader(self)

        @setup        = false
        @eager_loaded = false
      end
    end

    # Unloads all loaded code, and calls setup again so that the loader is able
    # to pick any changes in the file system.
    #
    # This method is not thread-safe, please see how this can be achieved by
    # client code in the README of the project.
    #
    # @raise [Zeitwerk::Error]
    # @sig () -> void
    def reload
      raise ReloadingDisabledError unless reloading_enabled?
      raise SetupRequired unless @setup

      unload
      recompute_ignored_paths
      recompute_collapse_dirs
      setup
    end

    # Says if the given constant path would be unloaded on reload. This
    # predicate returns `false` if reloading is disabled.
    #
    # @sig (String) -> bool
    def unloadable_cpath?(cpath)
      to_unload.key?(cpath)
    end

    # Returns an array with the constant paths that would be unloaded on reload.
    # This predicate returns an empty array if reloading is disabled.
    #
    # @sig () -> Array[String]
    def unloadable_cpaths
      to_unload.keys.freeze
    end

    # This is a dangerous method.
    #
    # @experimental
    # @sig () -> void
    def unregister
      Registry.unregister_loader(self)
      ExplicitNamespace.__unregister_loader(self)
    end

    # The return value of this predicate is only meaningful if the loader has
    # scanned the file. This is the case in the spots where we use it.
    #
    # @private
    # @sig (String) -> Boolean
    def shadowed_file?(file)
      shadowed_files.member?(file)
    end

    # --- Class methods ---------------------------------------------------------------------------

    class << self
      # @sig #call | #debug | nil
      attr_accessor :default_logger

      # This is a shortcut for
      #
      #   require "zeitwerk"
      #   loader = Zeitwerk::Loader.new
      #   loader.tag = File.basename(__FILE__, ".rb")
      #   loader.inflector = Zeitwerk::GemInflector.new(__FILE__)
      #   loader.push_dir(__dir__)
      #
      # except that this method returns the same object in subsequent calls from
      # the same file, in the unlikely case the gem wants to be able to reload.
      #
      # This method returns a subclass of Zeitwerk::Loader, but the exact type
      # is private, client code can only rely on the interface.
      #
      # @sig (bool) -> Zeitwerk::GemLoader
      def for_gem(warn_on_extra_files: true)
        called_from = caller_locations(1, 1).first.path
        Registry.loader_for_gem(called_from, warn_on_extra_files: warn_on_extra_files)
      end

      # Broadcasts `eager_load` to all loaders. Those that have not been setup
      # are skipped.
      #
      # @sig () -> void
      def eager_load_all
        Registry.loaders.each do |loader|
          begin
            loader.eager_load
          rescue SetupRequired
            # This is fine, we eager load what can be eager loaded.
          end
        end
      end

      # Broadcasts `eager_load_namespace` to all loaders. Those that have not
      # been setup are skipped.
      #
      # @sig (Module) -> void
      def eager_load_namespace(mod)
        Registry.loaders.each do |loader|
          begin
            loader.eager_load_namespace(mod)
          rescue SetupRequired
            # This is fine, we eager load what can be eager loaded.
          end
        end
      end

      # Returns an array with the absolute paths of the root directories of all
      # registered loaders. This is a read-only collection.
      #
      # @sig () -> Array[String]
      def all_dirs
        Registry.loaders.flat_map(&:dirs).freeze
      end
    end

    private # -------------------------------------------------------------------------------------

    # @sig (String, Module) -> void
    def set_autoloads_in_dir(dir, parent)
      ls(dir) do |basename, abspath|
        begin
          if ruby?(basename)
            basename.delete_suffix!(".rb")
            cname = inflector.camelize(basename, abspath).to_sym
            autoload_file(parent, cname, abspath)
          else
            if collapse?(abspath)
              set_autoloads_in_dir(abspath, parent)
            else
              cname = inflector.camelize(basename, abspath).to_sym
              autoload_subdir(parent, cname, abspath)
            end
          end
        rescue ::NameError => error
          path_type = ruby?(abspath) ? "file" : "directory"

          raise NameError.new(<<~MESSAGE, error.name)
            #{error.message} inferred by #{inflector.class} from #{path_type}

              #{abspath}

            Possible ways to address this:

              * Tell Zeitwerk to ignore this particular #{path_type}.
              * Tell Zeitwerk to ignore one of its parent directories.
              * Rename the #{path_type} to comply with the naming conventions.
              * Modify the inflector to handle this case.
          MESSAGE
        end
      end
    end

    # @sig (Module, Symbol, String) -> void
    def autoload_subdir(parent, cname, subdir)
      if autoload_path = autoload_path_set_by_me_for?(parent, cname)
        # We do not need to issue another autoload, the existing one is enough
        # no matter if it is for a file or a directory. Just remember the
        # subdirectory has to be visited if the namespace is used.
        namespace_dirs[cpath(parent, cname)] << subdir
      elsif !cdef?(parent, cname)
        # First time we find this namespace, set an autoload for it.
        namespace_dirs[cpath(parent, cname)] << subdir
        set_autoload(parent, cname, subdir)
      else
        # For whatever reason the constant that corresponds to this namespace has
        # already been defined, we have to recurse.
        log("the namespace #{cpath(parent, cname)} already exists, descending into #{subdir}") if logger
        set_autoloads_in_dir(subdir, cget(parent, cname))
      end
    end

    # @sig (Module, Symbol, String) -> void
    def autoload_file(parent, cname, file)
      if autoload_path = strict_autoload_path(parent, cname) || Registry.inception?(cpath(parent, cname))
        # First autoload for a Ruby file wins, just ignore subsequent ones.
        if ruby?(autoload_path)
          shadowed_files << file
          log("file #{file} is ignored because #{autoload_path} has precedence") if logger
        else
          promote_namespace_from_implicit_to_explicit(
            dir:    autoload_path,
            file:   file,
            parent: parent,
            cname:  cname
          )
        end
      elsif cdef?(parent, cname)
        shadowed_files << file
        log("file #{file} is ignored because #{cpath(parent, cname)} is already defined") if logger
      else
        set_autoload(parent, cname, file)
      end
    end

    # `dir` is the directory that would have autovivified a namespace. `file` is
    # the file where we've found the namespace is explicitly defined.
    #
    # @sig (dir: String, file: String, parent: Module, cname: Symbol) -> void
    def promote_namespace_from_implicit_to_explicit(dir:, file:, parent:, cname:)
      autoloads.delete(dir)
      Registry.unregister_autoload(dir)

      log("earlier autoload for #{cpath(parent, cname)} discarded, it is actually an explicit namespace defined in #{file}") if logger

      set_autoload(parent, cname, file)
      register_explicit_namespace(cpath(parent, cname))
    end

    # @sig (Module, Symbol, String) -> void
    def set_autoload(parent, cname, abspath)
      parent.autoload(cname, abspath)

      if logger
        if ruby?(abspath)
          log("autoload set for #{cpath(parent, cname)}, to be loaded from #{abspath}")
        else
          log("autoload set for #{cpath(parent, cname)}, to be autovivified from #{abspath}")
        end
      end

      autoloads[abspath] = [parent, cname]
      Registry.register_autoload(self, abspath)

      # See why in the documentation of Zeitwerk::Registry.inceptions.
      unless parent.autoload?(cname)
        Registry.register_inception(cpath(parent, cname), abspath, self)
      end
    end

    # @sig (Module, Symbol) -> String?
    def autoload_path_set_by_me_for?(parent, cname)
      if autoload_path = strict_autoload_path(parent, cname)
        autoload_path if autoloads.key?(autoload_path)
      else
        Registry.inception?(cpath(parent, cname))
      end
    end

    # @sig (String) -> void
    def register_explicit_namespace(cpath)
      ExplicitNamespace.__register(cpath, self)
    end

    # @sig (String) -> void
    def raise_if_conflicting_directory(dir)
      MUTEX.synchronize do
        dir_slash = dir + "/"

        Registry.loaders.each do |loader|
          next if loader == self
          next if loader.__ignores?(dir)

          loader.__roots.each_key do |root_dir|
            next if ignores?(root_dir)

            root_dir_slash = root_dir + "/"
            if dir_slash.start_with?(root_dir_slash) || root_dir_slash.start_with?(dir_slash)
              require "pp" # Needed for pretty_inspect, even in Ruby 2.5.
              raise Error,
                "loader\n\n#{pretty_inspect}\n\nwants to manage directory #{dir}," \
                " which is already managed by\n\n#{loader.pretty_inspect}\n"
              EOS
            end
          end
        end
      end
    end

    # @sig (String, Object, String) -> void
    def run_on_unload_callbacks(cpath, value, abspath)
      # Order matters. If present, run the most specific one.
      on_unload_callbacks[cpath]&.each { |c| c.call(value, abspath) }
      on_unload_callbacks[:ANY]&.each { |c| c.call(cpath, value, abspath) }
    end

    # @sig (Module, Symbol) -> void
    def unload_autoload(parent, cname)
      parent.__send__(:remove_const, cname)
      log("autoload for #{cpath(parent, cname)} removed") if logger
    end

    # @sig (Module, Symbol) -> void
    def unload_cref(parent, cname)
      # Let's optimistically remove_const. The way we use it, this is going to
      # succeed always if all is good.
      parent.__send__(:remove_const, cname)
    rescue ::NameError
      # There are a few edge scenarios in which this may happen. If the constant
      # is gone, that is OK, anyway.
    else
      log("#{cpath(parent, cname)} unloaded") if logger
    end
  end
end
