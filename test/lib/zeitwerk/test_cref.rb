# frozen_string_literal: true

require "test_helper"

class TestCref < LoaderTest
  def klass
    self.class
  end

  def new_cref(mod = klass, cname = :Foo)
    Zeitwerk::Cref.new(mod, :Foo)
  end

  test "#cname" do
    assert_equal :Foo, new_cref.cname
  end

  test "#path for Object" do
    assert_equal "Foo", new_cref(Object).path
  end

  test "#path for another namespace" do
    assert_equal "#{self.class}::Foo", new_cref.path
  end

  test "#to_s is #path" do
    assert_equal Zeitwerk::Cref.instance_method(:to_s), Zeitwerk::Cref.instance_method(:path)
  end

  test "#autoload?" do
    on_teardown { remove_const :Foo, from: klass }

    klass.autoload(:Foo, "/foo")
    assert_equal "/foo", new_cref.autoload?
  end

  test "#autoload" do
    on_teardown { remove_const :Foo, from: klass }

    new_cref.autoload("/foo")
    assert_equal "/foo", klass.autoload?(:Foo)
  end

  test "#defined? finds a constant defined in mod" do
    on_teardown { remove_const :Foo, from: klass }

    klass.const_set(:Foo, 1)
    assert new_cref.defined?
  end

  test "#defined? ignores the ancestors" do
    cname = :TMP_DIR
    assert klass.superclass.const_defined?(cname) # precondition
    assert !new_cref(klass, cname).defined?
  end

  test "#set" do
    on_teardown { remove_const :Foo, from: klass }

    assert_equal 1, new_cref.set(1)
    assert_equal 1, klass::Foo
  end

  test "#get" do
    on_teardown { remove_const :Foo, from: klass }

    klass.const_set(:Foo, 1)
    assert_equal 1, new_cref.get
  end

  test "#get with unknown cname" do
    assert_raises(NameError) { new_cref.get }
  end

  test "#remove" do
    cref = new_cref

    cref.set(1)
    assert cref.defined? # precondition

    cref.remove
    assert !cref.defined?
  end

  test "#remove with unknown cname" do
    assert_raises(NameError) { new_cref.remove }
  end
end
