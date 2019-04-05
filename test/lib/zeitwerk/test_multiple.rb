require "test_helper"

class TestMultiple < LoaderTest
  test "multiple independent loaders" do
    files = [
      ["lib0/app0.rb", "module App0; end"],
      ["lib0/app0/foo.rb", "class App0::Foo; end"],
      ["lib1/app1/foo.rb", "class App1::Foo; end"],
      ["lib1/app1/foo/bar/baz.rb", "class App1::Foo::Bar::Baz; end"]
    ]
    with_files(files) do
      new_loader(dirs: "lib0")
      new_loader(dirs: "lib1")

      assert App0::Foo
      assert App1::Foo::Bar::Baz
    end
  end

  test "multiple dependent loaders" do
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
      new_loader(dirs: "lib0")
      new_loader(dirs: "lib1")

      assert App0::Foo
      assert App1::Foo::Bar::Baz
    end
  end
end
