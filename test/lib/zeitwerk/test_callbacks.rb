require "test_helper"

class TestCallbacks < LoaderTest
  test "autoloading a file triggers on_file_autoloaded" do
    def loader.on_file_autoloaded(file)
      if file == File.realpath("x.rb")
        $on_file_autoloaded_called = true
      end
      super
    end

    files = [["x.rb", "X = true"]]
    with_setup(files) do
      $on_file_autoloaded_called = false
      assert X
      assert $on_file_autoloaded_called
    end
  end

  test "requiring an autoloadable file triggers on_file_autoloaded" do
    def loader.on_file_autoloaded(file)
      if file == File.realpath("y.rb")
        $on_file_autoloaded_called = true
      end
      super
    end

    files = [
      ["x.rb", "X = true"],
      ["y.rb", "Y = X"]
    ]
    with_setup(files, load_path: ".") do
      $on_file_autoloaded_called = false
      require "y"
      assert Y
      assert $on_file_autoloaded_called
    end
  end

  test "autoloading a directory triggers on_dir_autoloaded" do
    def loader.on_dir_autoloaded(dir)
      if dir == File.realpath("m")
        $on_dir_autoloaded_called = true
      end
      super
    end

    files = [["m/x.rb", "M::X = true"]]
    with_setup(files) do
      $on_dir_autoloaded_called = false
      assert M::X
      assert $on_dir_autoloaded_called
    end
  end

  test "autoloading a module that overrides `Module#name`" do
    def loader.on_namespace_loaded(namespace)
      if A == namespace
        $on_namespace_loaded_called = true
      end
      super
    end

    files = [
      ["a/m.rb", "module A; def self.name; raise; end; M = true; end"],
    ]
    with_setup(files) do
      $on_namespace_loaded_called = false
      assert A::M
      assert $on_namespace_loaded_called
    end
  end

  test "autoloading a class that overrides `Class#name`" do
    def loader.on_namespace_loaded(namespace)
      if B == namespace
        $on_namespace_loaded_called = true
      end
      super
    end

    files = [
      ["b/m.rb", "class B < Class.new { def self.name; 'b'; end }; M = true; end"]
    ]
    with_setup(files) do
      $on_namespace_loaded_called = false
      assert B
      assert $on_namespace_loaded_called
    end
  end
end
