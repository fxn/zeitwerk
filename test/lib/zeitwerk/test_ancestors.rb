require "test_helper"

class TestAncestors < LoaderTest
  test "autoloads a constant from an ancestor" do
    files = [
      ["a.rb", "class A; end"],
      ["a/x.rb", "class A::X; end"],
      ["b.rb", "class B < A; end"],
      ["c.rb", "class C < B; end"]
    ]
    with_setup(files) do
      assert C::X
    end
  end

  test "autoloads a constant from an ancenstor, even if present above" do
    files = [
      ["a.rb", "class A; X = :A; end"],
      ["b.rb", "class B < A; end"],
      ["b/x.rb", "class B; X = :B; end"],
      ["c.rb", "class C < B; end"]
    ]
    with_setup(files) do
      assert_equal :A, A::X
      assert_equal :B, C::X
    end
  end
end
