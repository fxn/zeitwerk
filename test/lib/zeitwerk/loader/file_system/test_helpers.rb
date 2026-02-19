# frozen_string_literal: true

require "fileutils"
require "test_helper"

class TestFileSystemUtilities < LoaderTest
  ABSPATHS_WITHOUT_RB_EXTENSION = %W(/tmp/Rakefile /tmp/README.md /tmp/template.rb.erb).freeze

  def setup
    super
    @fs = loader.instance_variable_get(:@fs)
  end

  # --- supported_ftype? ---

  test "supported_ftype? return :file is the extension is .rb" do
    assert_equal :file, @fs.supported_ftype?(__FILE__)
  end

  test "supported_ftype? return :directory if it's a directory" do
    assert_equal :directory, @fs.supported_ftype?(__dir__)
  end

  test "supported_ftype? return nil for anything else" do
    ABSPATHS_WITHOUT_RB_EXTENSION.each do |file_name|
      assert_nil @fs.supported_ftype?(file_name)
    end
  end

  # --- rb_extension? ---

  test "rb_extension? returns true if the argument has extension .rb" do
    assert @fs.rb_extension?(__FILE__)
  end

  test "rb_extension? return false otherwise" do
    ABSPATHS_WITHOUT_RB_EXTENSION.each do |file_name|
      assert !@fs.rb_extension?(file_name)
    end
  end

  # --- dir? ---

  test "dir? returns true if the argument is the name of an existing directory" do
    assert @fs.dir?(__dir__)
  end

  test "dir? returns true if the argument is the name of a symlink of an existing directory" do
    with_files do
      original = File.expand_path("original")
      FileUtils.mkdir('original')
      assert @fs.dir?(original) # precondition

      symlink = File.expand_path("symlink")
      FileUtils.ln_s(original, symlink)
      assert @fs.dir?(symlink)
    end
  rescue NotImplementedError
    skip "Symlinks are not supported on this platform, it is OK"
  end

  test "dir? return false otherwise" do
    assert !@fs.dir?(__FILE__)
  end

  # --- walk_up ---

  test "walk_up yields the given directory and its ancestors" do
    dir = Pathname.new(__dir__)

    expected = []
    dir.ascend { expected << _1.to_path }

    yielded = []
    @fs.walk_up(dir.to_path) { yielded << _1 }

    assert_equal expected, yielded
  end

    test "walk_up does not assume the directory exists" do
    dir = "/foo/bar/baz"

    yielded = []
    @fs.walk_up(dir) { yielded << _1 }

    assert_equal ["/foo/bar/baz", "/foo/bar", "/foo", "/"], yielded
  end
end
