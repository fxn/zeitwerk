require "test_helper"
require "set"

class TestIgnore < LoaderTest
  test "ignored root directories are ignored" do
    files = [["x.rb", "X = true"]]
    with_files(files) do
      loader.push_dir(".")
      loader.ignore(".")

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
    assert_equal [a, b].to_set, loader.ignored_glob_patterns
  end

  test "supports an array" do
    a = "#{Dir.pwd}/a.rb"
    b = "#{Dir.pwd}/b.rb"
    loader.ignore([a, b])
    assert_equal [a, b].to_set, loader.ignored_glob_patterns
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
end
