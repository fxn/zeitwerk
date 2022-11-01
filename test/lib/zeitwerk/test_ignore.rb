# frozen_string_literal: true

require "test_helper"
require "set"

class TestIgnore < LoaderTest
  def this_dir
    @this_dir ||= __dir__
  end

  def this_file
    @this_file ||= File.expand_path(__FILE__, this_dir)
  end

  def ascendant
    @dir_up ||= File.expand_path("#{this_dir}/../..")
  end

  test "ignored root directories are ignored" do
    files = [["x.rb", "X = true"]]
    with_files(files) do
      loader.push_dir(".")
      loader.ignore(".")
      loader.setup

      assert !Object.autoload?(:X)
      assert_raises(NameError) { ::X }
    end
  end

  test "ignored files are ignored" do
    files = [
      ["x.rb", "X = true"],
      ["y.rb", "Y = true"]
    ]
    with_files(files) do
      loader.push_dir(".")
      loader.ignore("y.rb")
      loader.setup

      assert Object.autoload?(:X)
      assert !Object.autoload?(:Y)

      assert ::X
      assert_raises(NameError) { ::Y }
    end
  end

  test "ignored directories are ignored" do
    files = [
      ["x.rb", "X = true"],
      ["m/a.rb", "M::A = true"],
      ["m/b.rb", "M::B = true"],
      ["m/c.rb", "M::C = true"]
    ]
    with_files(files) do
      loader.push_dir(".")
      loader.ignore("m")
      loader.setup

      assert Object.autoload?(:X)
      assert !Object.autoload?(:M)

      assert ::X
      assert_raises(NameError) { ::M }
    end
  end

  test "ignored files are not eager loaded" do
    files = [
      ["x.rb", "X = true"],
      ["y.rb", "Y = true"]
    ]
    with_files(files) do
      loader.push_dir(".")
      loader.ignore("y.rb")
      loader.setup
      loader.eager_load

      assert ::X
      assert_raises(NameError) { ::Y }
    end
  end

  test "ignored directories are not eager loaded" do
    files = [
      ["x.rb", "X = true"],
      ["m/a.rb", "M::A = true"],
      ["m/b.rb", "M::B = true"],
      ["m/c.rb", "M::C = true"]
    ]
    with_files(files) do
      loader.push_dir(".")
      loader.ignore("m")
      loader.setup
      loader.eager_load

      assert ::X
      assert_raises(NameError) { ::M }
    end
  end

  test "supports several arguments" do
    a = "#{Dir.pwd}/a.rb"
    b = "#{Dir.pwd}/b.rb"
    loader.ignore(a, b)
    assert_equal [a, b].to_set, loader.send(:ignored_glob_patterns)
  end

  test "supports an array" do
    a = "#{Dir.pwd}/a.rb"
    b = "#{Dir.pwd}/b.rb"
    loader.ignore([a, b])
    assert_equal [a, b].to_set, loader.send(:ignored_glob_patterns)
  end

  test "supports glob patterns" do
    files = [
      ["admin/user.rb", "class Admin::User; end"],
      ["admin/user_test.rb", "class Admin::UserTest < Minitest::Test; end"]
    ]
    with_files(files) do
      loader.push_dir(".")
      loader.ignore("**/*_test.rb")
      loader.setup

      assert Admin::User
      assert_raises(NameError) { Admin::UserTest }
    end
  end

  test "ignored paths are recomputed on reload" do
    files = [
      ["user.rb", "class User; end"],
      ["user_test.rb", "class UserTest < Minitest::Test; end"],
    ]
    with_files(files) do
      loader.push_dir(".")
      loader.ignore("*_test.rb")
      loader.setup

      assert User
      assert_raises(NameError) { UserTest }

      File.write("post.rb", "class Post; end")
      File.write("post_test.rb", "class PostTest < Minitest::Test; end")

      loader.reload

      assert Post
      assert_raises(NameError) { PostTest }
    end
  end

  test "returns true if a directory is ignored as is" do
    loader.ignore(this_dir)
    assert loader.__ignores?(this_dir)
  end

  test "returns true if a file is ignored as is" do
    loader.ignore(this_file)
    assert loader.__ignores?(this_file)
  end

  test "returns true for a descendant of an ignored directory" do
    loader.ignore(ascendant)
    assert loader.__ignores?(this_dir)
  end

  test "returns true for a file in a descendant of an ignored directory" do
    loader.ignore(ascendant)
    assert loader.__ignores?(this_file)
  end

  test "returns false for the directory of an ignored file" do
    loader.ignore(this_file)
    assert !loader.__ignores?(this_dir)
  end

  test "returns false for an ascendant directory of an ignored directory" do
    loader.ignore(this_dir)
    assert !loader.__ignores?(ascendant)
  end

  test "returns false if nothing is ignored" do
    assert !loader.__ignores?(this_dir)
    assert !loader.__ignores?(this_file)
  end
end
