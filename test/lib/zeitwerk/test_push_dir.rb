require "test_helper"
require "pathname"

class TesPushDir < LoaderTest
  test "accepts dirs as strings and stores their absolute paths" do
    loader.push_dir(".")
    assert loader.root_dirs == { Dir.pwd => Object }
    assert loader.dirs.include?(Dir.pwd)
  end

  test "accepts dirs as pathnames and stores their absolute paths" do
    loader.push_dir(Pathname.new("."))
    assert loader.root_dirs == { Dir.pwd => Object }
    assert loader.dirs.include?(Dir.pwd)
  end

  test "raises on non-existing directories" do
    dir = File.expand_path("non-existing")
    e = assert_raises(ArgumentError) { loader.push_dir(dir) }
    assert_equal "the root directory #{dir} does not exist", e.message
  end

  module MyApp
  end

  test "an alternative namespace can be passed" do
    files = [["app/x.rb", "TesPushDir::MyApp::X = true"]]
    with_setup(files, dirs: [['app', namespace: MyApp]]) do
      assert MyApp::X
    end
  end
end
