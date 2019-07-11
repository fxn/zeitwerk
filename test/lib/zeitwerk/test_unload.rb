require "test_helper"

class TestUnload < LoaderTest
  test "unload removes all autoloaded constants" do
    files = [
      ["user.rb", "class User; end"],
      ["admin/root.rb", "class Admin::Root; end"]
    ]
    with_setup(files) do
      assert User
      assert Admin::Root
      admin = Admin

      loader.unload

      assert !Object.const_defined?(:User)
      assert !Object.const_defined?(:Admin)
      assert !admin.const_defined?(:Root)
    end
  end

  test "unload removes non-executed autoloads" do
    files = [["x.rb", "X = true"]]
    with_setup(files) do
      # This does not autolaod, see the compatibility test.
      assert Object.const_defined?(:X)
      loader.unload
      assert !Object.const_defined?(:X)
    end
  end

  test "unload clears internal caches" do
    files = [
      ["app/user.rb", "class User; end"],
      ["app/api/v1/users_controller.rb", "class Api::V1::UsersController; end"],
      ["app/admin/root.rb", "class Admin::Root; end"],
      ["lib/user.rb", "class User; end"]
    ]
    with_setup(files, dirs: %w(app lib)) do
      assert User
      assert Api::V1::UsersController

      assert !loader.autoloads.empty?
      assert !loader.autoloaded_dirs.empty?
      assert !loader.to_unload.empty?
      assert !loader.lazy_subdirs.empty?

      loader.unload

      assert loader.autoloads.empty?
      assert loader.autoloaded_dirs.empty?
      assert loader.to_unload.empty?
      assert loader.lazy_subdirs.empty?
    end
  end

  test "unload does not assume autoloaded constants are still there" do
    files = [["x.rb", "X = true"]]
    with_setup(files) do
      assert X
      assert remove_const(:X) # user removed the constant by hand
      loader.unload # should not raise
    end
  end

  test "already existing namespaces are not reset" do
    on_teardown do
      remove_const :ActiveStorage
      delete_loaded_feature "active_storage.rb"
    end

    files = [
      ["lib/active_storage.rb", "module ActiveStorage; end"],
      ["app/models/active_storage/blob.rb", "class ActiveStorage::Blob; end"]
    ]
    with_files(files) do
      with_load_path("lib") do
        require "active_storage"

        loader.push_dir("app/models")
        loader.setup

        assert ActiveStorage::Blob
        loader.unload
        assert ActiveStorage
      end
    end
  end

  test "unload clears explicit namespaces associated" do
    files = [
      ["a/m.rb", "module M; end"], ["a/m/n.rb", "M::N = true"],
      ["b/x.rb", "module X; end"], ["b/x/y.rb", "X::Y = true"],
    ]
    with_files(files) do
      la = new_loader(dirs: "a")
      assert Zeitwerk::ExplicitNamespace.cpaths["M"] == la

      lb = new_loader(dirs: "b")
      assert Zeitwerk::ExplicitNamespace.cpaths["X"] == lb

      la.unload
      assert_nil Zeitwerk::ExplicitNamespace.cpaths["M"]
      assert Zeitwerk::ExplicitNamespace.cpaths["X"] == lb
    end
  end

  test "autoload clears explicit namespaces associated" do
    files = [
      ["f/z.rb", "class Z < Class.new { def self.name; 'z'; end }; end"], ["f/z/n.rb", "Z::N = true"],
    ]
    with_files(files) do
      l = new_loader(dirs: "f")
      assert Zeitwerk::ExplicitNamespace.cpaths["Z"] == l
      assert Z
      assert_nil Zeitwerk::ExplicitNamespace.cpaths["Z"]
    end
  end
end
