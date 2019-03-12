require "test_helper"

class TestMultiple < LoaderTest
  test "multiple independent loaders" do
    loaders = [loader, Zeitwerk::Loader.new]

    files = [
      ["lib0/app0.rb", "module App0; end"],
      ["lib0/app0/foo.rb", "class App0::Foo; end"],
      ["lib1/app1/foo.rb", "class App1::Foo; end"],
      ["lib1/app1/foo/bar/baz.rb", "class App1::Foo::Bar::Baz; end"]
    ]
    with_files(files) do
      loaders[0].push_dir("lib0")
      loaders[1].push_dir("lib1")
      loaders.each(&:setup)

      assert App0::Foo
      assert App1::Foo::Bar::Baz
    end
  end

  test "multiple dependent loaders" do
    loaders = [loader, Zeitwerk::Loader.new]

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
      loaders[1].push_dir("lib1")
      loaders.each(&:setup)

      assert App0::Foo
      assert App1::Foo::Bar::Baz
    end
  end

  test "multiple loaders sharing an autovivified namespace" do
    loaders = [loader, Zeitwerk::Loader.new]

    files = [
      ["lib0/namespace/foo.rb", <<-EOS],
        module Namespace
          class Foo
          end
        end
      EOS
      ["lib1/namespace/bar.rb", <<-EOS]
        module Namespace
          class Bar
          end
        end
      EOS
    ]
    with_files(files) do
      loaders[0].push_dir("lib0")
      loaders[1].push_dir("lib1")
      loaders.each(&:setup)

      assert ::Namespace
      assert ::Namespace::Foo
      assert ::Namespace::Bar
    end
  end

  test "multiple loaders sharing an explicit namespace" do
    loaders = [loader, Zeitwerk::Loader.new]

    files = [
      ["lib0/namespace.rb", <<-EOS],
        module Namespace
        end
      EOS
      ["lib0/namespace/foo.rb", <<-EOS],
        module Namespace
          class Foo
          end
        end
      EOS
      ["lib1/namespace/bar.rb", <<-EOS]
        module Namespace
          class Bar
          end
        end
      EOS
    ]
    with_files(files) do
      loaders[0].push_dir("lib0")
      loaders[0].tag = 'lib0'
      loaders[1].push_dir("lib1")
      loaders[1].tag = 'lib1'
      loaders.each(&:setup)

      assert ::Namespace
      assert ::Namespace::Foo
      assert ::Namespace::Bar
    end
  end
end
