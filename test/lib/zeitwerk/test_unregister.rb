# frozen_string_literal: true

require "test_helper"

class TestUnregister < LoaderTest
  test "unregister removes the loader from internal state" do
    loader1 = Zeitwerk::Loader.new
    cref1 = Zeitwerk::Cref.new(Object, :"dummy1")
    registry = Zeitwerk::Registry
    registry.loaders.register(loader1)
    registry.gem_loaders_by_root_file["dummy1"] = loader1
    registry.autoloads.register("dummy1", loader1)
    registry.explicit_namespaces.register(cref1, loader1)

    loader2 = Zeitwerk::Loader.new
    cref2 = Zeitwerk::Cref.new(Object, :"dummy2")
    registry = Zeitwerk::Registry
    registry.loaders.register(loader2)
    registry.gem_loaders_by_root_file["dummy2"] = loader2
    registry.autoloads.register("dummy2", loader2)
    registry.explicit_namespaces.register(cref2, loader2)

    loader1.unregister

    assert !registry.loaders.registered?(loader1)
    assert !registry.gem_loaders_by_root_file.values.include?(loader1)
    assert !registry.autoloads.registered?("dummy1")
    assert !registry.explicit_namespaces.registered?(cref1)

    assert registry.loaders.registered?(loader2)
    assert registry.gem_loaders_by_root_file.values.include?(loader2)
    assert registry.autoloads.registered?("dummy2")
    assert registry.explicit_namespaces.registered?(cref2) == loader2
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
