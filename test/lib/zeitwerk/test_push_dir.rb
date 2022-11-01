# frozen_string_literal: true

require "test_helper"
require "pathname"

class TesPushDir < LoaderTest
  module Namespace; end

  def check_dirs
    roots = loader.__roots

    dirs = loader.dirs
    assert_equal roots.keys, dirs
    assert dirs.frozen?

    dirs = loader.dirs(namespaces: true)
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

  test "accepts dirs as strings and associates them to the given namespace" do
    loader.push_dir(".", namespace: Namespace)
    check_dirs
  end

  test "accepts dirs as pathnames and associates them to the given namespace" do
    loader.push_dir(Pathname.new("."), namespace: Namespace)
    check_dirs
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
end
