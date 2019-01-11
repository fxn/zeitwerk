require "test_helper"

class TestConcurrency < LoaderTest
  test "constant definition is synchronized" do
    files = [["m.rb", <<-EOS]]
      module M
        sleep 0.5

        def self.works?
          true
        end
      end
    EOS
    with_setup(files) do
      t = Thread.new { M }
      assert M.works?
      t.join
    end
  end
end
