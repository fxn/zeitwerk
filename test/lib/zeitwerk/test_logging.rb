# frozen_string_literal: true

require "test_helper"

class TestLogging < LoaderTest
  def setup
    super
    loader.logger = method(:print)
  end

  def teardown
    Zeitwerk::Loader.default_logger = nil
    loader.logger = nil
    super
  end

  def tagged_message(message)
    "Zeitwerk@#{loader.tag}: #{message}"
  end

  def assert_logged(expected)
    case expected
    when String
      assert_output(tagged_message(expected)) { yield }
    when Regexp
      assert_output(/#{tagged_message(expected)}/) { yield }
    end
  end

  test "log! just prints to $stdout" do
    loader.logger = nil # make sure we are setting something
    loader.log!
    message = "test log!"
    assert_logged(/#{message}\n/) { loader.send(:log, message) }
  end

  test "accepts objects that respond to :call" do
    logger = Object.new
    def logger.call(message)
      print message
    end

    loader.logger = logger

    message = "test message :call"
    assert_logged(message) { loader.send(:log, message) }
  end

  test "accepts objects that respond to :debug" do
    logger = Object.new
    def logger.debug(message)
      print message
    end

    loader.logger = logger

    message = "test message :debug"
    assert_logged(message) { loader.send(:log, message) }
  end

  test "new loaders get assigned the default global logger" do
    assert_nil Zeitwerk::Loader.new.logger

    Zeitwerk::Loader.default_logger = Object.new
    assert_same Zeitwerk::Loader.default_logger, Zeitwerk::Loader.new.logger
  end

  test "logs loaded files" do
    files = [["x.rb", "X = true"]]
    with_files(files) do
      with_load_path(".") do
        assert_logged(/constant X loaded from file #{File.expand_path("x.rb")}/) do
          loader.push_dir(".")
          loader.setup

          assert X
        end
      end
    end
  end

  test "logs required managed files" do
    files = [["x.rb", "X = true"]]
    with_files(files) do
      with_load_path(".") do
        assert_logged(/constant X loaded from file #{File.expand_path("x.rb")}/) do
          loader.push_dir(".")
          loader.setup

          assert require "x"
        end
      end
    end
  end

  test "logs autovivified modules" do
    files = [["admin/user.rb", "class Admin::User; end"]]
    with_files(files) do
      with_load_path(".") do
        assert_logged(/module Admin autovivified from directory #{File.expand_path("admin")}/) do
          loader.push_dir(".")
          loader.setup

          assert Admin
        end
      end
    end
  end

  test "logs implicit to explicit promotions" do
    # We use two root directories to make sure the loader visits the implicit
    # a/m first, and the explicit b/m.rb after it.
    files = [
      ["a/m/x.rb", "M::X = true"],
      ["b/m.rb", "module M; end"]
    ]
    with_files(files) do
      loader.push_dir("a")
      loader.push_dir("b")
      assert_logged(/earlier autoload for M discarded, it is actually an explicit namespace defined in #{File.expand_path("b/m.rb")}/) do
        loader.setup
      end
    end
  end

  test "logs autoload configured for files" do
    files = [["x.rb", "X = true"]]
    with_files(files) do
      assert_logged("autoload set for X, to be loaded from #{File.expand_path("x.rb")}") do
        loader.push_dir(".")
        loader.setup
      end
    end
  end

  test "logs autoload configured for directories" do
    files = [["admin/user.rb", "class Admin::User; end"]]
    with_files(files) do
      assert_logged("autoload set for Admin, to be autovivified from #{File.expand_path("admin")}") do
        loader.push_dir(".")
        loader.setup
      end
    end
  end

  test "logs unloads for autoloads" do
    files = [["x.rb", "X = true"]]
    with_files(files) do
      assert_logged(/autoload for X removed/) do
        loader.push_dir(".")
        loader.setup
        loader.reload
      end
    end
  end

  test "logs unloads for loaded objects" do
    files = [["x.rb", "X = true"]]
    with_files(files) do
      assert_logged(/X unloaded/) do
        loader.push_dir(".")
        loader.setup
        assert X
        loader.reload
      end
    end
  end

  test "logs files shadowed by autoloads" do
    files = [
      ["a/foo.rb", "Foo = :a"],
      ["b/foo.rb", "Foo = :b"]
    ]
    with_files(files) do
      new_loader(dirs: "a")
      assert_logged(%r(file .*?/b/foo\.rb is ignored because .*?/a/foo\.rb has precedence)) do
        loader.push_dir("b")
        loader.setup
      end
    end
  end

  test "logs when eager loading starts" do
    files = [["x.rb", "X = true"]]
    with_files(files) do
      assert_logged(/eager load start/) do
        loader.eager_load
      end
    end
  end

  test "logs when eager loading ends" do
    files = [["x.rb", "X = true"]]
    with_files(files) do
      assert_logged(/eager load end/) do
        loader.eager_load
      end
    end
  end

  test "eager loading skips files that would map to already loaded constants" do
    on_teardown { remove_const :X }

    ::X = 1
    files = [["x.rb", "X = 1"]]
    with_files(files) do
      loader.push_dir(".")
      assert_logged(%r(file .*?/x\.rb is ignored because X is already defined)) do
        loader.setup
      end
    end
  end
end
