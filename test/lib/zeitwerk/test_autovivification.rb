require "test_helper"

class TestAutovivification < LoaderTest
  module Namespace; end

  test "autoloads a simple constant in an autovivified module (Object)" do
    files = [["admin/x.rb", "Admin::X = true"]]
    with_setup(files) do
      assert_kind_of Module, Admin
      assert Admin::X
    end
  end

  test "autoloads a simple constant in an autovivified module (Namespace)" do
    files = [["admin/x.rb", "#{Namespace}::Admin::X = true"]]
    with_setup(files, namespace: Namespace) do
      assert_kind_of Module, Namespace::Admin
      assert Namespace::Admin::X
    end
  end

  test "autovivifies several levels in a row (Object)" do
    files = [["foo/bar/baz/woo.rb", "Foo::Bar::Baz::Woo = true"]]
    with_setup(files) do
      assert Foo::Bar::Baz::Woo
    end
  end

  test "autovivifies several levels in a row (Namespace)" do
    files = [["foo/bar/baz/woo.rb", "#{Namespace}::Foo::Bar::Baz::Woo = true"]]
    with_setup(files, namespace: Namespace) do
      assert Namespace::Foo::Bar::Baz::Woo
    end
  end

  test "autoloads several constants from the same namespace (Object)" do
    files = [
      ["app/models/admin/hotel.rb", "class Admin::Hotel; end"],
      ["app/controllers/admin/hotels_controller.rb", "class Admin::HotelsController; end"]
    ]
    with_setup(files, dirs: %w(app/models app/controllers)) do
      assert Admin::Hotel
      assert Admin::HotelsController
    end
  end

  test "autoloads several constants from the same namespace (Namespace)" do
    files = [
      ["app/models/admin/hotel.rb", "class #{Namespace}::Admin::Hotel; end"],
      ["app/controllers/admin/hotels_controller.rb", "class #{Namespace}::Admin::HotelsController; end"]
    ]
    with_setup(files, namespace: Namespace, dirs: %w(app/models app/controllers)) do
      assert Namespace::Admin::Hotel
      assert Namespace::Admin::HotelsController
    end
  end
end
