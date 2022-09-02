# frozen_string_literal: true

require "test_helper"
require "set"

class TestCollapse < LoaderTest
  test "top-level directories can be collapsed" do
    files = [["foo/bar/x.rb", "Bar::X = true"]]
    with_files(files) do
      loader.push_dir(".")
      loader.collapse("foo")
      loader.setup

      assert Bar::X
    end
  end

  test "collapsed directories are ignored as namespaces" do
    files = [["foo/bar/x.rb", "Foo::X = true"]]
    with_files(files) do
      loader.push_dir(".")
      loader.collapse("foo/bar")
      loader.setup

      assert Foo::X
    end
  end

  test "collapsed directories are ignored as explicit namespaces" do
    files = [
      ["foo.rb", "Foo = true"],
      ["foo/x.rb", "X = true"]
    ]
    with_files(files) do
      loader.push_dir(".")
      loader.collapse("foo")
      loader.setup

      assert Foo
      assert X
    end
  end

  test "explicit namespaces are honored downwards" do
    files = [
      ["foo.rb", "module Foo; end"],
      ["foo/foo/x.rb", "Foo::X = true"]
    ]
    with_files(files) do
      loader.push_dir(".")
      loader.collapse("foo")
      loader.setup

      assert Foo::X
    end
  end

  test "explicit namespaces are honored downwards, deeper" do
    files = [
      ["foo.rb", "module Foo; end"],
      ["foo/bar/foo/x.rb", "Foo::X = true"]
    ]
    with_files(files) do
      loader.push_dir(".")
      loader.collapse(["foo", "foo/bar"])
      loader.setup

      assert Foo::X
    end
  end

  test "accepts several arguments" do
    files = [
      ["foo/bar/x.rb", "Foo::X = true"],
      ["zoo/bar/x.rb", "Zoo::X = true"]
    ]
    with_files(files) do
      loader.push_dir(".")
      loader.collapse("foo/bar", "zoo/bar")
      loader.setup

      assert Foo::X
      assert Zoo::X
    end
  end

  test "accepts an array" do
    files = [
      ["foo/bar/x.rb", "Foo::X = true"],
      ["zoo/bar/x.rb", "Zoo::X = true"]
    ]
    with_files(files) do
      loader.push_dir(".")
      loader.collapse(["foo/bar", "zoo/bar"])
      loader.setup

      assert Foo::X
      assert Zoo::X
    end
  end

  test "supports glob patterns" do
    files = [
      ["foo/bar/x.rb", "Foo::X = true"],
      ["zoo/bar/x.rb", "Zoo::X = true"]
    ]
    with_files(files) do
      loader.push_dir(".")
      loader.collapse("*/bar")
      loader.setup

      assert Foo::X
      assert Zoo::X
    end
  end

  test "collapse directories are recomputed on reload" do
    files = [["foo/bar/x.rb", "Foo::X = true"]]
    with_files(files) do
      loader.push_dir(".")
      loader.collapse("*/bar")
      loader.setup

      assert Foo::X
      assert_raises(NameError) { Zoo::X }

      FileUtils.mkdir_p("zoo/bar")
      File.write("zoo/bar/x.rb", "Zoo::X = true")

      loader.reload

      assert Foo::X
      assert Zoo::X
    end
  end

  test "collapse directories are honored when eager loading" do
    $collapse_honored_when_eager_loading = false
    files = [["foo/bar/x.rb", "Foo::X = true; $collapse_honored_when_eager_loading = true"]]
    with_files(files) do
      loader.push_dir(".")
      loader.collapse("foo/bar")
      loader.setup
      loader.eager_load

      assert $collapse_honored_when_eager_loading
    end
  end

  test "collapsed top-level directories are eager loaded too" do
    $collapse_honored_when_eager_loading = false
    files = [["foo/bar/x.rb", "Bar::X = true; $collapse_honored_when_eager_loading = true"]]
    with_files(files) do
      loader.push_dir(".")
      loader.collapse("foo")
      loader.setup
      loader.eager_load

      assert $collapse_honored_when_eager_loading
    end
  end
end
