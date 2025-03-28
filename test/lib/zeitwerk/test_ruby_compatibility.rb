# frozen_string_literal: true

require "test_helper"
require "pathname"

class TestRubyCompatibility < LoaderTest
  # We decorate Kernel#require in lib/zeitwerk/kernel.rb be able to trigger
  # callbacks, autovivify implicit namespaces, keep track of what has been
  # autoloaded, and more.
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

  # Once a managed file is autoloaded, Zeitwerk verifies the expected constant
  # has been defined and raises Zeitwerk::NameError if not. This happens within
  # the context of the require call and is correct because an autoload does not
  # define the constant by itself, it has to be a side-effect.
  test "within a file triggered by an autoload, the constant being autoloaded is not defined" do
    files = [["x.rb", "$const_defined_for_X = Object.const_defined?(:X); X = 1"]]
    with_setup(files) do
      $const_defined_for_X = Object.const_defined?(:X)
      assert $const_defined_for_X
      assert X
      assert !$const_defined_for_X
    end
  end

  # Zeitwerk sets autoloads using absolute paths and string concatenation with
  # the root directories. These paths could contain symlinks, but we can still
  # identify managed files in our decorated Kernel#require because Ruby stores
  # the paths as they are in $LOADED_FEATURES with no symlink resolution.
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
    with_files(["admin/users_controller.rb"]) do
      loader.push_dir(".")
      loader.setup

      assert Admin
      assert !$LOADED_FEATURES.include?(File.expand_path("admin"))
    end
  end

  # We exploit this one to simplify the detection of explicit namespaces.
  #
  # Let's suppose `Admin` is an explicit namespace and scanning finds first a
  # directory called `admin`. We set at that point an autoload for `Admin` that
  # will require that directory. If later on, scanning finds `admin.rb`, we just
  # set the autoload again, and change the target file.
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

  # In some spots like shadowed files detection we need to check if constants
  # are already defined in the parent class or module. In order to do this and
  # still be lazy, we rely on this property of const_defined?
  #
  # This also matters for autoloads already set by 3rd-party code, for example
  # in reopened namespaces. Zeitwerk won't override them, but thanks to this
  # characteristic of const_defined? if won't trigger them either.
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

  # We delegate constant name validation to Module#const_defined?.
  test "const_defined? raises NameError for invalid cnames" do
    error = assert_raises ::NameError do
      Module.new.const_defined?("Foo-Bar", false)
    end

    assert_includes error.message, "wrong constant name Foo-Bar"
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

  # Loaders use this property when unloading to be able tell if the autoloads
  # that are pending according to their state are still pending. While things
  # are autoloaded that collection is maintained, this should not be needed. But
  # client code doing unsupported stuff like using require_relative on managed
  # files could introduce weird state we need to be defensive about.
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

  # If the user issues a require call with a Pathname object for a path that is
  # autoloadable, we are still able to intercept it because $LOADED_FEATURES
  # stores it as a string and loader_for is able to find its loader. During
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

  # This allows Zeitwerk to be thread-safe on regular file autoloads. Module
  # autovivification is custom, has its own test.
  test "autoloads and constant references are synchronized" do
    skip 'https://github.com/oracle/truffleruby/issues/2431' if RUBY_ENGINE == 'truffleruby'

    $ensure_M_is_autoloaded_by_the_thread = Queue.new

    files = [["m.rb", <<-EOS]]
      $ensure_M_is_autoloaded_by_the_thread.pop()

      module M
        sleep 1

        def self.works?
          true
        end
      end
    EOS
    with_setup(files) do
      t = Thread.new do
        $ensure_M_is_autoloaded_by_the_thread << true
        M
      end

      sleep 0.5 # Let the thread hit the sleep in m.rb.
      assert M.works? # this should block until the thread has finished autoloading

      t.join
    end
  end
end
