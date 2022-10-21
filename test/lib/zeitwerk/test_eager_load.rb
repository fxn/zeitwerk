# frozen_string_literal: true

require "test_helper"
require "fileutils"

class TestEagerLoad < LoaderTest
  module Namespace; end

  test "eager loads independent files (Object)" do
    loaders = [loader, new_loader(setup: false)]

    files = [
      ["lib0/app0.rb", "module App0; end"],
      ["lib0/app0/foo.rb", "class App0::Foo; end"],
      ["lib1/app1/foo.rb", "class App1::Foo; end"],
      ["lib1/app1/foo/bar/baz.rb", "class App1::Foo::Bar::Baz; end"]
    ]
    with_files(files) do
      loaders[0].push_dir("lib0")
      loaders[0].setup

      loaders[1].push_dir("lib1")
      loaders[1].setup

      Zeitwerk::Loader.eager_load_all

      assert required?(files)
    end
  end

  test "eager loads independent files (Namespace)" do
    loaders = [loader, new_loader(setup: false)]

    files = [
      ["lib0/app0.rb", "module #{Namespace}::App0; end"],
      ["lib0/app0/foo.rb", "class #{Namespace}::App0::Foo; end"],
      ["lib1/app1/foo.rb", "class App1::Foo; end"],
      ["lib1/app1/foo/bar/baz.rb", "class App1::Foo::Bar::Baz; end"]
    ]
    with_files(files) do
      loaders[0].push_dir("lib0", namespace: Namespace)
      loaders[0].setup

      loaders[1].push_dir("lib1")
      loaders[1].setup

      Zeitwerk::Loader.eager_load_all

      assert required?(files)
    end
  end

  test "eager loads dependent loaders" do
    loaders = [loader, new_loader(setup: false)]

    files = [
      ["lib0/app0.rb", <<-EOS],
        module App0
          App1
        end
      EOS
      ["lib0/app0/foo.rb", <<-EOS],
        class App0::Foo
          App1::Foo
        end
      EOS
      ["lib1/app1/foo.rb", <<-EOS],
        class App1::Foo
          App0
        end
      EOS
      ["lib1/app1/foo/bar/baz.rb", <<-EOS]
        class App1::Foo::Bar::Baz
          App0::Foo
        end
      EOS
    ]
    with_files(files) do
      loaders[0].push_dir("lib0")
      loaders[0].setup

      loaders[1].push_dir("lib1")
      loaders[1].setup

      Zeitwerk::Loader.eager_load_all

      assert required?(files)
    end
  end

  test "eager loads gems" do
    on_teardown do
      remove_const :MyGem

      delete_loaded_feature "my_gem.rb"
      delete_loaded_feature "my_gem/foo.rb"
      delete_loaded_feature "my_gem/foo/bar.rb"
      delete_loaded_feature "my_gem/foo/baz.rb"
    end

    files = [
      ["my_gem.rb", <<-EOS],
        loader = Zeitwerk::Loader.for_gem
        loader.setup

        class MyGem
          Foo::Baz # autoloads fine
        end

        loader.eager_load
      EOS
      ["my_gem/foo.rb", "class MyGem::Foo; end"],
      ["my_gem/foo/bar.rb", "class MyGem::Foo::Bar; end"],
      ["my_gem/foo/baz.rb", "class MyGem::Foo::Baz; end"],
    ]

    with_files(files) do
      with_load_path(".") do
        require "my_gem"
        assert required?(files)
      end
    end
  end

  [false, true].each do |enable_reloading|
    test "we can opt-out of entire root directories, and still autoload (enable_autoloading #{enable_reloading})" do
      on_teardown do
        remove_const :Foo
        delete_loaded_feature "foo.rb"
      end

      files = [["foo.rb", "Foo = true"]]
      with_files(files) do
        loader = new_loader(dirs: ".", enable_reloading: enable_reloading)
        loader.do_not_eager_load(".")
        loader.eager_load

        assert !required?(files[0])
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

      files = [
        ["db_adapters/mysql_adapter.rb", <<-EOS],
          module DbAdapters::MysqlAdapter
          end
        EOS
        ["foo.rb", "Foo = true"]
      ]
      with_files(files) do
        loader = new_loader(dirs: ".", enable_reloading: enable_reloading)
        loader.do_not_eager_load("db_adapters")
        loader.eager_load

        assert !required?(files[0])
        assert required?(files[1])
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

      files = [
        ["foo.rb", "Foo = true"],
        ["bar.rb", "Bar = true"]
      ]
      with_files(files) do
        loader = new_loader(dirs: ".", enable_reloading: enable_reloading)
        loader.do_not_eager_load("bar.rb")
        loader.eager_load

        assert required?(files[0])
        assert !required?(files[1])
        assert Bar
      end
    end

    test "opt-ed out root directories sharing a namespace don't prevent autoload (enable_autoloading #{enable_reloading})" do
      on_teardown do
        remove_const :Ns

        delete_loaded_feature "ns/foo.rb"
        delete_loaded_feature "ns/bar.rb"
      end

      files = [
        ["lazylib/ns/foo.rb", "module Ns::Foo; end"],
        ["eagerlib/ns/bar.rb", "module Ns::Bar; end"]
      ]
      with_files(files) do
        loader = new_loader(dirs: %w(lazylib eagerlib), enable_reloading: enable_reloading)
        loader.do_not_eager_load('lazylib')
        loader.eager_load

        assert !required?(files[0])
        assert required?(files[1])
        assert Ns::Foo
      end
    end

    test "opt-ed out subdirectories don't prevent autoloading shared namespaces (enable_autoloading #{enable_reloading})" do
      on_teardown do
        remove_const :Ns

        delete_loaded_feature "ns/foo.rb"
        delete_loaded_feature "ns/bar.rb"
      end

      files = [
        ["lazylib/ns/foo.rb", "module Ns::Foo; end"],
        ["eagerlib/ns/bar.rb", "module Ns::Bar; end"]
      ]
      with_files(files) do
        loader = new_loader(dirs: %w(lazylib eagerlib), enable_reloading: enable_reloading)
        loader.do_not_eager_load('lazylib/ns')
        loader.eager_load

        assert !required?(files[0])
        assert required?(files[1])
        assert Ns::Foo
      end
    end
  end

  test "eager loading skips shadowed files" do
    files = [
      ["a/foo.rb", "Foo = 1"],
      ["b/foo.rb", "Foo = 1"]
    ]
    with_files(files) do
      la = new_loader(dirs: "a")
      lb = new_loader(dirs: "b")

      la.eager_load
      lb.eager_load

      assert required?(files[0])
      assert !required?(files[1])
    end
  end

  test "eager loading skips files that would map to already loaded constants" do
    on_teardown { remove_const :X }

    files = [["x.rb", "X = 1"]]
    ::X = 1
    with_setup(files) do
      loader.eager_load
      assert !required?(files[0])
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

  test "force eager load for root directories" do
    files = [["foo.rb", "Foo = true"]]
    with_setup(files) do
      loader.do_not_eager_load(".")
      loader.eager_load(force: true)

      assert required?(files)
    end
  end

  test "force eager load for sudirectories" do
    files = [
      ["db_adapters/mysql_adapter.rb", <<-EOS],
        module DbAdapters::MysqlAdapter
        end
      EOS
    ]
    with_setup(files) do
      loader.do_not_eager_load("db_adapters")
      loader.eager_load(force: true)

      assert required?(files)
      assert DbAdapters::MysqlAdapter
    end
  end

  test "force eager load for root files" do
    files = [["foo.rb", "Foo = true"]]
    with_setup(files) do
      loader.do_not_eager_load("foo.rb")
      loader.eager_load(force: true)

      assert required?(files)
    end
  end

  test "force eager load for namespaced files" do
    files = [["m/foo.rb", "M::Foo = true"]]
    with_setup(files) do
      loader.do_not_eager_load("m/foo.rb")
      loader.eager_load(force: true)

      assert required?(files)
    end
  end

  test "force eager load honours ignored root directories" do
    files = [["foo.rb", "Foo = true"]]
    with_files(files) do
      loader.ignore(".")
      loader.setup
      loader.eager_load(force: true)

      assert !required?(files)
    end
  end

  test "force eager load honours ignored subdirectories" do
    files = [["m/foo.rb", "M::Foo = true"]]
    with_files(files) do
      loader.ignore("m")
      loader.setup
      loader.eager_load(force: true)

      assert !required?(files)
    end
  end

  test "force eager load honours root files" do
    files = [["foo.rb", "Foo = true"]]
    with_files(files) do
      loader.ignore("foo.rb")
      loader.setup
      loader.eager_load(force: true)

      assert !required?(files)
    end
  end

  test "force eager load honours namespaced files" do
    files = [["m/foo.rb", "M::Foo = true"]]
    with_files(files) do
      loader.ignore("foo.rb")
      loader.setup
      loader.eager_load(force: true)

      assert !required?(files)
    end
  end

  test "files are eager loaded in lexicographic order" do
    files = [["x.rb", "X = 1"], ["y.rb", "Y = 1"]]
    with_setup(files) do
      loaded = []
      loader.on_load do |cpath, _value, _abspath|
        loaded << cpath
      end

      Dir.stub :children, ["y.rb", "x.rb"] do
        loader.eager_load
      end

      assert_equal ["X", "Y"], loaded
    end
  end
end
