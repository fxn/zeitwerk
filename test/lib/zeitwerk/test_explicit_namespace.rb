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

  test "similar name in a namespace and it's parent namespace, with the child name being reference first" do
    files = [
      ["app/models/pricing.rb", "class Pricing; X = 1; end"],
      ["app/models/hotel.rb", "class Hotel; X = 1; end"],
      ["app/models/hotel/pricing.rb", "class Hotel::Pricing; X = 2; end"],
    ]
    # Load order is very important here, if `::Pricing` is referenced before `::Hotel::Pricing`, the bug won't manifest
    with_setup(files, dirs: %w(app/models)) do
      assert_kind_of Class, Hotel
      assert_kind_of Class, Hotel::Pricing
      assert_kind_of Class, Pricing
      assert_equal 1, Pricing::X
      assert_equal 2, Hotel::Pricing::X
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
end
