# frozen_string_literal: true

require "test_helper"

# The following properties are not supported by the classic Rails autoloader.
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

  # See https://github.com/rails/rails/issues/28997.
  test "autoloads a constant from an ancestor that has some nesting going on" do
    files = [
      ["test_class.rb", "class TestClass; include IncludeModule; end"],
      ["include_module.rb", "module IncludeModule; include ContainerModule; end"],
      ["container_module/child_class.rb", "class ContainerModule::ChildClass; end"]
    ]
    with_setup(files) do
      assert TestClass::ChildClass
    end
  end
end
