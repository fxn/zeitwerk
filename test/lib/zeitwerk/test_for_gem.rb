require "test_helper"

class TestForGem < LoaderTest
  test "sets things correctly" do
    files = [
      ["my_gem.rb", <<-EOS],
        $for_gem_test_loader = Zeitwerk::Loader.for_gem
        $for_gem_test_loader.enable_reloading
        $for_gem_test_loader.setup

        class MyGem
        end
      EOS
      ["my_gem/foo.rb", "class MyGem::Foo; end"],
      ["my_gem/foo/bar.rb", "class MyGem::Foo::Bar; end"]
    ]
    with_files(files) do
      with_load_path(".") do
        assert require "my_gem" # what bundler is going to do
        assert MyGem::Foo::Bar

        $for_gem_test_loader.unload
        assert !Object.const_defined?(:MyGem)

        $for_gem_test_loader.setup
        assert MyGem::Foo::Bar
      end
    end
  end

  test "is idempotent" do
    files = [
      ["my_gem.rb", <<-EOS],
        $for_gem_test_zs << Zeitwerk::Loader.for_gem
        $for_gem_test_zs.last.enable_reloading
        $for_gem_test_zs.last.setup

        class MyGem
        end
      EOS
      ["my_gem/foo.rb", "class MyGem::Foo; end"]
    ]
    with_files(files) do
      with_load_path(".") do
        $for_gem_test_zs = []
        assert require "my_gem" # what bundler is going to do
        assert MyGem::Foo

        $for_gem_test_zs.first.unload
        assert !Object.const_defined?(:MyGem)

        $for_gem_test_zs.first.setup
        assert MyGem::Foo

        assert_equal 2, $for_gem_test_zs.size
        assert_same $for_gem_test_zs.first, $for_gem_test_zs.last
      end
    end
  end

  test "configures the gem inflector by default" do
    on_teardown do
      remove_const :MyGem
      delete_loaded_feature "my_gem.rb"
    end

    files = [
      ["my_gem.rb", <<-EOS],
        $for_gem_test_loader = Zeitwerk::Loader.for_gem
        $for_gem_test_loader.setup

        class MyGem
        end
      EOS
      ["my_gem/foo.rb", "class MyGem::Foo; end"]
    ]
    with_files(files) do
      with_load_path(".") do
        require "my_gem"
        assert_instance_of Zeitwerk::GemInflector, $for_gem_test_loader.inflector
      end
    end
  end

  test "configures the basename of the root file as loader name" do
    on_teardown do
      remove_const :MyGem
      delete_loaded_feature "my_gem.rb"
    end

    files = [
      ["my_gem.rb", <<-EOS],
        $for_gem_test_loader = Zeitwerk::Loader.for_gem
        $for_gem_test_loader.setup

        class MyGem
        end
      EOS
      ["my_gem/foo.rb", "class MyGem::Foo; end"]
    ]
    with_files(files) do
      with_load_path(".") do
        require "my_gem"
        assert_equal "my_gem", $for_gem_test_loader.tag
      end
    end
  end

  test "is able to handle a caller defined in a relative path" do
    on_teardown do
      remove_const :MyGem
      delete_loaded_feature "my_gem.rb"
    end

    files = [
      ["my_gem.rb", <<-EOS],
        $for_gem_test_loader = Zeitwerk::Loader.for_gem
        $for_gem_test_loader.setup

        class MyGem
          def self.caller_path
            $caller_file = caller_locations(1, 1).first.path
          end
        end
        $caller_path = MyGem.caller_path
      EOS
    ]
    with_files(files) do
      load "my_gem.rb"
      assert_equal "my_gem", $for_gem_test_loader.tag
      assert_equal "my_gem.rb", $caller_path
      assert_includes $for_gem_test_loader.root_dirs, File.expand_path(".")
    end
  end
end
