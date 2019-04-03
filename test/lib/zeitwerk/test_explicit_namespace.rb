require "test_helper"

class TestExplicitNamespace < LoaderTest
  test "explicit namespaces are loaded correctly" do
    files = [
      ["app/models/hotel.rb", "class Hotel; X = 1; end"],
      ["app/models/hotel/pricing.rb", "class Hotel::Pricing; end"]
    ]
    with_setup(files, dirs: "app/models") do
      assert_kind_of Class, Hotel
      assert Hotel::X
      assert Hotel::Pricing
    end
  end

  test "explicit namespaces managed by different instances" do
    files = [
      ["a/m.rb", "module M; end"], ["a/m/n.rb", "M::N = true"],
      ["b/x.rb", "module X; end"], ["b/x/y.rb", "X::Y = true"],
    ]
    with_files(files) do
      la = Zeitwerk::Loader.new
      la.push_dir("a")
      la.setup

      lb = Zeitwerk::Loader.new
      lb.push_dir("b")
      lb.setup

      assert M::N
      assert X::Y
    end
  end

  test "autoloads are set correctly, even if there are autoloads for the same cname in the superclass" do
    files = [
      ["a.rb", "class A; end"],
      ["a/x.rb", "A::X = :A"],
      ["b.rb", "class B < A; end"],
      ["b/x.rb", "B::X = :B"]
    ]
    with_setup(files) do
      assert_kind_of Class, A
      assert_kind_of Class, B
      assert_equal :B, B::X
    end
  end

  test "autoloads are set correctly, even if there are autoloads for the same cname in other ancestors" do
    files = [
      ["m/x.rb", "M::X = :M"],
      ["a.rb", "class A; include M; end"],
      ["b.rb", "class B < A; end"],
      ["b/x.rb", "B::X = :B"]
    ]
    with_setup(files) do
      assert_kind_of Class, A
      assert_kind_of Class, B
      assert_equal :B, B::X
    end
  end

  test "the autoload path is re-used by Kernel#require" do
    files = [
      ["app/models/hotel.rb", "class Hotel; end"],
    ]
    with_setup(files, dirs: "app/models") do
      abspath = loader.autoloads.keys.first

      assert_equal File.expand_path("app/models/hotel.rb"), abspath

      assert_kind_of Class, Hotel

      assert_equal abspath, $LOADED_FEATURES.last
      assert_same abspath, $LOADED_FEATURES.last
    end
  end

  test "the various cpaths hold onto by the loader are deduplicated" do
    files = [
      ["app/models/hotel.rb", "class Hotel; end"],
    ]
    with_setup(files, dirs: "app/models") do
      hotel_cname = Zeitwerk.intern_cname!('Hotel')
      assert_equal 'Hotel', hotel_cname

      autoload_cpath = loader.autoloads.values.first.last
      assert_equal hotel_cname, autoload_cpath
      assert_same hotel_cname, autoload_cpath

      assert_kind_of Class, Hotel

      loaded_cpath = loader.loaded_cpaths.first
      assert_equal hotel_cname, loaded_cpath
      assert_same hotel_cname, loaded_cpath
    end
  end

  # As of this writing, a tracer on the :class event does not seem to have any
  # performance penalty in an ordinary code base. But I prefer to precisely
  # control that we use a tracer only if needed in case this issue
  #
  #     https://bugs.ruby-lang.org/issues/14104
  #
  # goes forward.
  def tracer
    Zeitwerk::ExplicitNamespace.tracer
  end

  test "the tracer starts disabled" do
    assert !tracer.enabled?
  end

  test "simple autoloading does not enable the tracer" do
    files = [["x.rb", "X = true"]]
    with_setup(files) do
      assert !tracer.enabled?
      assert X
      assert !tracer.enabled?
    end
  end

  test "autovivification does not enable the tracer" do
    files = [["foo/bar.rb", "module Foo::Bar; end"]]
    with_setup(files) do
      assert !tracer.enabled?
      assert Foo::Bar
      assert !tracer.enabled?
    end
  end

  test "explicit namespaces enable the tracer until loaded" do
    files = [
      ["hotel.rb", "class Hotel; end"],
      ["hotel/pricing.rb", "class Hotel::Pricing; end"]
    ]
    with_setup(files) do
      assert tracer.enabled?
      assert Hotel
      assert !tracer.enabled?
      assert Hotel::Pricing
      assert !tracer.enabled?
    end
  end

  test "the tracer is enabled until everything is loaded" do
    files = [
      ["a/m.rb", "module M; end"], ["a/m/n.rb", "M::N = true"],
      ["b/x.rb", "module X; end"], ["b/x/y.rb", "X::Y = true"],
    ]
    with_files(files) do
      la = Zeitwerk::Loader.new
      la.push_dir("a")
      la.setup
      assert tracer.enabled?

      lb = Zeitwerk::Loader.new
      lb.push_dir("b")
      lb.setup
      assert tracer.enabled?

      assert M
      assert tracer.enabled?

      assert X
      assert !tracer.enabled?
    end
  end

  # This is a regression test.
  test "the tracer handles singleton classes" do
    files = [
      ["hotel.rb", <<-EOS],
        class Hotel
          class << self
            def x
              1
            end
          end
        end
      EOS
      ["hotel/pricing.rb", "class Hotel::Pricing; end"],
      ["car.rb", "class Car; end"],
      ["car/pricing.rb", "class Car::Pricing; end"],
    ]
    with_setup(files) do
      assert tracer.enabled?
      assert_equal 1, Hotel.x
      assert tracer.enabled?
    end
  end
end
