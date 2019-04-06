module Zeitwerk::Loader::Callbacks
  # Invoked from our decorated Kernel#require when a managed file is autoloaded.
  #
  # @private
  # @param file [String]
  # @return [void]
  def on_file_autoloaded(file)
    parent, cname = autoloads[file]
    loaded_cpaths.add(cpath(parent, cname))
    Zeitwerk::Registry.unregister_autoload(file)
    log("constant #{cpath(parent, cname)} loaded from file #{file}") if logger
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
    # Without the mutex and short-circuiting break, t2 would reset the module.
    # That not only would reassign the constant (undesirable per se) but, worse,
    # the module object created by t2 wouldn't have any of the autoloads for its
    # children, since t1 would have correctly deleted its lazy_subdirs entry.
    mutex2.synchronize do
      parent, cname = autoloads[dir]
      break if loaded_cpaths.include?(cpath(parent, cname))

      autovivified_module = parent.const_set(cname, Module.new)
      log("module #{autovivified_module.name} autovivified from directory #{dir}") if logger

      loaded_cpaths.add(autovivified_module.name)
      on_namespace_loaded(autovivified_module)
    end
  end

  # Invoked when a class or module is created or reopened, either from the
  # tracer or from module autovivification. If the namespace has matching
  # subdirectories, we descend into them now.
  #
  # @private
  # @param namespace [Module]
  # @return [void]
  def on_namespace_loaded(namespace)
    if subdirs = lazy_subdirs.delete(namespace.name)
      subdirs.each do |subdir|
        set_autoloads_in_dir(subdir, namespace)
      end
    end
  end
end
