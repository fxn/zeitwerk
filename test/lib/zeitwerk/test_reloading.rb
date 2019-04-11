require "test_helper"

class TestReloading < LoaderTest
  test "enabling reloading after setup raises" do
    e = assert_raises(Zeitwerk::Error) do
      loader = Zeitwerk::Loader.new
      loader.setup
      loader.enable_reloading
    end
    assert_equal "cannot enable reloading after setup", e.message
  end

  test "enabling reloading is idempotent, even after setup" do
    assert loader.reloading_enabled? # precondition
    loader.setup
    loader.enable_reloading # should not raise
    assert loader.reloading_enabled?
  end

  test "reloading works if the flag is set" do
    files = [
      ["x.rb", "X = 1"],         # top-level
      ["y.rb", "module Y; end"], # explicit namespace
      ["y/a.rb", "Y::A = 1"],
      ["z/a.rb", "Z::A = 1"]     # implicit namespace
    ]
    with_setup(files) do
      assert_equal 1, X
      assert_equal 1, Y::A
      assert_equal 1, Z::A

      y_object_id = Y.object_id
      z_object_id = Z.object_id

      File.write("x.rb", "X = 2")
      File.write("y/a.rb", "Y::A = 2")
      File.write("z/a.rb", "Z::A = 2")

      loader.reload

      assert_equal 2, X
      assert_equal 2, Y::A
      assert_equal 2, Z::A

      assert Y.object_id != y_object_id
      assert Z.object_id != z_object_id

      assert_equal 2, X
    end
  end

  test "reloading raises if the flag is not set" do
    e = assert_raises(Zeitwerk::ReloadingDisabledError) do
      loader = Zeitwerk::Loader.new
      loader.setup
      loader.reload
    end
    assert_equal "can't reload, please call loader.enable_reloading before setup", e.message
  end

  test "if reloading is disabled, autoloading metadata shrinks while autoloading (performance test)" do
    on_teardown do
      remove_const :X
      delete_loaded_feature "x.rb"

      remove_const :Y
      delete_loaded_feature "y.rb"
      delete_loaded_feature "y/a.rb"

      remove_const :Z
      delete_loaded_feature "z/a.rb"
    end

    files = [
      ["x.rb", "X = 1"],
      ["y.rb", "module Y; end"],
      ["y/a.rb", "Y::A = 1"],
      ["z/a.rb", "Z::A = 1"]
    ]
    with_files(files) do
      loader = new_loader(dirs: ".", enable_reloading: false)

      assert !loader.autoloads.empty?

      assert_equal 1, X
      assert_equal 1, Y::A
      assert_equal 1, Z::A

      assert loader.autoloads.empty?
      assert loader.to_unload.empty?
    end
  end

  test "if reloading is disabled, autoloading metadata shrinks while eager loading (performance test)" do
    on_teardown do
      remove_const :X
      delete_loaded_feature "x.rb"

      remove_const :Y
      delete_loaded_feature "y.rb"
      delete_loaded_feature "y/a.rb"

      remove_const :Z
      delete_loaded_feature "z/a.rb"
    end

    files = [
      ["x.rb", "X = 1"],
      ["y.rb", "module Y; end"],
      ["y/a.rb", "Y::A = 1"],
      ["z/a.rb", "Z::A = 1"]
    ]
    with_files(files) do
      loader = new_loader(dirs: ".", enable_reloading: false)

      assert !loader.autoloads.empty?
      assert !Zeitwerk::Registry.autoloads.empty?

      loader.eager_load

      assert loader.autoloads.empty?
      assert Zeitwerk::Registry.autoloads.empty?
      assert loader.to_unload.empty?
    end
  end
end
