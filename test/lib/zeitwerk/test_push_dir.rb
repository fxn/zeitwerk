# frozen_string_literal: true

require "test_helper"
require "pathname"

class TesPushDir < LoaderTest
  module Namespace; end

  def check_dirs
    roots = loader.__roots

    non_ignored_roots = roots.reject { |dir, _| loader.send(:ignored_path?, dir) }

    dirs = loader.dirs
    assert_equal non_ignored_roots.keys, dirs
    assert dirs.frozen?

    dirs = loader.dirs(namespaces: true)
    assert_equal non_ignored_roots, dirs
    assert dirs.frozen?
    assert !dirs.equal?(roots)

    dirs = loader.dirs(ignored: true)
    assert_equal roots.keys, dirs
    assert dirs.frozen?

    dirs = loader.dirs(namespaces: true, ignored: true)
    assert_equal roots, dirs
    assert dirs.frozen?
    assert !dirs.equal?(roots)
  end

  test "accepts dirs as strings and associates them to the Object namespace" do
    loader.push_dir(".")
    check_dirs
  end

  test "accepts dirs as pathnames and associates them to the Object namespace" do
    loader.push_dir(Pathname.new("."))
    check_dirs
  end

  test "there can be several root directories" do
    files = [["rd1/x.rb", "X = 1"], ["rd2/y.rb", "Y = 1"], ["rd3/z.rb", "Z = 1"]]
    with_setup(files) do
      check_dirs
    end
  end

  test "there can be several root directories, some of them may be ignored" do
    files = [["rd1/x.rb", "X = 1"], ["rd2/y.rb", "Y = 1"], ["rd3/z.rb", "Z = 1"]]
    with_files(files) do
      loader.push_dir("rd1")
      loader.push_dir("rd2")
      loader.push_dir("rd3")
      loader.ignore("rd2")
      check_dirs
    end
  end

  test "accepts dirs as strings and associates them to the given namespace" do
    loader.push_dir(".", namespace: Namespace)
    check_dirs
  end

  test "accepts dirs as pathnames and associates them to the given namespace" do
    loader.push_dir(Pathname.new("."), namespace: Namespace)
    check_dirs
  end

  test "there can be several root directories, with custom namespaces" do
    files = [["rd1/x.rb", "X = 1"], ["rd2/y.rb", "Y = 1"], ["rd3/z.rb", "Z = 1"]]
    with_setup(files, namespace: Namespace) do
      check_dirs
    end
  end

  test "there can be several root directories, with custom namespaces, some of them may be ignored" do
    files = [["rd1/x.rb", "X = 1"], ["rd2/y.rb", "Y = 1"], ["rd3/z.rb", "Z = 1"]]
    with_files(files) do
      loader.push_dir("rd1", namespace: Namespace)
      loader.push_dir("rd2", namespace: Namespace)
      loader.push_dir("rd3", namespace: Namespace)
      loader.ignore("rd2")
      check_dirs
    end
  end

  test "raises on non-existing directories" do
    dir = File.expand_path("non-existing")
    e = assert_raises(Zeitwerk::Error) { loader.push_dir(dir) }
    assert_equal "the root directory #{dir} does not exist", e.message
  end

  test "raises if the namespace is not a class or module object" do
    e = assert_raises(Zeitwerk::Error) { loader.push_dir(".", namespace: :foo) }
    assert_equal ":foo is not a class or module object, should be", e.message
  end

  test "raises if the namespace is anonymous" do
    e = assert_raises(Zeitwerk::Error) { loader.push_dir(".", namespace: Module.new) }
    assert_equal "root namespaces cannot be anonymous", e.message
  end
end
