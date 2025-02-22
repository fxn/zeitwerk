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
    $loader = nil
    files = [
      ["my_gem.rb", <<-EOS],
        $loader = Zeitwerk::Loader.new
        $loader.push_dir(__dir__)
        $loader.push_dir("rd1")
        $loader.push_dir("rd2")

        $loader.enable_reloading
        $loader.setup

        module MyGem; end
      EOS
      ["rd1/user.rb", "class User; end"],
      ["rd1/api/v1/users_controller.rb", "class Api::V1::UsersController; end"],
      ["rd1/admin/root.rb", "class Admin::Root; end"],
      ["rd2/user.rb", "class User; end"]
    ]
    with_files(files) do
      with_load_path(".") do
        require "my_gem"
      end

      assert User
      assert Api::V1::UsersController

      assert !$loader.__autoloads.empty?
      assert !$loader.__autoloaded_dirs.empty?
      assert !$loader.__to_unload.empty?
      assert !$loader.__namespace_dirs.empty?
      assert !$loader.__inceptions.empty?

      $loader.unload

      assert $loader.__autoloads.empty?
      assert $loader.__autoloaded_dirs.empty?
      assert $loader.__to_unload.empty?
      assert $loader.__namespace_dirs.empty?
      assert $loader.__inceptions.empty?
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
      crefM = Zeitwerk::Cref.new(Object, :M)
      assert Zeitwerk::Registry.explicit_namespaces.registered?(crefM) == la

      lb = new_loader(dirs: "b")
      crefX = Zeitwerk::Cref.new(Object, :X)
      assert Zeitwerk::Registry.explicit_namespaces.registered?(crefX) == lb

      la.unload
      assert_nil Zeitwerk::Registry.explicit_namespaces.registered?(crefM)
      assert Zeitwerk::Registry.explicit_namespaces.registered?(crefX) == lb
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

      assert !loader.__shadowed_files.empty? # precondition
      loader.unload
      assert loader.__shadowed_files.empty?
    end
  end

  test "unload clears associated inceptions" do
    files = []

    files << ["gem1/my_gem1.rb", <<~EOS]
      $loader1 = Zeitwerk::Loader.new
      $loader1.push_dir(__dir__)
      $loader1.enable_reloading
      $loader1.setup
      module MyGem1; end
    EOS

    files << ["gem2/my_gem2.rb", <<~EOS]
      $loader2 = Zeitwerk::Loader.new
      $loader2.push_dir(__dir__)
      $loader2.setup
      module MyGem2; end
    EOS

    with_files(files) do
      with_load_path(".") do
        require "gem1/my_gem1"
        require "gem2/my_gem2"
      end

      assert MyGem1
      assert MyGem2

      cref1 = Zeitwerk::Cref.new(Object, :MyGem1)
      cref2 = Zeitwerk::Cref.new(Object, :MyGem2)

      assert Zeitwerk::Registry.inceptions.registered?(cref1)
      assert Zeitwerk::Registry.inceptions.registered?(cref2)

      $loader1.unload

      assert !Zeitwerk::Registry.inceptions.registered?(cref1)
      assert Zeitwerk::Registry.inceptions.registered?(cref2)
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
