# frozen_string_literal: true

require "test_helper"

class TestShadowed < LoaderTest
  test "does not autoload from a shadowed file" do
    on_teardown { remove_const :X }

    ::X = 1

    files = [["x.rb", "X = 2"]]
    with_setup(files) do
      assert_equal 1, ::X
      loader.reload
      assert_equal 1, ::X
    end
  end

  test "autoloads from a shadowed implicit namespace" do
    on_teardown { remove_const :M }

    mod = Module.new
    ::M = mod

    files = [["m/x.rb", "M::X = true"]]
    with_setup(files) do
      assert M::X
      loader.reload
      assert_same mod, M
      assert M::X
    end
  end

  test "autoloads from a shadowed implicit namespace managed by another loader" do
    files = [["a/m/x.rb", "M::X = true"], ["b/m/y.rb", "M::Y = true"]]
    with_files(files) do
      new_loader(dirs: "a")
      loader = new_loader(dirs: "b")

      mod = M

      assert M::X
      assert M::Y
      loader.reload
      assert_same mod, M
      assert M::X
      assert M::Y
    end
  end

  test "autoloads from a shadowed explicit namespace" do
    on_teardown { remove_const :M }

    mod = Module.new
    ::M = mod

    files = [
      ["m.rb", "class M; end"],
      ["m/x.rb", "M::X = true"]
    ]
    with_setup(files) do
      assert M::X
      loader.reload
      assert_same mod, M
      assert M::X
    end
  end

  test "autoloads from a shadowed explicit namespace (autoload)" do
    on_teardown do
      remove_const :M
      delete_loaded_feature "a/m.rb"
    end

    files = [
      ["a/m.rb", "class M; end"],
      ["b/m/x.rb", "M::X = true"]
    ]
    with_files(files) do
      # External code has an autoload defined, could be another loader or not,
      # does not matter.
      Object.autoload(:M, File.expand_path("a/m.rb"))

      loader.push_dir("b")
      loader.setup

      mod = M
      assert M::X
      loader.reload
      assert_same mod, M
      assert M::X
    end
  end
end
