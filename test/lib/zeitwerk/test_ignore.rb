require "test_helper"
require "set"

class TestIgnore < LoaderTest
  test "ignored root directories are ignored" do
    files = [["x.rb", "X = true"]]
    with_files(files) do
      loader.push_dir(".")
      loader.ignore(".")

      assert_empty loader.autoloads
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

      assert_equal 1, loader.autoloads.size
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

      assert_equal 1, loader.autoloads.size
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
    assert_equal [a, b].to_set, loader.ignored
  end

  test "supports an array" do
    a = "#{Dir.pwd}/a.rb"
    b = "#{Dir.pwd}/b.rb"
    loader.ignore([a, b])
    assert_equal [a, b].to_set, loader.ignored
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

  test "ignored paths can be used by another instance" do
    on_teardown do
      # we loaded it manually, so we have to deal with it manually
      remove_const :Food
      remove_const :Drink
      %i[food fish cod drink juice cold].each do |name|
        delete_loaded_feature "#{name}.rb"
      end
    end

    # we have to use full path here, to been able to create all required files
    # before the test
    push_dir = Pathname.new(LoaderTest::TMP_DIR).
               expand_path.join('a/b/c/ar/models')

    nested_files = [
      ["a/b/c/ar.rb", <<-EOS],
        loader = Zeitwerk::Loader.new
        loader.push_dir "#{push_dir}"
        loader.setup
        loader.eager_load
      EOS
      ["a/b/c/ar/models/food.rb", "class Food; end"],
      ["a/b/c/ar/models/food/fish.rb", "class Food::Fish; end"],
      ["a/b/c/ar/models/food/fish/cod.rb", "class Food::Fish::Cod; end"],
      ["a/b/c/ar/models/drink/juice/cold.rb", "class Drink::Juice::Cold; end"],
    ]
    all_files = [
      ["a/b/z.rb", "class A::B::Z; require_relative 'c/ar' ;end"],
      *nested_files
    ]

    with_files(all_files) do
      loader.push_dir(".")
      loader.ignore("a/b/c")
      loader.setup

      assert_raises(NameError) { Food::Fish::Cod }
      assert_raises(NameError) { Drink::Juice::Cold }

      assert A::B::Z
      assert Food::Fish::Cod
      assert Drink::Juice::Cold
    end
  end
end
