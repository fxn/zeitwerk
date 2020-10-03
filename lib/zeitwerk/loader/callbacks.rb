module Zeitwerk::Loader::Callbacks
  include Zeitwerk::RealModName

  # Invoked from our decorated Kernel#require when a managed file is autoloaded.
  #
  # @private
  # @param file [String]
  # @return [void]
  def on_file_autoloaded(file)
    cref = autoloads.delete(file)
    to_unload[cpath(*cref)] = [file, cref] if reloading_enabled?
    Zeitwerk::Registry.unregister_autoload(file)

    if logger && cdef?(*cref)
      log("constant #{cpath(*cref)} loaded from file #{file}")
    elsif !cdef?(*cref)
      raise Zeitwerk::NameError.new("expected file #{file} to define constant #{cpath(*cref)}, but didn't", cref.last)
    end
  end

  # Invoked from our decorated Kernel#require when a managed directory is
  # autoloaded.
  #
  # @private
  # @param dir [String]
  # @return [void]
  def on_dir_autoloaded(dir)
    # Module#autoload does not serialize concurrent requires, and we handle
    # directories ourselves, so the callback needs to account for concurrency.
    #
    # Multi-threading would introduce a race condition here in which thread t1
    # autovivifies the module, and while autoloads for its children are being
    # set, thread t2 autoloads the same namespace.
    #
    # Without the mutex and subsequent delete call, t2 would reset the module.
    # That not only would reassign the constant (undesirable per se) but, worse,
    # the module object created by t2 wouldn't have any of the autoloads for its
    # children, since t1 would have correctly deleted its lazy_subdirs entry.
    mutex2.synchronize do
      if cref = autoloads.delete(dir)
        parent, cname = cref
        index_file = index_file_for_autoloaded_dir(parent, cname, dir)

        if index_file && File.exists?(index_file)
          realpath = File.realpath(index_file).freeze
          parent.autoload(cname, realpath)
          Kernel.require(index_file)

          to_unload[cpath(*cref)] = [index_file, cref] if reloading_enabled?

          if logger && cdef?(*cref)
            log("constant #{cpath(*cref)} loaded from file #{index_file}")
          elsif !cdef?(*cref)
            raise Zeitwerk::NameError.new("expected file #{index_file} to define constant #{cpath(*cref)}, but didn't", cref.last)
          end

          loaded_module = parent.const_get(cname)

          # We don't unregister `dir` in the registry because concurrent threads
          # wouldn't find a loader associated to it in Kernel#require and would
          # try to require the directory. Instead, we are going to keep track of
          # these to be able to unregister later if eager loading.
          autoloaded_dirs << dir

          on_namespace_loaded(loaded_module, index_file)
        else
          autovivified_module = parent.const_set(cname, Module.new)
          log("module #{autovivified_module.name} autovivified from directory #{dir}") if logger

          to_unload[autovivified_module.name] = [dir, cref] if reloading_enabled?

          # We don't unregister `dir` in the registry because concurrent threads
          # wouldn't find a loader associated to it in Kernel#require and would
          # try to require the directory. Instead, we are going to keep track of
          # these to be able to unregister later if eager loading.
          autoloaded_dirs << dir

          on_namespace_loaded(autovivified_module)
        end
      end
    end
  end

  # Invoked when a class or module is created or reopened, either from the
  # tracer or from module autovivification. If the namespace has matching
  # subdirectories, we descend into them now.
  #
  # @private
  # @param namespace [Module]
  # @return [void]
  def on_namespace_loaded(namespace, current_file = nil)
    if subdirs = lazy_subdirs.delete(real_mod_name(namespace))
      subdirs.each do |subdir|
        set_autoloads_in_dir(subdir, namespace, current_file)
      end
    end
  end
end
