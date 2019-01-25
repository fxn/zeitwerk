require "test_helper"
require "set"

class TestLoaded < LoaderTest
  test "a new loader has loaded nothing" do
    assert_empty Zeitwerk::Loader.new.loaded
  end

  test "a loader that has loading nothing, has loaded nothing" do
    files = [["x.rb", "X = true"]]
    with_setup(files) do
      assert_empty loader.loaded
      assert !loader.loaded?("X")
    end
  end

  test "a loader that loaded some stuff has loaded said stuff" do
    files = [
      ["m/x.rb", "M::X = true"],
      ["m/y.rb", "M::Y = true"],
      ["z.rb", "Z = true"]
    ]
    with_setup(files) do
      assert M::X
      assert_equal %w(M M::X).to_set, loader.loaded

      assert loader.loaded?("M")
      assert loader.loaded?("M::X")

      assert !loader.loaded?("M::Y")
      assert !loader.loaded?("Z")
    end
  end
end
