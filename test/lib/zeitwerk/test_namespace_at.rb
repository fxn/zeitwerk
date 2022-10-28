# frozen_string_literal: true

require "pathname"
require "test_helper"

# This is a private method I totally want to unit test.
class TestNamespaceAt < LoaderTest
  def namespace_at(path, l=loader)
    l.send(:namespace_at, File.expand_path(path))
  end

  test "returns Object for a root directory representing Object" do
    with_setup([]) do
      assert_same Object, namespace_at(".")
    end
  end

  test "returns the custom namespace for a root directory representing a custom namespace" do
    with_setup([], dirs: ".", namespace: self.class) do
      assert_same self.class, namespace_at(".")
    end
  end

  test "returns a module for a directory" do
    files = [["m/y/x.rb", "M::Y::X = 1"]]
    with_setup(files) do
      assert_same M, namespace_at("m")
      assert_same M, namespace_at("m/")
      assert_same M::Y, namespace_at("m/y")
      assert_same M::Y, namespace_at("m/y/")
    end
  end

  test "returns a module for a directory (Pathname)" do
    files = [["m/y/x.rb", "M::Y::X = 1"]]
    with_setup(files) do
      assert_same M, namespace_at(Pathname.new("m"))
      assert_same M, namespace_at(Pathname.new("m/"))
      assert_same M::Y, namespace_at(Pathname.new("m/y"))
      assert_same M::Y, namespace_at(Pathname.new("m/y/"))
    end
  end

  test "returns a module for a directory (inflection)" do
    loader.inflector.inflect("y" => "Z")
    files = [["m/y/x.rb", "M::Z::X = 1"]]
    with_setup(files) do
      assert_same M, namespace_at("m")
      assert_same M, namespace_at("m/")
      assert_same M::Z, namespace_at("m/y")
      assert_same M::Z, namespace_at("m/y/")
    end
  end

  test "returns a module for a directory (custom namespace)" do
    files = [["m/y/x.rb", "#{self.class.name}::M::Y::X = 1"]]
    with_setup(files, dirs: ".", namespace: self.class) do
      assert_same self.class.const_get(:M, false), namespace_at("m")
      assert_same M, namespace_at("m/")
      assert_same M::Y, namespace_at("m/y")
      assert_same M::Y, namespace_at("m/y/")
    end
  end

  test "returns a module for a directory (collapse)" do
    files = [["m/collapsed/y/x.rb", "M::Y::X = 1"]]
    with_files(files) do
      loader.collapse("m/collapsed")
      loader.push_dir(".")
      loader.setup
      assert_same M, namespace_at("m")
      assert_same M, namespace_at("m/")
      assert_same M, namespace_at("m/collapsed")
      assert_same M, namespace_at("m/collapsed/")
      assert_same M::Y, namespace_at("m/collapsed/y")
      assert_same M::Y, namespace_at("m/collapsed/y/")
    end
  end

  test "returns nil for discarded directories" do
    files = [["a/x.rb", "X = 1"]]
    with_files(files) do
      loader.ignore("x.rb")
      loader.setup
      assert_nil namespace_at("a")
    end
  end

  test "returns nil for descendants of ignored paths" do
    files = [["m/y/x.rb", "M::Y::X = 1"]]
    with_files(files) do
      loader.ignore("m")
      loader.push_dir(".")
      loader.setup
      assert_nil namespace_at("m/y")
      assert_nil namespace_at("m")
    end
  end

  test "returns the namespace for shadowed files" do
    files = [["m/x.rb", "X = 1"], ["n/x.rb", "X = 1"]]
    with_setup(files, dirs: %w(m n)) do
      assert_same Object, namespace_at("m")
      assert_same Object, namespace_at("n")
    end
  end

  test "returns nil for directories without Ruby files" do
    files = [["views/index.html", ""]]
    with_setup(files) do
      assert_nil namespace_at("views")
    end
  end

  test "returns nil for non-managed directories" do
    with_setup([]) do
      assert_nil namespace_at("..")
    end
  end
end
