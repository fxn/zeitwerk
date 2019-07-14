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
end
