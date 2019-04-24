require "test_helper"
require "fileutils"

class TestEagerLoad < LoaderTest
  test "eager loads independent files" do
    loaders = [loader, new_loader(setup: false)]

    $tel0 = $tel1 = false

    files = [
      ["lib0/app0.rb", "module App0; end"],
      ["lib0/app0/foo.rb", "class App0::Foo; $tel0 = true; end"],
      ["lib1/app1/foo.rb", "class App1::Foo; end"],
      ["lib1/app1/foo/bar/baz.rb", "class App1::Foo::Bar::Baz; $tel1 = true; end"]
    ]
    with_files(files) do
      loaders[0].push_dir("lib0")
      loaders[0].setup

      loaders[1].push_dir("lib1")
      loaders[1].setup

      Zeitwerk::Loader.eager_load_all

      assert $tel0
      assert $tel1
    end
  end

  test "eager loads dependent loaders" do
    loaders = [loader, new_loader(setup: false)]

    $tel0 = $tel1 = false

    files = [
      ["lib0/app0.rb", <<-EOS],
        module App0
          App1
        end
      EOS
      ["lib0/app0/foo.rb", <<-EOS],
        class App0::Foo
          $tel0 = App1::Foo
        end
      EOS
      ["lib1/app1/foo.rb", <<-EOS],
        class App1::Foo
          App0
        end
      EOS
      ["lib1/app1/foo/bar/baz.rb", <<-EOS]
        class App1::Foo::Bar::Baz
          $tel1 = App0::Foo
        end
      EOS
    ]
    with_files(files) do
      loaders[0].push_dir("lib0")
      loaders[0].setup

      loaders[1].push_dir("lib1")
      loaders[1].setup

      Zeitwerk::Loader.eager_load_all

      assert $tel0
      assert $tel1
    end
  end

  [false, true].each do |enable_reloading|
    test "we can opt-out of entire root directories, and still autoload (enable_autoloading #{enable_reloading})" do
      on_teardown do
        remove_const :Foo
        delete_loaded_feature "foo.rb"
      end

      $test_eager_load_eager_loaded_p = false
      files = [["foo.rb", "Foo = true; $test_eager_load_eager_loaded_p = true"]]
      with_files(files) do
        loader = new_loader(dirs: ".", enable_reloading: enable_reloading)
        loader.do_not_eager_load(".")
        loader.eager_load

        assert !$test_eager_load_eager_loaded_p
        assert Foo
      end
    end

    test "we can opt-out of sudirectories, and still autoload (enable_autoloading #{enable_reloading})" do
      on_teardown do
        remove_const :Foo
        delete_loaded_feature "foo.rb"

        remove_const :DbAdapters
        delete_loaded_feature "db_adapters/mysql_adapter.rb"
      end

      $test_eager_load_eager_loaded_p = false
      files = [
        ["db_adapters/mysql_adapter.rb", <<-EOS],
          module DbAdapters::MysqlAdapter
          end
          $test_eager_load_eager_loaded_p = true
        EOS
        ["foo.rb", "Foo = true"]
      ]
      with_files(files) do
        loader = new_loader(dirs: ".", enable_reloading: enable_reloading)
        loader.do_not_eager_load("db_adapters")
        loader.eager_load

        assert Foo
        assert !$test_eager_load_eager_loaded_p
        assert DbAdapters::MysqlAdapter
      end
    end

    test "we can opt-out of files, and still autoload (enable_autoloading #{enable_reloading})" do
      on_teardown do
        remove_const :Foo
        delete_loaded_feature "foo.rb"

        remove_const :Bar
        delete_loaded_feature "bar.rb"
      end

      $test_eager_load_eager_loaded_p = false
      files = [
        ["foo.rb", "Foo = true"],
        ["bar.rb", "Bar = true; $test_eager_load_eager_loaded_p = true"]
      ]
      with_files(files) do
        loader = new_loader(dirs: ".", enable_reloading: enable_reloading)
        loader.do_not_eager_load("bar.rb")
        loader.eager_load

        assert Foo
        assert !$test_eager_load_eager_loaded_p
        assert Bar
      end
    end
  end

  test "eager loading skips repeated files" do
    $test_eager_loaded_file = nil
    files = [
      ["a/foo.rb", "Foo = 1; $test_eager_loaded_file = :a"],
      ["b/foo.rb", "Foo = 1; $test_eager_loaded_file = :b"]
    ]
    with_files(files) do
      la = new_loader(dirs: "a")
      lb = new_loader(dirs: "b")

      la.eager_load
      lb.eager_load

      assert_equal :a, $test_eager_loaded_file
    end
  end

  test "eager loading skips files that would map to already loaded constants" do
    on_teardown { remove_const :X }

    $test_eager_loaded_file = false
    files = [["x.rb", "X = 1; $test_eager_loaded_file = true"]]
    ::X = 1
    with_setup(files) do
      loader.eager_load
      assert !$test_eager_loaded_file
    end
  end

  test "eager loading works with symbolic links" do
    files = [["real/x.rb", "X = true"]]
    with_files(files) do
      FileUtils.ln_s("real", "symlink")
      loader.push_dir("symlink")
      loader.setup
      loader.eager_load

      assert_nil Object.autoload?(:X)
    end
  end
end
