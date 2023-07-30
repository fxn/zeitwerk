# frozen_string_literal: true

require "pathname"
require "test_helper"

class TestExpectedCpathAtErrors < LoaderTest
  test "raises Zeitwerk::Error if the argument does not exist" do
    with_setup(dirs: ["."]) do
      error = assert_raises Zeitwerk::Error do
        loader.cpath_expected_at("does_not_exist.rb")
      end
      abspath = File.expand_path("does_not_exist.rb")
      assert_includes error.message, "#{abspath} does not exist"
    end
  end

  test "raises Zeitwerk::NameError if the argument does not yield a constant name" do
    files = [["foo-bar.rb", nil], ["1.rb", nil]]
    with_files(files) do
      loader.push_dir(".")

      error = assert_raises Zeitwerk::NameError do
        loader.cpath_expected_at(files[0][0])
      end
      assert_includes error.message, "wrong constant name Foo-bar"

      error = assert_raises Zeitwerk::NameError do
        loader.cpath_expected_at(files[1][0])
      end
      assert_includes error.message, "wrong constant name 1"
    end
  end

  test "raises Zeitwerk::NameError if some intermediate segment does not yield a constant name" do
    with_files([["x/foo-bar/y/z.rb", nil]]) do
      loader.push_dir(".")
      error = assert_raises Zeitwerk::NameError do
        loader.cpath_expected_at("x/foo-bar/y/z.rb")
      end
      assert_includes error.message, "wrong constant name Foo-bar"
    end
  end
end

class TestExpectedCpathAtNil < LoaderTest
  test "returns nil if the argument is not a directory or Ruby file" do
    files = [["tasks/database.rake", nil], ["CHANGELOG", nil]]
    with_setup(files) do
      files.each do |file, _contents|
        assert_nil loader.cpath_expected_at(file)
      end
    end
  end

  test "returns nil if the argument is ignored" do
    with_setup([["ignored.rb", nil]]) do
      assert_nil loader.cpath_expected_at("ignored.rb")
    end
  end

  test "returns nil if the argument is a hidden Ruby file" do
    with_setup([[".foo.rb", nil]]) do
      assert_nil loader.cpath_expected_at(".foo.rb")
    end
  end

  test "returns nil if the argument does not belong to the autoload paths" do
    with_setup(dirs: ["."]) do
      assert_nil loader.cpath_expected_at(__dir__)
      assert_nil loader.cpath_expected_at(__FILE__)
    end
  end

  test "returns nil if an ancestor is ignored" do
    with_setup([["ignored/x.rb", nil]]) do
      assert_nil loader.cpath_expected_at("ignored/x.rb")
    end
  end

  test "returns nil if an ancestor is a hidden directory" do
    with_setup([[".foo/x.rb", nil]]) do
      assert_nil loader.cpath_expected_at(".foo/x.rb")
    end
  end
end

class TestExpectedCpathAtString < LoaderTest
  module M
    def self.name
      "Overridden"
    end
  end

  M_REAL_NAME = "#{name}::M"

  test "returns the name of the root namespace for a root directory (Object)" do
    with_setup([["README.md", nil]]) do
      assert_equal "Object", loader.cpath_expected_at(".")
    end
  end

  test "returns the name of the root namespace for a root directory (Object, Pathname)" do
    with_setup([["README.md", nil]]) do
      assert_equal "Object", loader.cpath_expected_at(Pathname.new("."))
    end
  end

  test "returns the name of the root namespace for a root directory (Custom)" do
    with_setup(dirs: ["."], namespace: M) do
      assert_equal M_REAL_NAME, loader.cpath_expected_at(".")
    end
  end

  test "returns the name of the root namespace for a root directory (Custom, Pathname)" do
    with_setup(dirs: ["."], namespace: M) do
      assert_equal M_REAL_NAME, loader.cpath_expected_at(Pathname.new("."))
    end
  end

  test "returns the name of the root directory even if it is hidden" do
    with_setup([[".foo/x.rb", nil]], dirs: [".foo"]) do
      assert_equal "Object", loader.cpath_expected_at(".foo")
    end
  end

  test "returns the cpath to a root file (Object)" do
    with_setup([["x.rb", "X = 1"]]) do
      assert_equal "X", loader.cpath_expected_at("x.rb")
    end
  end

  test "returns the cpath to a root file (Custom)" do
    with_setup([["x.rb", "X = 1"]], namespace: M) do
      assert_equal "#{M_REAL_NAME}::X", loader.cpath_expected_at("x.rb")
    end
  end

  test "returns the cpath to a subdirectory (Object)" do
    with_setup([["a/x.rb", "A::X = 1"]]) do
      assert_equal "A", loader.cpath_expected_at("a")
    end
  end

  test "returns the cpath to a subdirectory (Custom)" do
    with_setup([["a/x.rb", "A::X = 1"]], namespace: M) do
      assert_equal "#{M_REAL_NAME}::A", loader.cpath_expected_at("a")
    end
  end

  test "returns the cpath to a nested file (Object)" do
    with_setup([["a/b/c/x.rb", "A::B::C::X = 1"]]) do
      assert_equal "A::B::C::X", loader.cpath_expected_at("a/b/c/x.rb")
    end
  end

  test "returns the cpath to a nested file (Custom)" do
    with_setup([["a/b/c/x.rb", "A::B::C::X = 1"]], namespace: M) do
      assert_equal "#{M_REAL_NAME}::A::B::C::X", loader.cpath_expected_at("a/b/c/x.rb")
    end
  end

  test "returns the cpath to a nested directory (Object)" do
    with_setup([["a/b/c/x.rb", "A::B::C::X = 1"]]) do
      assert_equal "A::B::C", loader.cpath_expected_at("a/b/c")
    end
  end

  test "returns the cpath to a nested directory (Custom)" do
    with_setup([["a/b/c/x.rb", "A::B::C::X = 1"]], namespace: M) do
      assert_equal "#{M_REAL_NAME}::A::B::C", loader.cpath_expected_at("a/b/c")
    end
  end

  test "supports collapsed directories (Object)" do
    with_setup([["a/b/collapsed/x.rb", "A::B::X = 1"]]) do
      assert_equal "A::B::X", loader.cpath_expected_at("a/b/collapsed/x.rb")
      assert_equal "A::B", loader.cpath_expected_at("a/b/collapsed")
    end
  end

  test "supports collapsed directories (Custom)" do
    with_setup([["a/b/collapsed/x.rb", "A::B::X = 1"]], namespace: M) do
      assert_equal "#{M_REAL_NAME}::A::B::X", loader.cpath_expected_at("a/b/collapsed/x.rb")
      assert_equal "#{M_REAL_NAME}::A::B", loader.cpath_expected_at("a/b/collapsed")
    end
  end
end
