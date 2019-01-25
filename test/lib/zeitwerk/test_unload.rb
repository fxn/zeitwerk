require "test_helper"

class TestUnload < LoaderTest
  test "unload removes all autoloaded constants" do
    files = [
      ["user.rb", "class User; end"],
      ["admin/root.rb", "class Admin::Root; end"]
    ]
    with_setup(files) do
      assert User
      assert Admin::Root
      admin = Admin

      loader.unload

      assert !Object.const_defined?(:User)
      assert !Object.const_defined?(:Admin)
      assert !admin.const_defined?(:Root)
    end
  end

  test "unload removes non-executed autoloads" do
    files = [["x.rb", "X = true"]]
    with_setup(files) do
      # This does not autolaod, see the compatibility test.
      assert Object.const_defined?(:X)
      loader.unload
      assert !Object.const_defined?(:X)
    end
  end

  test "unload clears internal caches" do
    files = [
      ["user.rb", "class User; end"],
      ["admin/root.rb", "class Admin::Root; end"]
    ]
    with_setup(files) do
      assert User
      assert Admin::Root

      assert !loader.autoloads.empty?
      assert !loader.loaded.empty?
      assert !loader.lazy_subdirs.empty?

      loader.unload

      assert loader.autoloads.empty?
      assert loader.loaded.empty?
      assert loader.lazy_subdirs.empty?
    end
  end

  test "unload does not assume autoloaded constants are still there" do
    files = [["x.rb", "X = true"]]
    with_setup(files) do
      assert X
      assert Object.send(:remove_const, :X) # user removed by hand
      loader.unload # should not raise
    end
  end
end
