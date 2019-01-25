require "test_helper"

class TestLoaded < LoaderTest
  test "a new loader has loaded nothing" do
    assert_empty Zeitwerk::Loader.new.loaded
  end

  test "a loader that has loading nothing, has loaded nothing" do
    files = [["x.rb", "X = true"]]
    with_setup(files) do
      assert_empty loader.loaded
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
      assert_equal %w(M M::X).sort, loader.loaded.sort
    end
  end
end
