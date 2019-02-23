module Zeitwerk::Loader::Callbacks
  # Invoked from our decorated Kernel#require when a managed file is autoloaded.
  #
  # @private
  # @param file [String]
  # @return [void]
  def on_file_autoloaded(file)
    parent, cname = autoloads[file]
    loaded.add(cpath(parent, cname))
    log("constant #{cpath(parent, cname)} loaded from file #{file}") if logger
  end

  # Invoked from our decorated Kernel#require when a managed directory is
  # autoloaded.
  #
  # @private
  # @param dir [String]
  # @return [void]
  def on_dir_autoloaded(dir)
    parent, cname = autoloads[dir]

    autovivified_module = parent.const_set(cname, Module.new)
    log("module #{autovivified_module.name} autovivified from directory #{dir}") if logger

    loaded.add(autovivified_module.name)
    on_namespace_loaded(autovivified_module)
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
