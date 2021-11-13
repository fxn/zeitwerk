# frozen_string_literal: true

require "test_helper"

class TestPrivateConstants < LoaderTest
  test "lookup rules for relative private constants work as expected" do
    files = [["m/x.rb", <<~EOS1], ["c.rb", <<~EOS2]]
      module M
        X = :X
        private_constant :X
      end
    EOS1
      class C
        include M

        def self.x
          X
        end
      end
    EOS2
    with_setup(files) do
      assert_equal :X, C.x
    end
  end

  test "lookup rules for qualified private constants work as expected" do
    files = [["m/x.rb", <<~RUBY]]
      module M
        X = :X
        private_constant :X
      end
    RUBY
    with_setup(files) do
      assert_raises(NameError) { M::X }
      assert_equal :X, M.module_eval("X")
    end
  end

  test "reloading works for private constants" do
    $test_reload_private_constants = 0
    files = [["m/x.rb", <<~EOS1], ["c.rb", <<~EOS2]]
      module M
        X = $test_reload_private_constants
        private_constant :X
      end
    EOS1
      class C
        include M

        def self.x
          X
        end
      end
    EOS2
    with_setup(files) do
      assert_equal 0, C.x

      loader.reload
      $test_reload_private_constants = 1

      assert_equal 1, C.x
    end
  end
end
