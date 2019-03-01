require "test_helper"

class TestRubyCompatibility < LoaderTest
  # We decorate Kernel#require in lib/zeitwerk/kernel.rb to be able to log
  # autoloads and to record what has been autoloaded so far.
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

  # Zeitwerk has to be called as soon as explicit namespaces are defined, to be
  # able to configure autoloads for their children before the class or module
  # body is interpreted. If explicit namespaces are found, Zeitwerk sets a trace
  # point on the :class event with that purpose.
  #
  # This is key because the body could reference child constants at the
  # top-level, mixins are a common use case.
  test "TracePoint emits :class events" do
    called = false

    tp = TracePoint.new(:class) { called = true }
    tp.enable

    class C; end
    assert called

    tp.disable
    self.class.send(:remove_const, :C)
  end

  # We configure autoloads on directories to autovivify modules on demand, and
  # lazily descend to set autoloads for their children. This is more efficient,
  # specially for large code bases.
  test "you can set autoloads on directories" do
    files = ["admin/users_controller.rb", "class UsersController; end"]
    with_setup(files) do
      assert_equal "#{Dir.pwd}/admin", Object.autoload?(:Admin)
    end
  end

  # While unloading constants we leverage this property to avoid lookups in
  # $LOADED_FEATURES for strings that we know are not going to be there.
  test "directories are not included in $LOADED_FEATURES" do
    with_files([]) do
      FileUtils.mkdir("admin")
      loader.push_dir(".")
      loader.setup

      assert Admin
      assert !$LOADED_FEATURES.include?(File.realpath("admin"))
    end
  end

  # We exploit this one to simplify the detection of explicit namespaces.
  #
  # Let's suppose `Admin` is an explicit namespace and scanning finds first a
  # directory called `admin`. We set at that point an autoload for `Admin` and
  # that will require that directory. If later on, scanning finds `admin.rb`, we
  # just set the autoload again, and change the target file.
  #
  # This way, we do not need to keep state or do an a posteriori pass, can set
  # autoloads lineraly as scanning progresses.
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

  # I believe Zeitwerk does not exploit this one now. Let's leave it here to
  # keep track of undocumented corner cases anyway.
  test "const_defined? is true for autoloads and does not load the file, if the file exists" do
    files = [["x.rb", "$const_defined_does_not_trigger_autoload = false; X = true"]]
    with_files(files) do
      $const_defined_does_not_trigger_autoload = true
      Object.autoload(:X, File.expand_path("x.rb"))

      assert Object.const_defined?(:X, false)
      assert $const_defined_does_not_trigger_autoload
      assert_nil Object.send(:remove_const, :X)
    end
  end

  # Unloading removes autoloads by calling remove_const. It is convenient that
  # remove_const does not execute the autoload because it would be surprising,
  # and slower, those unused files got loaded precisely while unloading.
  test "remove_const does not trigger an autoload" do
    files = [["x.rb", "$remove_const_does_not_trigger_autoload = false; X = 1"]]
    with_files(files) do
      $remove_const_does_not_trigger_autoload = true
      Object.autoload(:X, File.expand_path("x.rb"))

      Object.send(:remove_const, :X)
      assert $remove_const_does_not_trigger_autoload
    end
  end

  # Zeitwerk uses this property when unloading to be able to differentiate when
  # it is removing and autoload, and when it is unloading an actual loaded
  # object.
  test "autoloading removes the autoload configuration in the parent" do
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

  # We use remove_const to delete autoload configurations while unloading.
  # Otherwise, the configured files or directories could become stale.
  test "autoload configuration can be deleted with remove_const" do
    files = [["x.rb", "X = true"]]
    with_files(files) do
      Object.autoload(:X, File.expand_path("x.rb"))

      assert Object.autoload?(:X)
      Object.send(:remove_const, :X)
      assert !Object.autoload?(:X)
    end
  end

  # Thanks to this the code that unloads can just blindly issue remove_const
  # calls without catching exceptions.
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

  # This edge case justifies the need for the inceptions collection in the
  # registry.
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

  # Same as above, adding some depth.
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

  # This is why we issue a lazy_subdirs.delete call in the tracer block, to
  # ignore events triggered by reopenings.
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
