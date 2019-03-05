require "test_helper"

class TestAutovivification < LoaderTest
  test "autoloads a simple constant in an autovivified module" do
    files = [["admin/x.rb", "Admin::X = true"]]
    with_setup(files) do
      assert_kind_of Module, Admin
      assert Admin::X
    end
  end

  test "autovivifies several levels in a row" do
    files = [["foo/bar/baz/woo.rb", "Foo::Bar::Baz::Woo = true"]]
    with_setup(files) do
      assert Foo::Bar::Baz::Woo
    end
  end

  test "autoloads several constants from the same namespace" do
    files = [
      ["app/models/admin/hotel.rb", "class Admin::Hotel; end"],
      ["app/controllers/admin/hotels_controller.rb", "class Admin::HotelsController; end"]
    ]
    with_setup(files, dirs: %w(app/models app/controllers)) do
      assert Admin::Hotel
      assert Admin::HotelsController
    end
  end
end
