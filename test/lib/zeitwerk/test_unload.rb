# frozen_string_literal: true

require "test_helper"

class TestUnload < LoaderTest
  module Namespace; end

  test "unload removes all autoloaded constants (Object)" do
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

  test "unload removes all autoloaded constants (Namespace)" do
    files = [
      ["user.rb", "class #{Namespace}::User; end"],
      ["admin/root.rb", "class #{Namespace}::Admin::Root; end"]
    ]
    with_setup(files, namespace: Namespace) do
      assert Namespace::User
      assert Namespace::Admin::Root
      admin = Namespace::Admin

      loader.unload

      assert !Namespace.const_defined?(:User)
      assert !Namespace.const_defined?(:Admin)
      assert !admin.const_defined?(:Root)
    end
  end

  test "unload removes autoloaded constants, even if #name is overridden" do
    files = [["x.rb", <<~RUBY]]
      module X
        def self.name
          "Y"
        end
      end
    RUBY
    with_setup(files) do
      assert X
      loader.unload
      assert !Object.const_defined?(:X)
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
      ["rd1/user.rb", "class User; end"],
      ["rd1/api/v1/users_controller.rb", "class Api::V1::UsersController; end"],
      ["rd1/admin/root.rb", "class Admin::Root; end"],
      ["rd2/user.rb", "class User; end"]
    ]
    with_setup(files) do
      assert User
      assert Api::V1::UsersController

      assert !loader.autoloads.empty?
      assert !loader.autoloaded_dirs.empty?
      assert !loader.__to_unload.empty?
      assert !loader.namespace_dirs.empty?

      loader.unload

      assert loader.autoloads.empty?
      assert loader.autoloaded_dirs.empty?
      assert loader.__to_unload.empty?
      assert loader.namespace_dirs.empty?
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
      assert Zeitwerk::ExplicitNamespace.send(:cpaths)["M"] == la

      lb = new_loader(dirs: "b")
      assert Zeitwerk::ExplicitNamespace.send(:cpaths)["X"] == lb

      la.unload
      assert_nil Zeitwerk::ExplicitNamespace.send(:cpaths)["M"]
      assert Zeitwerk::ExplicitNamespace.send(:cpaths)["X"] == lb
    end
  end

  test "unload clears the set of shadowed files" do
    files = [
      ["a/m.rb", "module M; end"],
      ["b/m.rb", "module M; end"],
    ]
    with_files(files) do
      loader.push_dir("a")
      loader.push_dir("b")
      loader.setup

      assert !loader.shadowed_files.empty? # precondition
      loader.unload
      assert loader.shadowed_files.empty?
    end
  end

  test "unload clears state even if the autoload failed and the exception was rescued" do
    on_teardown do
      remove_const :X_IS_NOT_DEFINED
    end

    files = [["x.rb", "X_IS_NOT_DEFINED = true"]]
    with_setup(files) do
      begin
        X
      rescue Zeitwerk::NameError
        pass # precondition holds
      else
        flunk # precondition failed
      end

      loader.unload

      assert !Object.constants.include?(:X)
      assert !required?(files)
    end
  end

  test "raises if called before setup" do
    assert_raises(Zeitwerk::SetupRequired) do
      loader.unload
    end
  end
end
