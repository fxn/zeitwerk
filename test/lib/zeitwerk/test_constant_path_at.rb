# frozen_string_literal: true

require "pathname"
require "test_helper"

class TestConstantPathAt < LoaderTest
  test "returns an empty string for a root directory representing Object" do
    with_setup([]) do
      assert_equal "", loader.constant_path_at(".")
    end
  end

  test "returns a constant path for a root directory representing a custom namespace" do
    with_files([]) do
      loader.push_dir(".", namespace: self.class)
      loader.setup
      assert_equal self.class.name, loader.constant_path_at(".")
    end
  end

  test "returns the constant path for a Ruby file" do
    files = [["x.rb", "X = 1"]]
    with_setup(files) do
      assert_equal "X", loader.constant_path_at("x.rb")
    end
  end

  test "returns the constant path for a Ruby file (Pathname)" do
    files = [["x.rb", "X = 1"]]
    with_setup(files) do
      assert_equal "X", loader.constant_path_at(Pathname.new("x.rb"))
    end
  end

  test "returns the constant path for a Ruby file (inflection)" do
    files = [["html.rb", "class HTML; end"]]
    with_files(files) do
      loader.inflector.inflect("html" => "HTML")
      loader.push_dir(".")
      loader.setup
      assert_equal "HTML", loader.constant_path_at("html.rb")
    end
  end

  test "returns the constant path for a Ruby file (custom namespace)" do
    files = [["x.rb", "#{self.class.name}::X = 1"]]
    with_files(files) do
      loader.push_dir(".", namespace: self.class)
      loader.setup
      assert_equal "#{self.class.name}::X", loader.constant_path_at("x.rb")
    end
  end

  test "returns the constant path for a Ruby file (collapse)" do
    files = [["collapsed/x.rb", "X = 1"]]
    with_setup(files) do
      loader.collapse("collapsed")
      assert_equal "X", loader.constant_path_at("collapsed/x.rb")
    end
  end

  test "returns the constant path for a Ruby file (namespace)" do
    files = [["m/x.rb", "M::X = 1"]]
    with_setup(files) do
      assert_equal "M::X", loader.constant_path_at("m/x.rb")
    end
  end

  test "returns the constant path for a Ruby file (namespace, collapse)" do
    files = [["m/collapsed/x.rb", "M::X = 1"]]
    with_setup(files) do
      loader.collapse("m/collapsed")
      assert_equal "M::X", loader.constant_path_at("m/collapsed/x.rb")
    end
  end

  test "returns the constant path of a directory" do
    files = [["m/y/x.rb", "M::Y::X = 1"]]
    with_setup(files) do
      assert_equal "M", loader.constant_path_at("m")
      assert_equal "M", loader.constant_path_at("m/")
      assert_equal "M::Y", loader.constant_path_at("m/y")
      assert_equal "M::Y", loader.constant_path_at("m/y/")
    end
  end

  test "returns the constant path of a directory (Pathname)" do
    files = [["m/y/x.rb", "M::Y::X = 1"]]
    with_setup(files) do
      assert_equal "M", loader.constant_path_at(Pathname.new("m"))
      assert_equal "M", loader.constant_path_at(Pathname.new("m/"))
      assert_equal "M::Y", loader.constant_path_at(Pathname.new("m/y"))
      assert_equal "M::Y", loader.constant_path_at(Pathname.new("m/y/"))
    end
  end

  test "returns the constant path of a directory (inflection)" do
    files = [["api/y/x.rb", "API::Y::X = 1"]]
    with_files(files) do
      loader.inflector.inflect("api" => "API")
      loader.push_dir(".")
      loader.setup
      assert_equal "API", loader.constant_path_at("api")
      assert_equal "API", loader.constant_path_at("api/")
      assert_equal "API::Y", loader.constant_path_at("api/y")
      assert_equal "API::Y", loader.constant_path_at("api/y/")
    end
  end

  test "returns the constant path of a directory (custom namespace)" do
    files = [["m/y/x.rb", "#{self.class.name}::M::Y::X = 1"]]
    with_files(files) do
      loader.push_dir(".", namespace: self.class)
      loader.setup
      assert_equal "#{self.class.name}::M", loader.constant_path_at("m")
      assert_equal "#{self.class.name}::M", loader.constant_path_at("m/")
      assert_equal "#{self.class.name}::M::Y", loader.constant_path_at("m/y")
      assert_equal "#{self.class.name}::M::Y", loader.constant_path_at("m/y/")
    end
  end

  test "returns the constant path of a directory (collapse)" do
    files = [["m/collapsed/y/x.rb", "M::Y::X = 1"]]
    with_setup(files) do
      loader.collapse("m/collapsed")
      assert_equal "M", loader.constant_path_at("m")
      assert_equal "M", loader.constant_path_at("m/")
      assert_equal "M", loader.constant_path_at("m/collapsed")
      assert_equal "M", loader.constant_path_at("m/collapsed/")
      assert_equal "M::Y", loader.constant_path_at("m/collapsed/y")
      assert_equal "M::Y", loader.constant_path_at("m/collapsed/y/")
    end
  end

  test "returns the constant path for ignored paths" do
    files = [["x.rb", "X = 1"]]
    with_files(files) do
      loader.ignore("x.rb")
      loader.push_dir(".")
      loader.setup
      assert_equal "X", loader.constant_path_at("x.rb")
    end
  end

  test "returns the constant path for descendants of ignored paths" do
    files = [["m/y/x.rb", "M::Y::X = 1"]]
    with_setup(files) do
      loader.ignore("m")
      assert_equal "M::Y::X", loader.constant_path_at("m/y/x.rb")
      assert_equal "M::Y", loader.constant_path_at("m/y")
      assert_equal "M", loader.constant_path_at("m")
    end
  end

  test "returns the constant for shadowed files" do
    files = [["m/x.rb", "X = 1"], ["n/x.rb", "X = 1"]]
    with_files(files) do
      loader.push_dir("m")
      loader.push_dir("n")
      loader.setup
      assert_equal "X", loader.constant_path_at("m/x.rb")
      assert_equal "X", loader.constant_path_at("n/x.rb")
    end
  end

  test "returns nil for non-Ruby files" do
    files = [["README.md", ""]]
    with_setup(files) do
      assert_nil loader.constant_path_at("README.md")
    end
  end

  test "returns the constant path for non-existing files" do
    with_setup([]) do
      assert_equal "X", loader.constant_path_at("x.rb")
    end
  end

  test "returns nil for non-managed files" do
    with_setup([]) do
      assert_nil loader.constant_path_at("..")
    end
  end
end
