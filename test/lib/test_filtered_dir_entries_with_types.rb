# frozen_string_literal: true

require "test_helper"

class TestExtendedDirChildren < LoaderTest
  test "filtered_dir_entries_with_type" do
    files = [
      ["file.rb", ""],
      ["plain.txt", ""],
      [".hidden.rb", ""],
      ["dir/nested.rb", ""]
    ]

    with_files(files) do
      if File.respond_to?(:symlink)
        File.symlink("file.rb", "file_link.rb")
        File.symlink("dir", "dir_link")
      end

      if File.respond_to?(:mkfifo)
        File.mkfifo("pipe")
      end

      entries = loader.__send__(:filtered_dir_entries_with_type, TMP_DIR)
      entries_by_name = entries.to_h

      refute_includes entries_by_name.keys, "."
      refute_includes entries_by_name.keys, ".."

      assert_equal :file, entries_by_name["file.rb"]
      refute_includes entries_by_name.keys, "plain.txt"
      assert_equal :directory, entries_by_name["dir"]
      refute_includes entries_by_name.keys, ".hidden.rb"


      if File.respond_to?(:symlink)
        assert_equal :file, entries_by_name["file_link.rb"]
        assert_equal :directory, entries_by_name["dir_link"]
      end

      if File.respond_to?(:mkfifo)
        refute_includes entries_by_name.keys, "pipe"
      end
    end
  end
end
