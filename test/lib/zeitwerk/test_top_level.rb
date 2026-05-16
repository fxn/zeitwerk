# frozen_string_literal: true

require "test_helper"

class TestTopLevel < LoaderTest
  module Namespace; end

  test "autoloads a simple constant in a top-level file (Object)" do
    files = [["x.rb", "X = true"]]
    with_setup(files) do
      assert X
    end
  end

  test "autoloads a simple constant in a top-level file (Namespace)" do
    files = [["x.rb", "#{Namespace}::X = true"]]
    with_setup(files, namespace: Namespace) do
      assert Namespace::X
    end
  end

  test "autoloads a simple class in a top-level file (Object)" do
    files = [["user.rb", "class User; end"]]
    with_setup(files) do
      assert User
    end
  end

  test "autoloads a simple class in a top-level file (Namespace)" do
    files = [["user.rb", "class #{Namespace}::User; end"]]
    with_setup(files, namespace: Namespace) do
      assert Namespace::User
    end
  end

  test "autoloads several top-level classes" do
    files = [
      ["rd1/user.rb", "class User; end"],
      ["rd2/users_controller.rb", "class UsersController; User; end"]
    ]
    with_setup(files) do
      assert UsersController
    end
  end

  test "anything other than Ruby and visible directories is ignored" do
    files = [
      ["x.txt", ""],              # Programmer notes
      ["x.lua", ""],              # Lua files for Redis
      ["x.yaml", ""],             # Included configuration
      ["x.json", ""],             # Included configuration
      ["x.erb", ""],              # Included template
      ["x.jpg", ""],              # Included image
      ["x.rb~", ""],              # Emacs auto backup
      ["#x.rb#", ""],             # Emacs auto save
      [".filename.swp", ""],      # Vim swap file
      ["4913", ""],               # May be created by Vim
      [".idea/workspace.xml", ""] # RubyMine
    ]
    with_setup(files) do
      assert_empty loader.__autoloads
    end
  end

  test "shadowed file managed by the loader" do
    files = [["rd1/x.rb", "X = :rd1"], ["rd2/x.rb", "X = :rd2"]]
    with_setup(files) do
      assert_equal :rd1, X
    end
  end

  test "file shadowed by an already defined constant" do
    string_oid = String.object_id

    files = [["string.rb"]]
    with_setup(files) do
      assert_equal string_oid, String.object_id
    end
  end
end
