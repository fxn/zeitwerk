# frozen_string_literal: true

require "test_helper"

class TestForGem < LoaderTest
  MY_GEM = ["lib/my_gem.rb", <<~EOS]
    $for_gem_test_loader = Zeitwerk::Loader.for_gem
    $for_gem_test_loader.enable_reloading
    $for_gem_test_loader.setup

    module MyGem
    end
  EOS

  def with_my_gem(files = [MY_GEM], rq = true)
    with_files(files) do
      with_load_path("lib") do
        if rq
          assert require("my_gem")
          assert MyGem
        end
        yield
      end
    end
  end

  test "sets things correctly" do
    files = [
      MY_GEM,
      ["lib/my_gem/foo.rb", "class MyGem::Foo; end"],
      ["lib/my_gem/foo/bar.rb", "MyGem::Foo::Bar = true"]
    ]
    with_my_gem(files) do
      assert MyGem::Foo::Bar

      $for_gem_test_loader.unload
      assert !Object.const_defined?(:MyGem)

      $for_gem_test_loader.setup
      assert MyGem::Foo::Bar
    end
  end

  test "is idempotent" do
    $for_gem_test_zs = []
    files = [
      ["lib/my_gem.rb", <<-EOS],
        $for_gem_test_zs << Zeitwerk::Loader.for_gem
        $for_gem_test_zs.last.enable_reloading
        $for_gem_test_zs.last.setup

        module MyGem
        end
      EOS
    ]

    with_my_gem(files) do
      $for_gem_test_zs.first.unload
      assert !Object.const_defined?(:MyGem)

      $for_gem_test_zs.first.setup
      assert MyGem

      assert_equal 2, $for_gem_test_zs.size
      assert_same $for_gem_test_zs.first, $for_gem_test_zs.last
    end
  end

  test "configures the gem inflector by default" do
    with_my_gem do
      assert_instance_of Zeitwerk::GemInflector, $for_gem_test_loader.inflector
    end
  end

  test "configures the basename of the root file as loader tag" do
    with_my_gem do
      assert_equal "my_gem", $for_gem_test_loader.tag
    end
  end

  test "does not warn if lib only has expected files" do
    with_my_gem([MY_GEM], false) do
      assert_silent do
        assert require("my_gem")
      end
    end
  end

  test "does not warn if lib only has extra, non-hidden, non-Ruby files" do
    files = [MY_GEM, ["lib/i18n.yml", ""], ["lib/.vscode", ""]]
    with_my_gem(files, false) do
      assert_silent do
        assert require("my_gem")
      end
    end
  end

  test "warns if the lib has an extra Ruby file" do
    files = [MY_GEM, ["lib/foo.rb", ""]]
    with_my_gem(files, false) do
      _out, err = capture_io do
        assert require("my_gem")
      end
      assert_includes err, "Zeitwerk defines the constant Foo after the file"
      assert_includes err, File.expand_path("lib/foo.rb")
      assert_includes err, "Zeitwerk::Loader.for_gem(warn_on_extra_files: false)"
    end
  end

  test "does not warn if lib has an extra Ruby file, but it is ignored" do
    files = [["lib/my_gem.rb", <<~EOS], ["lib/foo.rb", ""]]
      loader = Zeitwerk::Loader.for_gem
      loader.ignore("\#{__dir__}/foo.rb")
      loader.enable_reloading
      loader.setup

      module MyGem
      end
    EOS
    with_my_gem(files, false) do
      _out, err = capture_io do
        assert require("my_gem")
      end
      assert_empty err
    end
  end

  test "does not warn if lib has an extra Ruby file, but warnings are disabled" do
    files = [["lib/my_gem.rb", <<~EOS], ["lib/foo.rb", ""]]
      loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
      loader.enable_reloading
      loader.setup

      module MyGem
      end
    EOS
    with_my_gem(files, false) do
      _out, err = capture_io do
        assert require("my_gem")
      end
      assert_empty err
    end
  end

  test "warns if lib has an extra directory" do
    files = [MY_GEM, ["lib/foo/bar.rb", "Foo::Bar = true"]]
    with_my_gem(files, false) do
      _out, err = capture_io do
        assert require("my_gem")
      end
      assert_includes err, "Zeitwerk defines the constant Foo after the directory"
      assert_includes err, File.expand_path("lib/foo")
      assert_includes err, "Zeitwerk::Loader.for_gem(warn_on_extra_files: false)"
    end
  end

  test "does not warn if lib has an extra directory, but it is ignored" do
    files = [["lib/my_gem.rb", <<~EOS], ["lib/foo/bar.rb", "Foo::Bar = true"]]
      loader = Zeitwerk::Loader.for_gem
      loader.ignore("\#{__dir__}/foo")
      loader.enable_reloading
      loader.setup

      module MyGem
      end
    EOS
    with_my_gem(files, false) do
      _out, err = capture_io do
        assert require("my_gem")
      end
      assert_empty err
    end
  end

  test "does not warn if lib has an extra directory, but it has no Ruby files" do
    files = [["lib/my_gem.rb", <<~EOS], ["lib/tasks/newsletter.rake", ""]]
      loader = Zeitwerk::Loader.for_gem
      loader.enable_reloading
      loader.setup

      module MyGem
      end
    EOS
    with_my_gem(files, false) do
      _out, err = capture_io do
        assert require("my_gem")
      end
      assert_empty err
    end
  end

  test "does not warn if lib has an extra directory, but warnings are disabled" do
    files = [["lib/my_gem.rb", <<~EOS], ["lib/foo/bar.rb", "Foo::Bar = true"]]
      loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
      loader.enable_reloading
      loader.setup

      module MyGem
      end
    EOS
    with_my_gem(files, false) do
      _out, err = capture_io do
        assert require("my_gem")
      end
      assert_empty err
    end
  end

  test "warnings do not assume the namespace directory is the tag" do
    files = [["lib/my_gem.rb", <<~EOS], ["lib/foo/bar.rb", "Foo::Bar = true"]]
      loader = Zeitwerk::Loader.for_gem
      loader.tag = "foo"
      loader.enable_reloading
      loader.setup

      module MyGem
      end
    EOS
    with_my_gem(files, false) do
      _out, err = capture_io do
        assert require("my_gem")
      end
      assert_includes err, "Zeitwerk defines the constant Foo after the directory"
      assert_includes err, File.expand_path("lib/foo")
      assert_includes err, "Zeitwerk::Loader.for_gem(warn_on_extra_files: false)"
    end
  end

  test "warnings use the gem inflector" do
    files = [["lib/my_gem.rb", <<~EOS], ["lib/foo/bar.rb", "Foo::Bar = true"]]
      loader = Zeitwerk::Loader.for_gem
      loader.inflector.inflect("foo" => "BAR")
      loader.enable_reloading
      loader.setup

      module MyGem
      end
    EOS
    with_my_gem(files, false) do
      _out, err = capture_io do
        assert require("my_gem")
      end
      assert_includes err, "Zeitwerk defines the constant BAR after the directory"
      assert_includes err, File.expand_path("lib/foo")
      assert_includes err, "Zeitwerk::Loader.for_gem(warn_on_extra_files: false)"
    end
  end
end
