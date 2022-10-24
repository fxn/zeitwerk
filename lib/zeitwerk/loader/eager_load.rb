module Zeitwerk::Loader::EagerLoad
  # Eager loads all files in the root directories, recursively. Files do not
  # need to be in `$LOAD_PATH`, absolute file names are used. Ignored and
  # shadowed files are not eager loaded. You can opt-out specifically in
  # specific files and directories with `do_not_eager_load`, and that can be
  # overridden passing `force: true`.
  #
  # @sig (true | false) -> void
  def eager_load(force: false)
    mutex.synchronize do
      break if @eager_loaded

      log("eager load start") if logger

      actual_root_dirs.each do |root_dir, namespace|
        actual_eager_load_dir(root_dir, namespace, force: force)
      end

      autoloaded_dirs.each do |autoloaded_dir|
        Zeitwerk::Registry.unregister_autoload(autoloaded_dir)
      end
      autoloaded_dirs.clear

      @eager_loaded = true

      log("eager load end") if logger
    end
  end

  def eager_load_dir(path)
    abspath = File.expand_path(path)
    unless dir?(abspath)
      raise Zeitwerk::Error.new("#{abspath} is not a directory")
    end

    if namespace = namespace_at(abspath)
      actual_eager_load_dir(abspath, namespace)
    end
  end

  def eager_load_namespace(mod)
    unless mod.is_a?(Module)
      raise Zeitwerk::Error, "#{mod.inspect} is not a class or module object"
    end

    actual_root_dirs.each do |root_dir, root_namespace|
      if mod.equal?(Object)
        actual_eager_load_dir(root_dir, root_namespace)
      elsif root_namespace.equal?(Object)
        eager_load_child_namespace(mod, root_dir, root_namespace)
      else
        mod_name = real_mod_name(mod)
        root_namespace_name = real_mod_name(root_namespace)

        if root_namespace_name.start_with?(mod_name + "::")
          actual_eager_load_dir(root_dir, root_namespace)
        elsif mod_name == root_namespace_name
          actual_eager_load_dir(root_dir, root_namespace)
        elsif mod_name.start_with?(root_namespace_name + "::")
          eager_load_child_namespace(mod, root_dir, root_namespace)
        else
          # Unrelated constant hierarchies, do nothing.
        end
      end
    end
  end

  # @sig (String) -> Module | nil
  def namespace_at(path)
    abspath = File.expand_path(path)
    return if !File.exist?(abspath) || ignores?(abspath)

    unless dir?(abspath)
      if ruby?(abspath)
        abspath = File.dirname(abspath)
      else
        return
      end
    end

    cnames = []

    walk_up(abspath) do |dir|
      if namespace = root_dirs[dir]
        cnames.reverse_each do |cname|
          # Could happen if none of these directories have Ruby files.
          return unless cdef?(namespace, cname)
          namespace = cget(namespace, cname)
        end
        return namespace
      end

      unless collapse?(dir)
        basename = File.basename(dir)
        cnames << inflector.camelize(basename, dir).to_sym
      end
    end
  end

  # The caller is responsible for making sure `namespace` is the namespace that
  # corresponds to `dir`.
  #
  # @sig (String, Module, Boolean) -> void
  private def actual_eager_load_dir(dir, namespace, force: false)
    honour_exclusions = !force
    return if honour_exclusions && excluded_from_eager_load?(dir)

    log("eager load directory #{dir} start") if logger

    queue = [[dir, namespace]]
    while to_eager_load = queue.shift
      dir, namespace = to_eager_load

      ls(dir) do |basename, abspath|
        next if honour_exclusions && eager_load_exclusions.member?(abspath)

        if ruby?(abspath)
          if (cref = autoloads[abspath]) && !shadowed_file?(abspath)
            cget(*cref)
          end
        else
          if collapse?(abspath)
            queue << [abspath, namespace]
          else
            cname = inflector.camelize(basename, abspath).to_sym
            queue << [abspath, cget(namespace, cname)]
          end
        end
      end
    end

    log("eager load directory #{dir} end") if logger
  end

  # In order to invoke this method, the caller has to ensure `child` is a
  # strict namespace descendendant of `root_namespace`.
  #
  # @sig (Module, String, Module, Boolean) -> void
  private def eager_load_child_namespace(child, root_dir, root_namespace)
    suffix = real_mod_name(child)
    unless root_namespace.equal?(Object)
      suffix = suffix.delete_prefix(real_mod_name(root_namespace) + "::")
    end

    # These directories are at the same namespace level, there may be more if
    # we find collapsed ones. As we scan, we look for matches for the first
    # segment, and store them in `next_dirs`. If there are any, we look for
    # the next segments in those matches. Repeat.
    #
    # If we exhaust the search locating directories that match all segments,
    # we just need to eager load those ones.
    dirs = [root_dir]
    next_dirs = []

    suffix.split("::").each do |segment|
      while dir = dirs.shift
        ls(dir) do |basename, abspath|
          next unless dir?(abspath)

          if collapse?(abspath)
            current_dirs << abspath
          elsif segment == inflector.camelize(basename, abspath)
            next_dirs << abspath
          end
        end
      end

      return if next_dirs.empty?

      dirs.replace(next_dirs)
      next_dirs.clear
    end

    dirs.each do |dir|
      actual_eager_load_dir(dir, child)
    end
  end
end
