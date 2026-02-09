# frozen_string_literal: true

require "test_helper"

class TestLs < LoaderTest
  def ls(dir = ".")
    dir = File.expand_path(dir)
    entries = []

    loader.send(:ls, dir) do |basename, abspath, ftype|
      entries << [basename, abspath, ftype]
    end

    entries
  end

  test "yields Ruby files, sorted" do
    files = ["b.rb", "a.rb"]
    with_files(files) do
      assert_equal [
        ["a.rb", File.expand_path("a.rb"), :file],
        ["b.rb", File.expand_path("b.rb"), :file]
      ], ls
    end
  end

  test "follows symlinks to Ruby files" do
    files = ["targets/a.rb", "targets/b.rb"]
    with_files(files) do
      FileUtils.mkdir_p("links")

      FileUtils.ln_s(File.expand_path("targets/a.rb"), "links/a_link.rb")
      FileUtils.ln_s(File.expand_path("targets/b.rb"), "links/b_link.rb")

      assert_equal [
        ["a_link.rb", File.expand_path("links/a_link.rb"), :file],
        ["b_link.rb", File.expand_path("links/b_link.rb"), :file]
      ], ls("links")
    end
  end

  test "yields directories with Ruby files, sorted" do
    files = ["b/c.rb", "a/d.rb"]
    with_files(files) do
      assert_equal [
        ["a", File.expand_path("a"), :directory],
        ["b", File.expand_path("b"), :directory]
      ], ls
    end
  end

  test "follows symlinks to directories" do
    files = ["targets/a/x.rb", "targets/b/y.rb"]
    with_files(files) do
      FileUtils.mkdir_p("links")
      FileUtils.ln_s(File.expand_path("targets/a"), "links/a_link")
      FileUtils.ln_s(File.expand_path("targets/b"), "links/b_link")

      assert_equal [
        ["a_link", File.expand_path("links/a_link"), :directory],
        ["b_link", File.expand_path("links/b_link"), :directory]
      ], ls("links")
    end
  end

  test "ignores hidden files, even if they have a .rb extension" do
    files = [".hidden.rb"]
    with_files(files) do
      assert_empty ls
    end
  end

  test "ignores directories without Ruby files" do
    files = ["tasks/billing/generate_bills.rake"]
    with_files(files) do
      assert_empty ls
    end
  end

  test "ignores ignored paths" do
    files = ["ignored.rb", "ignored/a.rb"]
    with_setup(files) do
      assert_empty ls
    end
  end

  test "ignores root directories" do
    files = ["rd/a.rb"]
    with_setup(files) do
      assert_empty ls
    end
  end
end
