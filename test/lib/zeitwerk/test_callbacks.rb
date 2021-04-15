require "test_helper"

class TestCallbacks < LoaderTest
  module Namespace; end

  test "autoloading a file triggers on_file_autoloaded (Object)" do
    def loader.on_file_autoloaded(file)
      if file == File.expand_path("x.rb")
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

  test "autoloading a file triggers on_file_autoloaded (Namespace)" do
    def loader.on_file_autoloaded(file)
      if file == File.expand_path("x.rb")
        $on_file_autoloaded_called = true
      end
      super
    end

    files = [["x.rb", "#{Namespace}::X = true"]]
    with_setup(files, namespace: Namespace) do
      $on_file_autoloaded_called = false
      assert Namespace::X
      assert $on_file_autoloaded_called
    end
  end

  test "requiring an autoloadable file triggers on_file_autoloaded (Object)" do
    def loader.on_file_autoloaded(file)
      if file == File.expand_path("y.rb")
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

  test "requiring an autoloadable file triggers on_file_autoloaded (Namespace)" do
    def loader.on_file_autoloaded(file)
      if file == File.expand_path("y.rb")
        $on_file_autoloaded_called = true
      end
      super
    end

    files = [
      ["x.rb", "#{Namespace}::X = true"],
      ["y.rb", "#{Namespace}::Y = #{Namespace}::X"]
    ]
    with_setup(files, namespace: Namespace, load_path: ".") do
      $on_file_autoloaded_called = false
      require "y"
      assert Namespace::Y
      assert $on_file_autoloaded_called
    end
  end

  test "autoloading a directory triggers on_dir_autoloaded (Object)" do
    def loader.on_dir_autoloaded(dir)
      if dir == File.expand_path("m")
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

  test "autoloading a directory triggers on_dir_autoloaded (Namespace)" do
    def loader.on_dir_autoloaded(dir)
      if dir == File.expand_path("m")
        $on_dir_autoloaded_called = true
      end
      super
    end

    files = [["m/x.rb", "#{Namespace}::M::X = true"]]
    with_setup(files, namespace: Namespace) do
      $on_dir_autoloaded_called = false
      assert Namespace::M::X
      assert $on_dir_autoloaded_called
    end
  end
end
