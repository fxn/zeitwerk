require "test_helper"

class TestForGem < LoaderTest
  test "sets things correctly" do
    on_teardown do
      remove_const :MyGem
      delete_loaded_feature "my_gem.rb", "foo.rb", "bar.rb"
    end

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
    on_teardown do
      remove_const :MyGem
      delete_loaded_feature "my_gem.rb", "foo.rb"
    end

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
      delete_loaded_feature "my_gem.rb", "foo.rb"
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
      delete_loaded_feature "my_gem.rb", "foo.rb"
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
end
