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

  test "eager loading skips repeated files" do
    $test_eager_loaded_file = nil
    files = [
      ["a/foo.rb", "Foo = 1; $test_eager_loaded_file = :a"],
      ["b/foo.rb", "Foo = 1; $test_eager_loaded_file = :b"]
    ]
    with_files(files) do
      la = Zeitwerk::Loader.new
      la.push_dir("a")
      la.setup

      lb = Zeitwerk::Loader.new
      lb.push_dir("b")
      lb.setup

      la.eager_load
      lb.eager_load

      assert_equal :a, $test_eager_loaded_file
    end
  end

  test "eager loading skips files that would map to already loaded constants" do
    $test_eager_loaded_file = false
    files = [["x.rb", "X = 1; $test_eager_loaded_file = true"]]
    ::X = 1
    with_setup(files) do
      loader.eager_load
      assert !$test_eager_loaded_file
    end
    remove_const :X
  end
end
