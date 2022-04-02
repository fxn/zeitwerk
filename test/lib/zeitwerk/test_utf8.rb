# frozen_string_literal: true

require "test_helper"

class TestUTF8 < LoaderTest
  # In CI, the codepage for the Windows file system for Ruby 2.5, 2.6, and 2.7
  # is Windows-1252, and UTF-8 for Ruby >= 3.0. In Ubuntu, the file system is
  # encoded in UTF-8 for all supported Ruby versions.
  if Encoding::UTF_8 == Encoding.find("filesystem")
    test "autoloads in a project whose root directories have accented letters" do
      files = [["líb/x.rb", "X = true"]]
      with_setup(files, dirs: "líb") do
        assert X
      end
    end

    test "autoloads constants that have accented letters in the middle" do
      files = [["màxim.rb", "Màxim = 10_000"]]
      with_setup(files) do
        assert Màxim
      end
    end

    if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.6')
      test "autoloads constants that start with a Greek letter" do
        files = [["ω.rb", "Ω = true"]]
        with_setup(files) do
          assert Ω
        end
      end

      test "autoloads implicit namespaces that start with a Greek letter" do
        files = [["ω/à.rb", "Ω::À = true"]]
        with_setup(files) do
          assert Ω::À
        end
      end

      test "autoloads explicit namespaces that start with a Greek letter" do
        files = [
          ["ω.rb", "module Ω; end"],
          ["ω/à.rb", "Ω::À = true"]
        ]
        with_setup(files) do
          assert Ω::À
        end
      end
    end
  end
end
