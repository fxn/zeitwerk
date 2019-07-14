require "test_helper"

class TestTopLevel < LoaderTest
  test "autoloads a simple constant in a top-level file" do
    files = [["x.rb", "X = true"]]
    with_setup(files) do
      assert X
    end
  end

  test "autoloads a simple class in a top-level file" do
    files = [["app/models/user.rb", "class User; end"]]
    with_setup(files, dirs: "app/models") do
      assert User
    end
  end

  test "autoloads several top-level classes" do
    files = [
      ["app/models/user.rb", "class User; end"],
      ["app/controllers/users_controller.rb", "class UsersController; User; end"]
    ]
    with_setup(files, dirs: %w(app/models app/controllers)) do
      assert UsersController
    end
  end

  test "autoloads only the first of multiple occurrences" do
    files = [
      ["app/models/user.rb", "User = :model"],
      ["app/decorators/user.rb", "User = :decorator"],
    ]
    with_setup(files, dirs: %w(app/models app/decorators)) do
      assert_equal :model, User
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
      assert_empty loader.autoloads
    end
  end
end
