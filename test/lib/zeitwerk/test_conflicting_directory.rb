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
end
