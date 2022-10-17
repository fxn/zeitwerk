# frozen_string_literal: true

require "pathname"
require "test_helper"

class TestNamespaceAt < LoaderTest
  test "returns Object for a root directory representing Object" do
    with_setup([]) do
      assert_same Object, loader.namespace_at(".")
    end
  end

  test "returns the custom namespace for a root directory representing a custom namespace" do
    with_files([]) do
      loader.push_dir(".", namespace: self.class)
      loader.setup
      assert_same self.class, loader.namespace_at(".")
    end
  end

  test "returns Object for a top-level Ruby file" do
    files = [["x.rb", "X = 1"]]
    with_setup(files) do
      assert_same Object, loader.namespace_at("x.rb")
    end
  end

  test "returns Object for a top-level Ruby file (Pathname)" do
    files = [["x.rb", "X = 1"]]
    with_setup(files) do
      assert_same Object, loader.namespace_at(Pathname.new("x.rb"))
    end
  end

  test "returns a class for a top-level Ruby file (custom namespace)" do
    files = [["x.rb", "#{self.class.name}::X = 1"]]
    with_files(files) do
      loader.push_dir(".", namespace: self.class)
      loader.setup
      assert_same self.class, loader.namespace_at("x.rb")
    end
  end

  test "returns Object for a top-level Ruby file (collapse)" do
    files = [["collapsed/x.rb", "X = 1"]]
    with_setup(files) do
      loader.collapse("collapsed")
      assert_same Object, loader.namespace_at("collapsed/x.rb")
    end
  end

  test "returns a module for a Ruby file (namespace)" do
    files = [["m/x.rb", "M::X = 1"]]
    with_setup(files) do
      assert_same M, loader.namespace_at("m/x.rb")
    end
  end

  test "returns a module for a Ruby file (namespace, collapse)" do
    files = [["m/collapsed/x.rb", "M::X = 1"]]
    with_setup(files) do
      loader.collapse("m/collapsed")
      assert_same M, loader.namespace_at("m/collapsed/x.rb")
    end
  end

  test "returns a module for a directory" do
    files = [["m/y/x.rb", "M::Y::X = 1"]]
    with_setup(files) do
      assert_same M, loader.namespace_at("m")
      assert_same M, loader.namespace_at("m/")
      assert_same M::Y, loader.namespace_at("m/y")
      assert_same M::Y, loader.namespace_at("m/y/")
    end
  end

  test "returns a module for a directory (Pathname)" do
    files = [["m/y/x.rb", "M::Y::X = 1"]]
    with_setup(files) do
      assert_same M, loader.namespace_at(Pathname.new("m"))
      assert_same M, loader.namespace_at(Pathname.new("m/"))
      assert_same M::Y, loader.namespace_at(Pathname.new("m/y"))
      assert_same M::Y, loader.namespace_at(Pathname.new("m/y/"))
    end
  end

  test "returns a module for a directory (inflection)" do
    files = [["m/y/x.rb", "M::Z::X = 1"]]
    with_files(files) do
      loader.inflector.inflect("y" => "Z")
      loader.push_dir(".")
      loader.setup
      assert_same M, loader.namespace_at("m")
      assert_same M, loader.namespace_at("m/")
      assert_same M::Z, loader.namespace_at("m/y")
      assert_same M::Z, loader.namespace_at("m/y/")
    end
  end

  test "returns a module for a directory (custom namespace)" do
    files = [["m/y/x.rb", "#{self.class.name}::M::Y::X = 1"]]
    with_files(files) do
      loader.push_dir(".", namespace: self.class)
      loader.setup
      assert_same self.class.const_get(:M, false), loader.namespace_at("m")
      assert_same M, loader.namespace_at("m/")
      assert_same M::Y, loader.namespace_at("m/y")
      assert_same M::Y, loader.namespace_at("m/y/")
    end
  end

  test "returns a module for a directory (collapse)" do
    files = [["m/collapsed/y/x.rb", "M::Y::X = 1"]]
    with_setup(files) do
      loader.collapse("m/collapsed")
      assert_same M, loader.namespace_at("m")
      assert_same M, loader.namespace_at("m/")
      assert_same M, loader.namespace_at("m/collapsed")
      assert_same M, loader.namespace_at("m/collapsed/")
      assert_same M::Y, loader.namespace_at("m/collapsed/y")
      assert_same M::Y, loader.namespace_at("m/collapsed/y/")
    end
  end

  test "returns nil for ignored paths" do
    files = [["x.rb", "X = 1"]]
    with_files(files) do
      loader.ignore("x.rb")
      loader.setup
      assert_nil loader.namespace_at("x.rb")
    end
  end

  test "returns nil for descendants of ignored paths" do
    files = [["m/y/x.rb", "M::Y::X = 1"]]
    with_files(files) do
      loader.ignore("m")
      loader.push_dir(".")
      loader.setup
      assert_nil loader.namespace_at("m/y/x.rb")
      assert_nil loader.namespace_at("m/y")
      assert_nil loader.namespace_at("m")
    end
  end

  test "returns the namespace for shadowed files" do
    files = [["m/x.rb", "X = 1"], ["n/x.rb", "X = 1"]]
    with_files(files) do
      loader.push_dir("m")
      loader.push_dir("n")
      loader.setup
      assert_same Object, loader.namespace_at("m/x.rb")
      assert_same Object, loader.namespace_at("n/x.rb")
    end
  end

  test "returns nil for non-Ruby files" do
    files = [["README.md", ""]]
    with_setup(files) do
      assert_nil loader.namespace_at("README.md")
    end
  end

  test "returns nil for directories without Ruby files" do
    files = [["views/index.html", ""]]
    with_setup(files) do
      assert_nil loader.namespace_at("views")
    end
  end

  test "returns nil for non-existing files" do
    with_setup([]) do
      assert_nil loader.namespace_at("foo.rb")
    end
  end

  test "returns nil for non-managed files" do
    with_setup([]) do
      assert_nil loader.namespace_at("..")
    end
  end
end
