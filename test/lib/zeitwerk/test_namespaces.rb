require "test_helper"

class TestNamespaces < LoaderTest
  test "directories without explicitly defined namespaces autovivify a module" do
    files = [["admin/user.rb", "class Admin::User; end"]]
    with_setup(files) do
      assert_kind_of Module, Admin
      assert Admin::User
    end
  end

  test "directories with a matching defined namespace do not autovivfy" do
    files = [
      ["app/models/hotel.rb", "class Hotel; X = 1; end"],
      ["app/models/hotel/pricing.rb", "class Hotel::Pricing; end"]
    ]
    with_setup(files, dirs: "app/models") do
      assert_kind_of Class, Hotel
      assert Hotel::X
      assert Hotel::Pricing
    end
  end

  test "already existing namespaces are not reset" do
    files = [
      ["lib/active_storage.rb", "module ActiveStorage; end"],
      ["app/models/active_storage/blob.rb", "class ActiveStorage::Blob; end"]
    ]
    with_files(files) do
      with_load_path("lib") do
        begin
          require "active_storage"

          loader.push_dir("app/models")
          loader.setup

          assert ActiveStorage::Blob
          loader.unload
          assert ActiveStorage
        ensure
          delete_loaded_feature("lib/active_storage.rb")
          Object.send(:remove_const, :ActiveStorage)
        end
      end
    end
  end

  test "sudirectories in the root directories do not autovivify modules" do
    files = [["app/models/concerns/pricing.rb", "module Pricing; end"]]
    with_setup(files, dirs: %w(app/models app/models/concerns)) do
      assert_raises(NameError) { Concerns }
    end
  end

  test "subdirectories in the root directories are ignored even if there is a matching file" do
    files = [
      ["app/models/hotel.rb", "class Hotel; include GeoLoc; end"],
      ["app/models/concerns/geo_loc.rb", "module GeoLoc; end"],
      ["app/models/concerns.rb", "module Concerns; end"]
    ]
    with_setup(files, dirs: %w(app/models app/models/concerns)) do
      assert Concerns
      assert Hotel
    end
  end
end
