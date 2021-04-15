require "test_helper"

class TestExceptions < LoaderTest
  test "raises NameError if the expected constant is not defined" do
    files = [["typo.rb", "TyPo = 1"]]
    with_setup(files) do
      typo_rb = File.expand_path("typo.rb")
      error = assert_raises(Zeitwerk::NameError) { Typo }
      assert_equal "expected file #{typo_rb} to define constant Typo, but didn't", error.message
      assert_equal :Typo, error.name
    end
  end

  test "eager loading raises NameError if files do not define the expected constants" do
    on_teardown do
      remove_const :X # should be unnecessary, but $LOADED_FEATURES.reject! redefines it
      remove_const :Y
    end

    files = [["x.rb", "Y = 1"]]
    with_setup(files) do
      x_rb = File.expand_path("x.rb")
      error = assert_raises(Zeitwerk::NameError) { loader.eager_load }
      assert_equal "expected file #{x_rb} to define constant X, but didn't", error.message
      assert_equal :X, error.name
    end
  end

  test "eager loading raises NameError if a namespace has not been loaded yet" do
    on_teardown do
      remove_const :CLI
      delete_loaded_feature 'cli/x.rb'
    end

    files = [["cli/x.rb", "module CLI; X = 1; end"]]
    with_setup(files) do
      cli_x_rb = File.expand_path("cli/x.rb")
      error = assert_raises(Zeitwerk::NameError) { loader.eager_load }
      assert_equal "expected file #{cli_x_rb} to define constant Cli::X, but didn't", error.message
      assert_equal :X, error.name
    end
  end

  test "raises if the file does" do
    files = [["raises.rb", "Raises = 1; raise 'foo'"]]
    with_setup(files, rm: false) do
      assert_raises(RuntimeError, "foo") { Raises }
    end
  end

  test "raises Zeitwerk::NameError if the inflector returns an invalid constant name for a file" do
    files = [["foo-bar.rb", "FooBar = 1"]]
    error = assert_raises Zeitwerk::NameError do
      with_setup(files) {}
    end
    assert_equal :"Foo-bar", error.name
    assert_includes error.message, "wrong constant name Foo-bar"
    assert_includes error.message, "Tell Zeitwerk to ignore this particular file."
  end

  test "raises Zeitwerk::NameError if the inflector returns an invalid constant name for a directory" do
    files = [["foo-bar/baz.rb", "FooBar::Baz = 1"]]
    error = assert_raises Zeitwerk::NameError do
      with_setup(files) {}
    end
    assert_equal :"Foo-bar", error.name
    assert_includes error.message, "wrong constant name Foo-bar"
    assert_includes error.message, "Tell Zeitwerk to ignore this particular directory."
  end
end
