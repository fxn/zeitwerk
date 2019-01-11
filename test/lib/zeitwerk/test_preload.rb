require "test_helper"

class TestPreload < LoaderTest
  def preloads
    @preloads ||= ["a.rb", "m/n"]
  end

  def assert_preload
    $a_preloaded = $b_preoloaded = $c_preloaded = $d_preloaded = false
    files = [
      ["a.rb", "A = 1; $a_preloaded = true"],
      ["m/n/b.rb", "M::N::B = 1; $b_preloaded = true"],
      ["m/c.rb", "M::C = 1; $c_preloaded = true"],
      ["d.rb", "D = 1; $d_preloaded = true"]
    ]
    with_files(files) do
      loader.push_dir(".")
      yield # preload here
      loader.setup

      assert $a_preloaded
      assert $b_preloaded
      assert !$c_preloaded
      assert !$d_preloaded
    end
  end

  test "preloads files and directories (multiple args)" do
    assert_preload do
      loader.preload(*preloads)
    end
  end

  test "preloads files and directories (array)" do
    assert_preload do
      loader.preload(preloads)
    end
  end

  test "preloads files and directories (multiple calls)" do
    assert_preload do
      loader.preload(preloads.first)
      loader.preload(preloads.last)
    end
  end

  test "preloads files after setup too" do
    assert_preload do
      loader.setup
      loader.preload(preloads)
    end
  end
end
