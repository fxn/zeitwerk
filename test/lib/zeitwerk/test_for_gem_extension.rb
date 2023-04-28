# frozen_string_literal: true

require "test_helper"

class TestForGemExtension < LoaderTest
  ROOT_DIR = "lib/test_for_gem_extension"
  MY_GEM_EXTENSION = ["#{ROOT_DIR}/my_gem_extension.rb", <<~EOS]
    $for_gem_extension_test_loader = Zeitwerk::Loader.for_gem_extension(#{self})
    $for_gem_extension_test_loader.enable_reloading
    $for_gem_extension_test_loader.setup

    module #{self}::MyGemExtension
    end
  EOS

  def with_my_gem_extension(files = [MY_GEM_EXTENSION], rq = true)
    with_files(files) do
      with_load_path("lib") do
        if rq
          assert require("test_for_gem_extension/my_gem_extension")
          assert self.class::MyGemExtension
        end
        yield
      end
    end
  end

  test "sets things correctly" do
    files = [
      MY_GEM_EXTENSION,
      ["#{ROOT_DIR}/my_gem_extension/foo.rb", "class #{self.class}::MyGemExtension::Foo; end"],
      ["#{ROOT_DIR}/my_gem_extension/foo/bar.rb", "#{self.class}::MyGemExtension::Foo::Bar = true"]
    ]
    with_my_gem_extension(files) do
      assert self.class::MyGemExtension::Foo::Bar

      $for_gem_extension_test_loader.unload
      assert !self.class.const_defined?(:MyGemExtension)

      $for_gem_extension_test_loader.setup
      assert self.class::MyGemExtension::Foo::Bar
    end
  end

  test "is idempotent" do
    $for_gem_extension_zs = []
    files = [
      ["#{ROOT_DIR}/my_gem_extension.rb", <<-EOS],
        $for_gem_extension_zs << Zeitwerk::Loader.for_gem_extension(#{self.class})
        $for_gem_extension_zs.last.enable_reloading
        $for_gem_extension_zs.last.setup

        module #{self.class}::MyGemExtension
        end
      EOS
    ]

    with_my_gem_extension(files) do
      $for_gem_extension_zs.first.unload
      assert !self.class.const_defined?(:MyGemExtension)

      $for_gem_extension_zs.first.setup
      assert self.class::MyGemExtension

      assert_equal 2, $for_gem_extension_zs.size
      assert_same $for_gem_extension_zs.first, $for_gem_extension_zs.last
    end
  end

  test "configures the gem inflector by default" do
    files = [MY_GEM_EXTENSION, ["#{ROOT_DIR}/my_gem_extension/version.rb", "#{self.class}::MyGemExtension::VERSION = '1.0'"]]
    with_my_gem_extension(files) do
      assert_instance_of Zeitwerk::GemInflector, $for_gem_extension_test_loader.inflector
      assert_equal "1.0", self.class::MyGemExtension::VERSION
    end
  end

  test "configures the namespace plus basename of the root file as loader tag" do
    with_my_gem_extension do
      assert_equal "#{self.class}-my_gem_extension", $for_gem_extension_test_loader.tag
    end
  end

  test "works too if going through a hyphenated entry point (require)" do
    files = [
      ["lib/my-gem-extension.rb", "require 'test_for_gem_extension/my_gem_extension'"],
      MY_GEM_EXTENSION,
    ]
    with_my_gem_extension(files, false) do
      assert require("my-gem-extension")
      assert self.class::MyGemExtension
    end
  end

  test "raises if the namespace is not a class or module object" do
    e = assert_raises(Zeitwerk::Error) { Zeitwerk::Loader.for_gem_extension(:foo) }
    assert_equal ":foo is not a class or module object, should be", e.message
  end

  test "raises if the namespace is anonymous" do
    e = assert_raises(Zeitwerk::Error) { Zeitwerk::Loader.for_gem_extension(Module.new) }
    assert_equal "extending anonymous namespaces is unsupported", e.message
  end
end
