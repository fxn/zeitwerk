require "test_helper"

class TestAutoloads < Minitest::Test
  def setup
    @autoloads = Zeitwerk::Autoloads.new
    @abspath   = "/foo.rb"
  end

  test "define defines an autoload" do
    on_teardown { remove_const :M }

    @autoloads.define(Object, :M, @abspath)
    assert_equal @abspath, Object.autoload?(:M)
  end

  test "abspath_for returns the configured path" do
    on_teardown { remove_const :M }

    @autoloads.define(Object, :M, @abspath)
    assert_equal @abspath, @autoloads.abspath_for(Object, :M)
    assert_nil @autoloads.abspath_for(Object, :N)
  end

  test "cref_for returns the configured cref" do
    on_teardown { remove_const :M }

    @autoloads.define(Object, :M, @abspath)
    assert_equal [Object, :M], @autoloads.cref_for(@abspath)
    assert_nil @autoloads.cref_for("/bar.rb")
  end

  test "each iterates over the autoloads" do
    on_teardown { remove_const :M }

    @autoloads.define(Object, :M, @abspath)
    @autoloads.each do |(parent, cname), abspath|
      assert_equal @abspath, abspath
      assert_equal Object, parent
      assert_equal :M, cname
    end
  end

  test "delete maintains the two internal collections" do
    on_teardown { remove_const :M }

    @autoloads.define(Object, :M, @abspath)
    @autoloads.delete(@abspath)
    assert @autoloads.empty?
  end

  test "a new instance is empty" do
    assert @autoloads.empty?
  end

  test "an instance with definitions is not empty" do
    on_teardown { remove_const :M }

    @autoloads.define(Object, :M, @abspath)
    assert !@autoloads.empty?
  end

  test "a cleared instance is empty" do
    on_teardown { remove_const :M }

    @autoloads.define(Object, :M, @abspath)
    @autoloads.clear
    assert @autoloads.empty?
  end
end
