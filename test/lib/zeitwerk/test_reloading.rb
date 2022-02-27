# frozen_string_literal: true

require "test_helper"
require "fileutils"

class TestReloading < LoaderTest
  module Namespace; end

  def silence_exceptions_in_threads
    original_report_on_exception = Thread.report_on_exception
    Thread.report_on_exception = false
    yield
  ensure
    Thread.report_on_exception = original_report_on_exception
  end

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

  test "reloading works if the flag is set (Object)" do
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

  test "reloading works if the flag is set (Namespace)" do
    files = [
      ["x.rb", "#{Namespace}::X = 1"],         # top-level
      ["y.rb", "module #{Namespace}::Y; end"], # explicit namespace
      ["y/a.rb", "#{Namespace}::Y::A = 1"],
      ["z/a.rb", "#{Namespace}::Z::A = 1"]     # implicit namespace
    ]
    with_setup(files, namespace: Namespace) do
      assert_equal 1, Namespace::X
      assert_equal 1, Namespace::Y::A
      assert_equal 1, Namespace::Z::A

      ns_object_id = Namespace.object_id
      y_object_id  = Namespace::Y.object_id
      z_object_id  = Namespace::Z.object_id

      File.write("x.rb", "#{Namespace}::X = 2")
      File.write("y/a.rb", "#{Namespace}::Y::A = 2")
      File.write("z/a.rb", "#{Namespace}::Z::A = 2")

      loader.reload

      assert_equal 2, Namespace::X
      assert_equal 2, Namespace::Y::A
      assert_equal 2, Namespace::Z::A

      assert Namespace.object_id    == ns_object_id
      assert Namespace::Y.object_id != y_object_id
      assert Namespace::Z.object_id != z_object_id

      assert_equal 2, Namespace::X
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

  test "reloading supports deleted root directories" do
    files = [["a/x.rb", "X = 1"], ["b/y.rb", "Y = 1"]]
    with_setup(files, dirs: %w(a b)) do
      assert X
      assert Y

      FileUtils.rm_rf("b")
      loader.reload

      assert X
    end
  end

  test "you can eager load again after reloading" do
    $test_eager_load_after_reload = 0
    files = [["x.rb", "$test_eager_load_after_reload += 1; X = 1"]]
    with_setup(files) do
      loader.eager_load
      assert_equal 1, $test_eager_load_after_reload

      loader.reload

      loader.eager_load
      assert_equal 2, $test_eager_load_after_reload
    end
  end

  test "reload recovers from name errors (w/o on_unload callbacks)" do
    on_teardown { remove_const :Y }

    files = [["x.rb", "Y = :typo"]]
    with_setup(files) do
      assert_raises(Zeitwerk::NameError) { X }

      loader.reload
      File.write("x.rb", "X = true")

      assert X
    end
  end

  test "reload recovers from name errors (w/ on_unload callbacks)" do
    on_teardown { remove_const :Y }

    files = [["x.rb", "Y = :typo"]]
    with_setup(files) do
      loader.on_unload {}
      assert_raises(Zeitwerk::NameError) { X }

      loader.reload
      File.write("x.rb", "X = true")

      assert X
    end
  end

  test "reloading? returns false before and after reloading" do
    with_setup([]) do
      assert !loader.reloading?

      loader.reload

      assert !loader.reloading?
    end
  end

  test "reloading? is true during reloading" do
    $reloading_flag_during_reloading = false
    with_setup([]) do
      def loader.unload
        $reloading_flag_during_reloading = reloading?
        super
      end
      loader.reload

      assert $reloading_flag_during_reloading
    end
  end

  test "concurrent reloads are detected" do
    $test_concurrent_reloads_queue = Queue.new
    with_setup([]) do
      def loader.unload
        $test_concurrent_reloads_queue << true
        sleep 0.5
        super
      end

      silence_exceptions_in_threads do
        t1 = Thread.new { loader.reload }
        t2 = Thread.new { $test_concurrent_reloads_queue.pop(); loader.reload }

        assert_raises(Zeitwerk::UnsynchronizedReloadError) { t2.join }
        t1.join
      end
    end
  end

  test "autoloads during reloading are detected (not a namespace)" do
    on_teardown { remove_const :X }

    $test_concurrent_reloads_queue = Queue.new
    with_setup([["x.rb", "X = 1"]]) do
      def loader.unload
        $test_concurrent_reloads_queue << true
        sleep 0.5
        super
      end

      silence_exceptions_in_threads do
        t1 = Thread.new { loader.reload }
        t2 = Thread.new { $test_concurrent_reloads_queue.pop(); X }

        assert_raises(Zeitwerk::UnsynchronizedReloadError) { t2.join }
        t1.join
      end
    end
  end

  test "autoloads during reloading are detected (implicit namespace)" do
    on_teardown { remove_const :X }

    $test_concurrent_reloads_queue = Queue.new
    with_setup([["x/y.rb", "X::Y = 1"]]) do
      def loader.unload
        $test_concurrent_reloads_queue << true
        sleep 0.5
        super
      end

      silence_exceptions_in_threads do
        t1 = Thread.new { loader.reload }
        t2 = Thread.new { $test_concurrent_reloads_queue.pop(); X }

        assert_raises(Zeitwerk::UnsynchronizedReloadError) { t2.join }
        t1.join
      end
    end
  end

  test "autoloads during reloading are detected (explicit namespace)" do
    on_teardown { remove_const :X }

    $test_concurrent_reloads_queue = Queue.new
    with_setup([["x.rb", "module X; end"], ["x/y.rb", "X::Y = 1"]]) do
      def loader.unload
        $test_concurrent_reloads_queue << true
        sleep 0.5
        super
      end

      silence_exceptions_in_threads do
        t1 = Thread.new { loader.reload }
        t2 = Thread.new { $test_concurrent_reloads_queue.pop(); X }

        assert_raises(Zeitwerk::UnsynchronizedReloadError) { t2.join }
        t1.join
      end
    end
  end
end
