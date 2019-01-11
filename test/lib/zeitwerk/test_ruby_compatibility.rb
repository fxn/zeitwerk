require "test_helper"

class TestRubyCompatibility < LoaderTest
  test "autoload calls Kernel#require" do
    files = [["x.rb", "X = true"]]
    with_files(files) do
      loader.push_dir(".")
      loader.setup

      $trc_require_has_been_called = false
      $trc_autoload_path = File.expand_path("x.rb")

      begin
        Kernel.module_eval do
          alias_method :trc_original_require, :require
          def require(path)
            $trc_require_has_been_called = true if path == $trc_autoload_path
            trc_original_require(path)
          end
        end

        assert X
        assert $trc_require_has_been_called
      ensure
        Kernel.module_eval do
          remove_method :require
          define_method :require, instance_method(:trc_original_require)
          remove_method :trc_original_require
        end
      end
    end
  end

  test "directories are not included in $LOADED_FEATURES" do
    with_files([]) do
      FileUtils.mkdir("admin")
      loader.push_dir(".")
      loader.setup

      assert Admin
      assert !$LOADED_FEATURES.include?(File.realpath("admin"))
    end
  end

  test "an autoload can be overridden" do
    files = [
      ["x0/x.rb", "X = 0"],
      ["x1/x.rb", "X = 1"]
    ]
    with_files(files) do
      Object.autoload(:X, File.expand_path("x0/x.rb"))
      Object.autoload(:X, File.expand_path("x1/x.rb"))

      assert_equal 1, X
    end
    Object.send(:remove_const, :X)
  end

  test "const_defined? is true for autoloads and does not load the file" do
    files = [["x.rb", "$const_defined_does_not_trigger_autoload = false; X = true"]]
    with_files(files) do
      $const_defined_does_not_trigger_autoload = true
      Object.autoload(:X, File.expand_path("x.rb"))

      assert Object.const_defined?(:X, false)
      assert $const_defined_does_not_trigger_autoload
      assert_nil Object.send(:remove_const, :X)
    end
  end

  test "remove_const does not trigger an autoload" do
    files = [["x.rb", "$remove_const_does_not_trigger_autoload = false; X = 1"]]
    with_files(files) do
      $remove_const_does_not_trigger_autoload = true
      Object.autoload(:X, File.expand_path("x.rb"))

      Object.send(:remove_const, :X)
      assert $remove_const_does_not_trigger_autoload
    end
  end

  test "autoloads remove the autoload configuration in the parent" do
    files = [["x.rb", "X = true"]]
    with_files(files) do
      Object.autoload(:X, File.expand_path("x.rb"))

      assert Object.autoload?(:X)
      assert X
      assert !Object.autoload?(:X)
      assert Object.send(:remove_const, :X)
      assert delete_loaded_feature("x.rb")
    end
  end

  test "autoload configuration can be deleted with remove_const" do
    files = [["x.rb", "X = true"]]
    with_files(files) do
      Object.autoload(:X, File.expand_path("x.rb"))

      assert Object.autoload?(:X)
      Object.send(:remove_const, :X)
      assert !Object.autoload?(:X)
    end
  end

  test "remove_const works on constants with an autoload even if the file did not define them" do
    files = [["foo.rb", "NOT_FOO = 1"]]
    with_files(files) do
      with_load_path(Dir.pwd) do
        begin
          Object.autoload(:Foo, "foo")
          assert_raises(NameError) { Foo }
          Object.send(:remove_const, :Foo)
          Object.send(:remove_const, :NOT_FOO)
          delete_loaded_feature("foo.rb")
        end
      end
    end
  end

  test "an autoload on yourself is ignored" do
    files = [["foo.rb", <<-EOS]]
      Object.autoload(:Foo, __FILE__)
      $trc_inception = !Object.autoload?(:Foo)
      Foo = 1
    EOS
    with_files(files) do
      loader.push_dir(".")
      loader.setup

      with_load_path do
        $trc_inception = false
        require "foo"
      end

      assert $trc_inception
    end
  end

  test "an autoload on a file being required at some point up in the call chain is also ignored" do
    files = [
      ["foo.rb", <<-EOS],
        require 'bar'
        Foo = 1
      EOS
     ["bar.rb", <<-EOS]
       Bar = true
       Object.autoload(:Foo, File.realpath('foo.rb'))
       $trc_inception = !Object.autoload?(:Foo)
     EOS
    ]
    with_files(files) do
      loader.push_dir(".")
      loader.setup

      with_load_path do
        $trc_inception = false
        require "foo"
      end

      assert $trc_inception
    end
  end

  # This why we issue a lazy_subdirs.delete call in the tracer block.
  test "tracing :class calls you back on creation and on reopening" do
    traced = []
    tracer = TracePoint.trace(:class) do |tp|
      traced << tp.self
    end

    2.times do
      class C; end
      module M; end
    end

    assert_equal [C, M, C, M], traced

    tracer.disable
    self.class.send(:remove_const, :C)
    self.class.send(:remove_const, :M)
  end
end
