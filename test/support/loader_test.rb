class LoaderTest < Minitest::Test
  TMP_DIR = File.expand_path("../tmp", __dir__).freeze

  attr_reader :loader

  def setup
    @loader = Zeitwerk::Loader.new
  end

  def with_files(files, rm: true)
    FileUtils.rm_rf(TMP_DIR)
    FileUtils.mkdir_p(TMP_DIR)

    Dir.chdir(TMP_DIR) do
      files.each do |fname, contents|
        FileUtils.mkdir_p(File.dirname(fname))
        File.write(fname, contents)
      end

      begin
        yield
      ensure
        FileUtils.rm_rf(TMP_DIR) if rm
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
