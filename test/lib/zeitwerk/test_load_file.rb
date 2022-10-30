require "pathname"
require "test_helper"

class TestLoadFile < LoaderTest
  test "loads a top-level file" do
    files = [["x.rb", "X = 1"]]
    with_setup(files) do
      loader.load_file("x.rb")

      assert required?(files[0])
    end
  end

  test "loads a top-level file (Pathname)" do
    files = [["x.rb", "X = 1"]]
    with_setup(files) do
      loader.load_file(Pathname.new("x.rb"))

      assert required?(files[0])
    end
  end

  test "loads a top-level file (custom root namespace)" do
    files = [["x.rb", "#{self.class}::X = 1"]]
    with_setup(files, namespace: self.class) do
      loader.load_file("x.rb")

      assert required?(files[0])
    end
  end

  test "loads a namespaced file" do
    files = [["m/x.rb", "M::X = 1"]]
    with_setup(files) do
      loader.load_file("m/x.rb")

      assert required?(files[0])
    end
  end

  test "loads a namespaced file (custom root namespace)" do
    files = [["m/x.rb", "#{self.class}::M::X = 1"]]
    with_setup(files, namespace: self.class) do
      loader.load_file("m/x.rb")

      assert required?(files[0])
    end
  end

  test "supports collapsed directories" do
    files = [["m/collapsed/x.rb", "M::X = 1"]]
    with_files(files) do
      loader.push_dir(".")
      loader.collapse("m/collapsed")
      loader.setup
      loader.load_file("m/collapsed/x.rb")

      assert required?(files[0])
    end
  end
end

class TestLoadFileErrors < LoaderTest
  test "raises if the argument does not exist" do
    with_setup([]) do
      e = assert_raises { loader.load_file("foo.rb") }
      assert_equal "#{File.expand_path('foo.rb')} does not exist", e.message
    end
  end

  test "raises if the argument is a directory" do
    with_setup([["m/x.rb", "M::X = 1"]]) do
      e = assert_raises { loader.load_file("m") }
      assert_equal "#{File.expand_path('m')} is not a Ruby file", e.message
    end
  end

  test "raises if the argument is a file, but does not have .rb extension" do
    with_setup([["README.md", ""]]) do
      e = assert_raises { loader.load_file("README.md") }
      assert_equal "#{File.expand_path('README.md')} is not a Ruby file", e.message
    end
  end

  test "raises if the argument is ignored" do
    with_files([["ignored.rb", "IGNORED"]]) do
      loader.push_dir(".")
      loader.ignore("ignored.rb")
      loader.setup

      e = assert_raises { loader.load_file("ignored.rb") }
      assert_equal "#{File.expand_path('ignored.rb')} is ignored", e.message
    end
  end

  test "raises if the argument is a descendant of an ignored directory" do
    with_files([["ignored/n/x.rb", "IGNORED"]]) do
      loader.push_dir(".")
      loader.ignore("ignored")
      loader.setup

      e = assert_raises { loader.load_file("ignored/n/x.rb") }
      assert_equal "#{File.expand_path('ignored/n/x.rb')} is ignored", e.message
    end
  end

  test "raises if the argument lives in an ignored root directory" do
    with_files([["ignored/n/x.rb", "IGNORED"]]) do
      loader.push_dir("ignored")
      loader.ignore("ignored")
      loader.setup

      e = assert_raises { loader.load_file("ignored/n/x.rb") }
      assert_equal "#{File.expand_path('ignored/n/x.rb')} is ignored", e.message
    end
  end

  test "raises if the file exists, but it is not managed by this loader" do
    files = [["external/x.rb", ""], ["lib/x.rb", "X = 1"]]
    with_setup(files, dirs: ["lib"]) do
      e = assert_raises { loader.load_file("external/x.rb") }
      assert_equal "I do not manage #{File.expand_path('external/x.rb')}", e.message
    end
  end

  test "raises if the file is shadowed" do
    files = [["lib1/x.rb", "X = 1"], ["lib2/x.rb", "SHADOWED"]]
    with_setup(files, dirs: %w(lib1 lib2)) do
      e = assert_raises { loader.load_file("lib2/x.rb") }
      assert_equal "#{File.expand_path('lib2/x.rb')} is shadowed", e.message
    end
  end
end
