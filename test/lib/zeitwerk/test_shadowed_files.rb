# frozen_string_literal: true

require "test_helper"

class TestShadowedFiles < LoaderTest
  test "does not autoload from a file shadowed by an existing constant" do
    on_teardown { remove_const :X }

    ::X = 1

    files = [["x.rb", "X = 2"]]
    with_setup(files) do
      assert loader.shadowed_file?(File.expand_path("x.rb"))

      assert_equal 1, ::X
      loader.reload
      assert_equal 1, ::X
    end
  end

  test "does not autoload from a file shadowed by another one managed by the same loader" do
    files = [["a/x.rb", "X = 1"], ["b/x.rb", "X = 2"]]
    with_files(files) do
      loader.push_dir("a")
      loader.push_dir("b")
      loader.setup

      assert !loader.shadowed_file?(File.expand_path("a/x.rb"))
      assert loader.shadowed_file?(File.expand_path("b/x.rb"))

      assert_equal 1, ::X
      loader.reload
      assert_equal 1, ::X
    end
  end

  test "does not autoload from a file shadowed by another one managed by a different loader" do
    files = [["a/x.rb", "X = 1"], ["b/x.rb", "X = 2"]]
    with_files(files) do
      first_loader = new_loader(dirs: "a")
      second_loader = new_loader(dirs: "b")

      assert !first_loader.shadowed_file?(File.expand_path("a/x.rb"))
      assert second_loader.shadowed_file?(File.expand_path("b/x.rb"))

      assert_equal 1, ::X
      second_loader.reload
      assert_equal 1, ::X
    end
  end
end
