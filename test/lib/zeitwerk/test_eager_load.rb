require "test_helper"

class TestEagerLoad < LoaderTest
  test "eager loads independent files" do
    loaders = [loader, Zeitwerk::Loader.new]

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
    loaders = [loader, Zeitwerk::Loader.new]

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

  test "we can opt-out of entire root directories, and still autoload" do
    $test_eager_load_eager_loaded_p = false
    files = [["foo.rb", "Foo = true; $test_eager_load_eager_loaded_p = true"]]
    with_setup(files) do
      loader.do_not_eager_load(".")
      loader.eager_load

      assert !$test_eager_load_eager_loaded_p
      assert Foo
    end
  end

  test "we can opt-out of sudirectories, and still autoload" do
    $test_eager_load_eager_loaded_p = false
    files = [
      ["db_adapters/mysql_adapter.rb", <<-EOS],
        module DbAdapters::MysqlAdapter
        end
        $test_eager_load_eager_loaded_p = true
      EOS
      ["foo.rb", "Foo = true"]
    ]
    with_setup(files) do
      loader.do_not_eager_load("db_adapters")
      loader.eager_load

      assert Foo
      assert !$test_eager_load_eager_loaded_p
      assert DbAdapters::MysqlAdapter
    end
  end

  test "we can opt-out of files, and still autoload" do
    $test_eager_load_eager_loaded_p = false
    files = [
      ["foo.rb", "Foo = true"],
      ["bar.rb", "Bar = true; $test_eager_load_eager_loaded_p = true"]
    ]
    with_setup(files) do
      loader.do_not_eager_load("bar.rb")
      loader.eager_load

      assert Foo
      assert !$test_eager_load_eager_loaded_p
      assert Bar
    end
  end
end
