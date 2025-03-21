# frozen_string_literal: true

class LoaderTest < Minitest::Test
  TMP_DIR = File.expand_path("../tmp", __dir__)

  attr_reader :loader

  def setup
    @loader = new_loader(setup: false)
  end

  # We enable reloading in the reloaders of the test suite to have a robust
  # cleanup of constants.
  #
  # There are gems that allow you to run tests in forked processes and you do
  # not need to care, but JRuby does not support forking, and I prefer to be
  # ready for the day in which Zeitwerk runs on JRuby.
  def new_loader(dirs: [], namespace: Object, enable_reloading: true, setup: true)
    Zeitwerk::Loader.new.tap do |loader|
      Array(dirs).each do |dir|
        loader.push_dir(dir, namespace: namespace)
      end
      loader.enable_reloading if enable_reloading
      loader.setup            if setup
    end
  end

  def reset_constants
    Zeitwerk::Registry.loaders.each do |loader|
      begin
        loader.unload
      rescue Zeitwerk::SetupRequired
      end
    end
  end

  def reset_registry
    Zeitwerk::Registry.loaders.clear
    Zeitwerk::Registry.gem_loaders_by_root_file.clear
    Zeitwerk::Registry.autoloads.clear
    Zeitwerk::Registry.inceptions.clear
  end

  def reset_explicit_namespace
    Zeitwerk::Registry.explicit_namespaces.clear
  end

  def teardown
    reset_constants
    reset_registry
    reset_explicit_namespace
  end

  def mkdir_test
    FileUtils.rm_rf(TMP_DIR)
    FileUtils.mkdir_p(TMP_DIR)
  end

  def with_files(files, rm: true)
    mkdir_test

    Dir.chdir(TMP_DIR) do
      files.each do |fname, contents|
        FileUtils.mkdir_p(File.dirname(fname))
        if contents
          File.write(fname, contents)
        else
          FileUtils.touch(fname)
        end
      end
      yield
    end
  ensure
    mkdir_test if rm
  end

  def with_load_path(dirs = loader.dirs)
    dirs = Array(dirs).map { |dir| File.expand_path(dir) }
    dirs.each { |dir| $LOAD_PATH.push(dir) }
    yield
  ensure
    dirs.each { |dir| $LOAD_PATH.delete(dir) }
  end

  def with_setup(files = [], dirs: nil, namespace: Object, load_path: nil, rm: true)
    with_files(files, rm: rm) do
      dirs ||= files.map do |file|
        file[0] =~ %r{\A(rd\d+)/} ? $1 : "."
      end.uniq
      dirs.each { |dir| loader.push_dir(dir, namespace: namespace) }

      files.each do |file|
        if File.basename(file[0]) == "ignored.rb"
          loader.ignore(file[0])
        elsif file[0] =~ %r{\A(ignored|.+/ignored)/}
          loader.ignore($1)
        end

        if file[0] =~ %r{\A(collapsed|.+/collapsed)/}
          loader.collapse($1)
        end
      end

      loader.setup
      if load_path
        with_load_path(load_path) { yield }
      else
        yield
      end
    end
  end

  def required?(file_or_files)
    if file_or_files.is_a?(String)
      $LOADED_FEATURES.include?(File.expand_path(file_or_files, TMP_DIR))
    elsif file_or_files[0].is_a?(String)
      required?(file_or_files[0])
    else
      file_or_files.all? { |f| required?(f) }
    end
  end

  def assert_abspath(expected, actual)
    assert_equal(File.expand_path(expected, TMP_DIR), actual)
  end
end
