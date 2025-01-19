# frozen_string_literal: true

require "test_helper"

class TestCref < LoaderTest
  def klass
    self.class
  end

  def new_cref(mod = klass, cname = :Foo)
    Zeitwerk::Cref.new(mod, cname)
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

  test "#path for another namespace that overrides #name" do
    on_teardown do
      remove_const :M
      remove_const :C
    end

    ::M = new_overridden_module
    cref = new_cref(M)
    assert_equal "M::Foo", cref.path

    ::C = new_overridden_class
    cref = new_cref(C)
    assert_equal "C::Foo", cref.path
  end

  test "#path is memoized" do
    cref = new_cref
    assert_equal cref.path.object_id, cref.path.object_id
  end

  test "#to_s is #path" do
    assert_equal Zeitwerk::Cref.instance_method(:to_s), Zeitwerk::Cref.instance_method(:path)
  end

  test "#eql? is true for the same object" do
    cref = new_cref
    assert cref.eql?(cref)
  end

  test "#eql? is true for different objects with the same path" do
    cref1 = new_cref
    cref2 = new_cref
    assert cref1.eql?(cref2)
    assert cref2.eql?(cref1)
  end

  test "#eql? is true for different objects with different paths" do
    assert !new_cref.eql?(new_cref(klass, :Bar))
    assert !new_cref(String, :Foo).eql?(new_cref)
  end

  test "#eql? is false for objects of different classes" do
    assert !new_cref.eql?(Object.new)
  end

  test "#== is #eql?" do
    assert_equal Zeitwerk::Cref.instance_method(:==), Zeitwerk::Cref.instance_method(:eql?)
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

  test "crefs are hashable" do
    cref = new_cref
    h = { cref => true }

    assert h[cref]
    assert h[new_cref]
    assert !h[new_cref(klass, :Bar)]
  end

  test "crefs are hashable even if #hash is overridden in mod" do
    on_teardown do
      remove_const :M
      remove_const :C
    end

    ::M = new_overridden_module
    cref = new_cref(::M)
    assert_equal [cref], { cref => 1 }.keys

    ::C = new_overridden_class
    cref = new_cref(::C)
    assert_equal [cref], { cref => 1 }.keys
  end
end
