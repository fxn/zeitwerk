require "test_helper"

class TestAllDirs < LoaderTest
  test "returns an empty array if no loaders are instantiated" do
    assert_empty Zeitwerk::Loader.all_dirs
  end

  test "returns an empty array if there are loaders but they have no root dirs" do
    2.times { Zeitwerk::Loader.new }
    assert_empty Zeitwerk::Loader.all_dirs
  end

  test "returns the root directories of the registered loaders" do
    files = [
      ["loaderA/a.rb", "A = true"],
      ["loaderB/b.rb", "B = true"]
    ]
    with_files(files) do
      loaderA = Zeitwerk::Loader.new
      loaderA.push_dir("loaderA")

      loaderB = Zeitwerk::Loader.new
      loaderB.push_dir("loaderB")

      assert_equal ["#{Dir.pwd}/loaderA", "#{Dir.pwd}/loaderB"], Zeitwerk::Loader.all_dirs
    end
  end
end
