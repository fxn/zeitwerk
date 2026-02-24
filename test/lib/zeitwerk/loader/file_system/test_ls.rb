# frozen_string_literal: true

require "fileutils"
require "timeout"
require "test_helper"

class TestFileSystemLS < LoaderTest
  def setup
    super
    @fs = loader.instance_variable_get(:@fs)
  end

  def yielded(dir)
    yielded = []
    @fs.ls(dir) { |*entry| yielded << entry }
    yielded
  end

  test "ls yields Ruby files" do
    with_files(["user.rb"]) do |cwd|
      assert_equal [["user.rb", "#{cwd}/user.rb", :file]], yielded(cwd)
    end
  end

  test "ls yields symlinks with .rb extension and the extension of the original file is irrelevant" do
    with_files(["original.whatever"]) do |cwd|
      original = File.expand_path("original.whatever")
      FileUtils.ln_s(original, "#{cwd}/symlink.rb")
      assert_equal [["symlink.rb", "#{cwd}/symlink.rb", :file]], yielded(cwd)
    end
  rescue NotImplementedError
    skip "Symlinks are not supported on this platform, it is OK"
  end

  test "ls yields directories with Ruby files" do
    with_files(["admin/users_controller.rb"]) do |cwd|
      assert_equal [["admin", "#{cwd}/admin", :directory]], yielded(cwd)
    end
  end

  test "ls yields symlinks to directories" do
    with_files(["out/original/users_controller.rb"]) do |cwd|
      FileUtils.mkdir("project")
      FileUtils.ln_s("#{cwd}/out/original", "#{cwd}/project/symlink")
      assert_equal [["symlink", "#{cwd}/project/symlink", :directory]], yielded("#{cwd}/project")
    end
  end

  test "ls does not loop forever if a directory graph has cycles" do
    begin
      original = @fs.method(:relevant_dir_entries)
      stat = Struct.new(:dev, :ino)

      @fs.define_singleton_method(:relevant_dir_entries) do |dir, &block|
        if block
          case dir
          when "/a"
            block.call("b", "/b", :directory)
          when "/b"
            block.call("a", "/a", :directory)
          end
        else
          original.call(dir)
        end
      end

      File.stub :stat, ->(dir) { dir == "/a" ? stat.new(1, 1) : stat.new(1, 2) } do
        assert_equal false, Timeout.timeout(1) { @fs.send(:has_at_least_one_ruby_file?, "/a") }
      end
    ensure
      @fs.singleton_class.send(:define_method, :relevant_dir_entries, original)
    end
  end

  test "ls yields entries in sorted order" do
    with_files(["b.rb", "c/foo.rb", "a.rb"]) do |cwd|
      assert_equal ["a.rb", "b.rb", "c"], yielded(cwd).map(&:first)
    end
  end

  test "ls ignores hidden files and directories" do
    with_files([".hidden"]) do |cwd|
      assert_empty yielded(cwd)
    end
  end

  test "ls ignores files without .rb extension" do
    with_files(["main.js", "Gemfile"]) do |cwd|
      assert_empty yielded(cwd)
    end
  end

  test "ls ignores directories without Ruby files" do
    with_files(["assets/home.css"]) do |cwd|
      assert_empty yielded(cwd)
    end
  end

  test "ls ignores ignored Ruby files" do
    with_setup(["ignored.rb"]) do |cwd|
      assert_empty yielded(cwd)
    end
  end

  test "ls ignores ignored directories" do
    with_setup(["ignored/users_controller.rb"]) do |cwd|
      assert_empty yielded(cwd)
    end
  end

  test "ls ignores directories with only ignored Ruby files" do
    with_setup(["admin/ignored.rb"]) do |cwd|
      assert_empty yielded(cwd)
    end
  end

  test "ls ignores nested root directories" do
    with_setup(["rd/user.rb"], dirs: %w(. rd)) do |cwd|
      assert_empty yielded(cwd)
    end
  end
end
