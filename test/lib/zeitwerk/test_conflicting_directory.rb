# frozen_string_literal: true

require "test_helper"

class TestConflictingDirectory < LoaderTest
  def dir
    __dir__
  end

  def parent
    File.expand_path("..", dir)
  end

  def existing_loader
    @existing_loader ||= new_loader(setup: false)
  end

  def loader
    @loader ||= new_loader(setup: false)
  end

  def conflicting_directory_message(dir)
    require "pp"
    "loader\n\n#{loader.pretty_inspect}\n\nwants to manage directory #{dir}," \
    " which is already managed by\n\n#{existing_loader.pretty_inspect}\n"
  end

  test "raises if an existing loader manages the same root dir" do
    existing_loader.push_dir(dir)

    e = assert_raises(Zeitwerk::Error) { loader.push_dir(dir) }
    assert_equal conflicting_directory_message(dir), e.message
  end

  test "raises if an existing loader manages a parent directory" do
    existing_loader.push_dir(parent)

    e = assert_raises(Zeitwerk::Error) { loader.push_dir(dir) }
    assert_equal conflicting_directory_message(dir), e.message
  end

  test "raises if an existing loader manages a subdirectory" do
    existing_loader.push_dir(dir)

    e = assert_raises(Zeitwerk::Error) { loader.push_dir(parent) }
    assert_equal conflicting_directory_message(parent), e.message
  end

  test "does not raise if an existing loader manages a directory with a matching prefix" do
    files = [["foo/x.rb", "X = 1"], ["foobar/y.rb", "Y = 1"]]
    with_files(files) do
      existing_loader.push_dir("foo")
      assert loader.push_dir("foobar")
    end
  end

  test "does not raise if an existing loader ignores the directory (dir)" do
    existing_loader.push_dir(parent)
    existing_loader.ignore(dir)
    assert loader.push_dir(dir)
  end

  test "does not raise if an existing loader ignores the directory (glob pattern)" do
    existing_loader.push_dir(parent)
    existing_loader.ignore("#{parent}/*")
    assert loader.push_dir(dir)
  end

  test "does not raise if the loader ignores a directory managed by an existing loader (dir)" do
    existing_loader.push_dir(dir)
    loader.ignore(dir)
    assert loader.push_dir(parent)
  end

  test "does not raise if the loader ignores a directory managed by an existing loader (glob pattern)" do
    existing_loader.push_dir(dir)
    loader.ignore("#{parent}/*")
    assert loader.push_dir(parent)
  end

  test "raises if an existing loader ignores a directory with a matching prefix" do
    files = [["foo/x.rb", "X = 1"], ["foobar/y.rb", "Y = 1"]]
    with_files(files) do
      ignored         = File.expand_path("foo")
      conflicting_dir = File.expand_path("foobar")

      existing_loader.push_dir(".")
      existing_loader.ignore(ignored)

      e = assert_raises(Zeitwerk::Error) { loader.push_dir(conflicting_dir) }
      assert_equal conflicting_directory_message(conflicting_dir), e.message
    end
  end
end
