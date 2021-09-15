# frozen_string_literal: true

require "test_helper"

class TestUnregister < LoaderTest
  test "unregister removes the loader from internal state" do
    loader1 = Zeitwerk::Loader.new
    registry = Zeitwerk::Registry
    registry.register_loader(loader1)
    registry.loaders_managing_gems["dummy1"] = loader1
    registry.register_autoload(loader1, "dummy1")
    registry.register_inception("dummy1", "dummy1", loader1)
    Zeitwerk::ExplicitNamespace.register("dummy1", loader1)

    loader2 = Zeitwerk::Loader.new
    registry = Zeitwerk::Registry
    registry.register_loader(loader2)
    registry.loaders_managing_gems["dummy2"] = loader2
    registry.register_autoload(loader2, "dummy2")
    registry.register_inception("dummy2", "dummy2", loader2)
    Zeitwerk::ExplicitNamespace.register("dummy2", loader2)

    loader1.unregister

    assert !registry.loaders.include?(loader1)
    assert !registry.loaders_managing_gems.values.include?(loader1)
    assert !registry.autoloads.values.include?(loader1)
    assert !registry.inceptions.values.any? {|_, l| l == loader1}
    assert !Zeitwerk::ExplicitNamespace.cpaths.values.include?(loader1)

    assert registry.loaders.include?(loader2)
    assert registry.loaders_managing_gems.values.include?(loader2)
    assert registry.autoloads.values.include?(loader2)
    assert registry.inceptions.values.any? {|_, l| l == loader2}
    assert Zeitwerk::ExplicitNamespace.cpaths.values.include?(loader2)
  end

  test 'with_loader yields and unregisters' do
    loader = Zeitwerk::Loader.new
    unregister_was_called = false
    loader.define_singleton_method(:unregister) { unregister_was_called = true }

    Zeitwerk::Loader.stub :new, loader do
      Zeitwerk.with_loader do |l|
        assert_same loader, l
      end
    end

    assert unregister_was_called
  end

  test 'with_loader yields and unregisters, even if an exception happens' do
    loader = Zeitwerk::Loader.new
    unregister_was_called = false
    loader.define_singleton_method(:unregister) { unregister_was_called = true }

    Zeitwerk::Loader.stub :new, loader do
      Zeitwerk.with_loader { raise } rescue nil
    end

    assert unregister_was_called
  end
end
