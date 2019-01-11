require "test_helper"

class TestCallbacks < LoaderTest
  test "autoloading a file triggers on_file_loaded" do
    def loader.on_file_loaded(file)
      if file == File.realpath("x.rb")
        $on_file_loaded_called = true
      end
      super
    end

    files = [["x.rb", "X = true"]]
    with_setup(files) do
      $on_file_loaded_called = false
      assert X
      assert $on_file_loaded_called
    end
  end

  test "requiring an autoloadable file triggers on_file_loaded" do
    def loader.on_file_loaded(file)
      if file == File.realpath("y.rb")
        $on_file_loaded_called = true
      end
      super
    end

    files = [
      ["x.rb", "X = true"],
      ["y.rb", "Y = X"]
    ]
    with_setup(files, load_path: ".") do
      $on_file_loaded_called = false
      require "y"
      assert Y
      assert $on_file_loaded_called
    end
  end

  test "autoloading a directory triggers on_dir_loaded" do
    def loader.on_dir_loaded(dir)
      if dir == File.realpath("m")
        $on_dir_loaded_called = true
      end
      super
    end

    files = [["m/x.rb", "M::X = true"]]
    with_setup(files) do
      $on_dir_loaded_called = false
      assert M::X
      assert $on_dir_loaded_called
    end
  end
end
