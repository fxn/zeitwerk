require "test_helper"

# As of this writing, a tracer on the :class event does not seem to have any
# performance penalty in an ordinary code base. But I prefer to precisely
# control that we use a tracer only if needed in case this issue
#
#     https://bugs.ruby-lang.org/issues/14104
#
# goes forward.
class TestTracer < LoaderTest
  test "the tracer of a new instance is disabled" do
    assert !Zeitwerk::Loader.new.tracer.enabled?
  end

  test "simple autoloading does not enable the tracer" do
    files = [["x.rb", "X = true"]]
    with_setup(files) do
      assert X
      assert !loader.tracer.enabled?
    end
  end

  test "autovivification does not enable the tracer" do
    files = [["foo/bar.rb", "module Foo::Bar; end"]]
    with_setup(files) do
      assert Foo::Bar
      assert !loader.tracer.enabled?
    end
  end

  test "explicit namespaces do enable the tracer" do
    files = [
      ["hotel.rb", "class Hotel; end"],
      ["hotel/pricing.rb", "class Hotel::Pricing; end"]
    ]
    with_setup(files) do
      assert Hotel::Pricing
      assert loader.tracer.enabled?
    end
  end

  test "reload disables the tracer" do
    loader.tracer.enable
    loader.reload
    assert !loader.tracer.enabled?
  end

  test "eager loading disables the tracer" do
    loader.tracer.enable
    loader.eager_load
    assert !loader.tracer.enabled?
  end
end
