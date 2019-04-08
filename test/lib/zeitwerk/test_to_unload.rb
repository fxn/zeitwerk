require "test_helper"
require "set"

class TestToUnload < LoaderTest
  test "a loader that has loading nothing, has nothing to unload" do
    files = [["x.rb", "X = true"]]
    with_setup(files) do
      assert_empty loader.to_unload
      assert !loader.to_unload?("X")
    end
  end

  test "a loader that loaded some stuff has that stuff to be unloaded if reloading is enabled" do
    files = [
      ["m/x.rb", "M::X = true"],
      ["m/y.rb", "M::Y = true"],
      ["z.rb", "Z = true"]
    ]
    with_setup(files) do
      assert M::X

      assert loader.to_unload?("M")
      assert loader.to_unload?("M::X")

      assert !loader.to_unload?("M::Y")
      assert !loader.to_unload?("Z")
    end
  end

  test "a loader that loaded some stuff has nothing to unload if reloading is disabled" do
    on_teardown do
      remove_const :M
      delete_loaded_feature "m/x.rb"
      delete_loaded_feature "m/y.rb"

      remove_const :Z
      delete_loaded_feature "z.rb"
    end
    files = [
      ["m/x.rb", "M::X = true"],
      ["m/y.rb", "M::Y = true"],
      ["z.rb", "Z = true"]
    ]
    with_files(files) do
      loader = new_loader(dirs: ".", enable_reloading: false)

      assert M::X
      assert M::Y
      assert Z

      assert loader.to_unload.empty?
    end
  end
end
