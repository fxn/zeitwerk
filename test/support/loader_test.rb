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
  def new_loader(dirs: [], enable_reloading: true, setup: true)
    Zeitwerk::Loader.new.tap do |loader|
      Array(dirs).each do |dir|
        loader.push_dir(dir)
      end
      loader.enable_reloading if enable_reloading
      loader.setup            if setup
    end
  end

  def reset_constants
    Zeitwerk::Registry.loaders.each(&:unload)
  end

  def reset_registry
    Zeitwerk::Registry.loaders.clear
    Zeitwerk::Registry.loaders_managing_gems.clear
  end

  def reset_explicit_namespace
    Zeitwerk::ExplicitNamespace.cpaths.clear
    Zeitwerk::ExplicitNamespace.tracer.disable
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
        File.write(fname, contents)
      end

      begin
        yield
      ensure
        mkdir_test if rm
      end
    end
  end

  def with_load_path(dirs = loader.dirs)
    Array(dirs).each { |dir| $LOAD_PATH.push(dir) }
    yield
  ensure
    Array(dirs).each { |dir| $LOAD_PATH.delete(dir) }
  end

  def with_setup(files, dirs: ".", load_path: nil, rm: true)
    with_files(files, rm: rm) do
      Array(dirs).each { |dir| loader.push_dir(dir) }
      loader.setup
      if load_path
        with_load_path(load_path) { yield }
      else
        yield
      end
    end
  end
end
