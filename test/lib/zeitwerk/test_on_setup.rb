# frozen_string_literal: true

require "test_helper"

class TestOnSetup < LoaderTest
  test "on_setup callbacks are fired on setup, in order" do
    x = []
    loader.on_setup { x << 0 }
    loader.on_setup { x << 1 }
    loader.setup

    assert_equal [0, 1], x
  end

  test "on_setup callbacks are fired if setup was already done" do
    loader.setup

    x = []
    loader.on_setup { x << 0 }
    loader.on_setup { x << 1 }

    assert_equal [0, 1], x
  end

  test "on_setup callbacks are fired again on reload" do
    loader.enable_reloading

    x = []
    loader.on_setup { x << 0 }
    loader.on_setup { x << 1 }
    loader.setup

    assert_equal [0, 1], x

    loader.reload

    assert_equal [0, 1, 0, 1], x
  end

  test "on_setup is able to autoload" do
    files = [["x.rb", "X = true"]]
    with_files(files) do
      loader.push_dir(".")
      loader.on_setup do
        assert X
      end
      loader.setup
    end
  end
end
