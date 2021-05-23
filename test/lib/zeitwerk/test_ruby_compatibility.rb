require "test_helper"
require "pathname"

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

  # Zeitwerk sets autoloads using absolute paths, and the root dirs are joined
  # as given. Thanks to this property, we are able to identify the files we
  # manage in our decorated Kernel#require.
  test "absolute paths passed to require end up in $LOADED_FEATURES as is" do
    on_teardown { $LOADED_FEATURES.pop }

    files = [["real/real_x.rb", ""]]
    with_files(files) do
      FileUtils.ln_s("real", "sym")
      FileUtils.ln_s(File.expand_path("real/real_x.rb"), "sym/sym_x.rb")

      sym_x = File.expand_path("sym/sym_x.rb")
      assert require(sym_x)
      assert $LOADED_FEATURES.last == sym_x
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
    on_teardown do
      @tp.disable
      remove_const :C, from: self.class
    end

    called = false

    @tp = TracePoint.new(:class) { called = true }
    @tp.enable

    class C; end
    assert called
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
      assert !$LOADED_FEATURES.include?(File.expand_path("admin"))
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
  # autoloads linearly as scanning progresses.
  test "an autoload can be overridden" do
    on_teardown { remove_const :X }

    files = [
      ["x0/x.rb", "X = 0"],
      ["x1/x.rb", "X = 1"]
    ]
    with_files(files) do
      Object.autoload(:X, File.expand_path("x0/x.rb"))
      Object.autoload(:X, File.expand_path("x1/x.rb"))

      assert_equal 1, X
    end
  end

  # I believe Zeitwerk does not exploit this one now. Let's leave it here to
  # keep track of undocumented corner cases anyway.
  test "const_defined? is true for autoloads and does not load the file, if the file exists" do
    on_teardown { remove_const :X }

    files = [["x.rb", "$const_defined_does_not_trigger_autoload = false; X = true"]]
    with_files(files) do
      $const_defined_does_not_trigger_autoload = true
      Object.autoload(:X, File.expand_path("x.rb"))

      assert Object.const_defined?(:X, false)
      assert $const_defined_does_not_trigger_autoload
    end
  end

  # Unloading removes autoloads by calling remove_const. It is convenient that
  # remove_const does not execute the autoload because it would be surprising,
  # and slower, that those unused files got loaded precisely while unloading.
  test "remove_const does not trigger an autoload" do
    files = [["x.rb", "$remove_const_does_not_trigger_autoload = false; X = 1"]]
    with_files(files) do
      $remove_const_does_not_trigger_autoload = true
      Object.autoload(:X, File.expand_path("x.rb"))

      remove_const :X
      assert $remove_const_does_not_trigger_autoload
    end
  end

  # Zeitwerk uses this property when unloading to be able to differentiate when
  # it is removing and autoload, and when it is unloading an actual loaded
  # object.
  test "autoloading removes the autoload configuration in the parent" do
    on_teardown do
      remove_const :X
      delete_loaded_feature "x.rb"
    end

    files = [["x.rb", "X = true"]]
    with_files(files) do
      Object.autoload(:X, File.expand_path("x.rb"))

      assert Object.autoload?(:X)
      assert X
      assert !Object.autoload?(:X)
    end
  end

  # We use remove_const to delete autoload configurations while unloading.
  # Otherwise, the configured files or directories could become stale.
  test "autoload configuration can be deleted with remove_const" do
    files = [["x.rb", "X = true"]]
    with_files(files) do
      Object.autoload(:X, File.expand_path("x.rb"))

      assert Object.autoload?(:X)
      remove_const :X
      assert !Object.autoload?(:X)
    end
  end

  # Thanks to this the code that unloads can just blindly issue remove_const
  # calls without catching exceptions.
  test "remove_const works on constants with an autoload even if the file did not define them" do
    on_teardown do
      remove_const :Foo
      remove_const :NOT_FOO
      delete_loaded_feature "foo.rb"
    end

    files = [["foo.rb", "NOT_FOO = 1"]]
    with_files(files) do
      with_load_path(Dir.pwd) do
        begin
          Object.autoload(:Foo, "foo")
          assert_raises(NameError) { Foo }
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
       Object.autoload(:Foo, File.expand_path('foo.rb'))
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
    on_teardown do
      @tracer.disable
      remove_const :C, from: self.class
      remove_const :M, from: self.class
    end

    traced = []
    @tracer = TracePoint.trace(:class) do |tp|
      traced << tp.self
    end

    2.times do
      class C; end
      module M; end
    end

    assert_equal [C, M, C, M], traced
  end

  # Computing hash codes is costly and we want the tracer to be as efficient as
  # possible. The TP callback doesn't short-circuit anonymous classes/modules
  # because Class.new/Module.new do not trigger the :class event. We leverage
  # this property to save a nil? call.
  #
  # However, if that changes in future versions of Ruby, this test would tell us
  # and we could revisit the callback implementation.
  test "trace points on the :class events don't get called on Class.new and Module.new" do
    on_teardown { @tracer.disable }

    $tracer_for_anonymous_class_and_modules_called = false
    @tracer = TracePoint.trace(:class) { $tracer_for_anonymous_class_and_modules_called = true }

    Class.new
    Module.new

    assert !$tracer_for_anonymous_class_and_modules_called
  end

  # If the user issues a require call with a Pathname object for a path that is
  # autoloadable, we are able to autoload because $LOADED_FEATURES.last returns
  # the real path as a string and loader_for is able to find its loader. During
  # unloading, we find and delete strings in $LOADED_FEATURES too.
  #
  # This is not a hard requirement, we could work around it if $LOADED_FEATURES
  # stored pathnames. But the code is simpler if this property holds.
  test "required pathnames end up as strings in $LOADED_FEATURES" do
    on_teardown do
      remove_const :X
      $LOADED_FEATURES.pop
    end

    files = [["x.rb", "X = 1"]]
    with_files(files) do
      with_load_path(".") do
        assert_equal true, require(Pathname.new("x"))
        assert_equal 1, X
        assert_equal File.expand_path("x.rb"), $LOADED_FEATURES.last
      end
    end
  end
end
