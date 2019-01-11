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

      assert_equal 1, loader.autoloads.size
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

      assert_equal 1, loader.autoloads.size
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
end
