# frozen_string_literal: true

require "test_helper"
require "pathname"

class TestRequireInteraction < LoaderTest
  def assert_required(str)
    assert_equal true, require(str)
  end

  def assert_not_required(str)
    assert_equal false, require(str)
  end

  test "our decorated require returns true or false as expected" do
    on_teardown do
      remove_const :User
      delete_loaded_feature "user.rb"
    end

    files = [["user.rb", "class User; end"]]
    with_files(files) do
      with_load_path(".") do
        assert_required "user"
        assert_not_required "user"
      end
    end
  end

  test "our decorated require returns true or false as expected (Pathname)" do
    on_teardown do
      remove_const :User
      delete_loaded_feature "user.rb"
    end

    files = [["user.rb", "class User; end"]]
    pathname_for_user = Pathname.new("user")
    with_files(files) do
      with_load_path(".") do
        assert_required pathname_for_user
        assert_not_required pathname_for_user
      end
    end
  end

  test "autoloading makes require idempotent even with a relative path" do
    files = [["user.rb", "class User; end"]]
    with_setup(files, load_path: ".") do
      assert User
      assert_not_required "user"
    end
  end

  test "a required top-level file is still detected as autoloadable" do
    files = [["user.rb", "class User; end"]]
    with_setup(files, load_path: ".") do
      assert_required "user"
      loader.unload
      assert !Object.const_defined?(:User, false)

      loader.setup
      assert User
    end
  end

  test "a required top-level file is still detected as autoloadable (Pathname)" do
    files = [["user.rb", "class User; end"]]
    with_setup(files, load_path: ".") do
      assert_required Pathname.new("user")
      assert User
      loader.unload
      assert !Object.const_defined?(:User, false)

      loader.setup
      assert User
    end
  end

  test "require autovivifies as needed" do
    files = [
      ["app/models/admin/user.rb", "class Admin::User; end"],
      ["app/controllers/admin/users_controller.rb", "class Admin::UsersController; end"]
    ]
    dirs = %w(app/models app/controllers)
    with_setup(files, dirs: dirs, load_path: dirs) do
      assert_required "admin/user"

      assert Admin::User
      assert Admin::UsersController

      loader.unload
      assert !Object.const_defined?(:Admin)
    end
  end

  test "files deep down the current visited level are recognized as managed (implicit)" do
    files = [["foo/bar/baz/zoo/woo.rb", "Foo::Bar::Baz::Zoo::Woo = 1"]]
    with_setup(files, load_path: ".") do
      assert_required "foo/bar/baz/zoo/woo"
      assert loader.unloadable_cpath?("Foo::Bar::Baz::Zoo::Woo")
    end
  end

  test "files deep down the current visited level are recognized as managed (explicit)" do
    files = [
      ["foo/bar/baz/zoo.rb", "module Foo::Bar::Baz::Zoo; include Wadus; end"],
      ["foo/bar/baz/zoo/wadus.rb", "module Foo::Bar::Baz::Zoo::Wadus; end"],
      ["foo/bar/baz/zoo/woo.rb", "Foo::Bar::Baz::Zoo::Woo = 1"]
    ]
    with_setup(files, load_path: ".") do
      assert_required "foo/bar/baz/zoo/woo"
      assert loader.unloadable_cpath?("Foo::Bar::Baz::Zoo::Wadus")
      assert loader.unloadable_cpath?("Foo::Bar::Baz::Zoo::Woo")
    end
  end

  test "require works well with explicit namespaces" do
    files = [
      ["hotel.rb", "class Hotel; X = true; end"],
      ["hotel/pricing.rb", "class Hotel::Pricing; end"]
    ]
    with_setup(files, load_path: ".") do
      assert_required "hotel/pricing"
      assert Hotel::Pricing
      assert Hotel::X
    end
  end

  test "you can autoload yourself in a required file" do
    files = [
      ["my_gem.rb", <<-EOS],
        loader = Zeitwerk::Loader.new
        loader.push_dir(__dir__)
        loader.enable_reloading
        loader.setup

        module MyGem; end
      EOS
      ["my_gem/foo.rb", "class MyGem::Foo; end"]
    ]
    with_files(files) do
      with_load_path(Dir.pwd) do
        assert_required "my_gem"
      end
    end
  end

  test "does not autovivify while loading an explicit namespace, constant is not yet defined - file first" do
    files = [
      ["hotel.rb", <<-EOS],
        loader = Zeitwerk::Loader.new
        loader.push_dir(__dir__)
        loader.enable_reloading
        loader.setup

        Hotel.name

        class Hotel
        end
      EOS
      ["hotel/pricing.rb", "class Hotel::Pricing; end"]
    ]
    with_files(files) do
      iter = ->(dir, &block) do
        if dir == Dir.pwd
          block.call("hotel.rb")
          block.call("hotel")
        end
      end
      Dir.stub :foreach, iter do
        e = assert_raises(NameError) do
          with_load_path(Dir.pwd) do
            assert_required "hotel"
          end
        end
        assert_match %r/Hotel/, e.message
      end
    end
  end

  test "does not autovivify while loading an explicit namespace, constant is not yet defined - file last" do
    files = [
      ["hotel.rb", <<-EOS],
        loader = Zeitwerk::Loader.new
        loader.push_dir(__dir__)
        loader.enable_reloading
        loader.setup

        Hotel.name

        class Hotel
        end
      EOS
      ["hotel/pricing.rb", "class Hotel::Pricing; end"]
    ]
    with_files(files) do
      iter = ->(dir, &block) do
        if dir == Dir.pwd
          block.call("hotel")
          block.call("hotel.rb")
        end
      end
      Dir.stub :foreach, iter do
        e = assert_raises(NameError) do
          with_load_path(Dir.pwd) do
            assert_required "hotel"
          end
        end
        assert_match %r/Hotel/, e.message
      end
    end
  end
end
