# frozen_string_literal: true

require "test_helper"

class TestNsFilesValidations < LoaderTest
  test "nsfiles must be strings" do
    e = assert_raises(TypeError) do
      loader.nsfile = :ns
    end
    assert_equal "nsfiles must be strings", e.message
  end

  test "nsfiles must have .rb extension" do
    e = assert_raises(ArgumentError) do
      loader.nsfile = "ns"
    end
    assert_equal "nsfiles must have .rb extension", e.message
  end

  test "nsfiles must be basenames, not paths" do
    e = assert_raises(ArgumentError) do
      loader.nsfile = "path/to/ns.rb"
    end
    assert_equal "nsfiles must be basenames, not paths", e.message
  end

  test "nsfiles cannot be hidden" do
    e = assert_raises(ArgumentError) do
      loader.nsfile = ".ns.rb"
    end
    assert_equal "nsfiles cannot be hidden", e.message
  end
end

class TestNsfilesFeatures < LoaderTest
  def setup
    super
    loader.nsfile = "ns.rb"
  end

  test "nsfiles define namespaces (direct)" do
    files = [["widget/ns.rb", "Widget = Class.new"]]
    with_setup(files) do
      assert_kind_of Class, Widget
    end
  end

  test "other files are loaded as usual" do
    files = [["widget/ns.rb", "Widget = Class.new"], ["widget/x.rb", "Widget::X = true"]]
    with_setup(files) do
      assert_kind_of Class, Widget
      assert Widget::X
    end
  end

  test "nsfiles DO NOT define namespaces if ignored" do
    loader.nsfile = "ignored.rb"

    files = [["widget/ignored.rb"], ["widget/x.rb", "Widget::X = true"]]
    with_setup(files) do
      assert_kind_of Module, Widget
      assert Widget::X
    end
  end

  test "nsfiles define namespaces (collapsed)" do
    files = [["widget/collapsed/ns.rb", "Widget = Class.new"]]
    with_setup(files) do
      assert_kind_of Class, Widget
    end
  end

  test "other files are loaded as usual (collapsed)" do
    files = [["widget/collapsed/ns.rb", "Widget = Class.new"], ["widget/collapsed/x.rb", "Widget::X = true"]]
    with_setup(files) do
      assert_kind_of Class, Widget
      assert Widget::X
    end
  end

  test "nsfiles define namespaces (collapsed, nested)" do
    with_setup([["widget/collapsed/collapsed/ns.rb", "Widget = Class.new"]]) do
      assert_kind_of Class, Widget
    end
  end

  test "other files are loaded as usual (collapsed, nested)" do
    with_setup([["widget/collapsed/collapsed/ns.rb", "Widget = Class.new"], ["widget/collapsed/collapsed/x.rb", "Widget::X = true"]]) do
      assert_kind_of Class, Widget
      assert Widget::X
    end
  end

  test "nsfiles are not inflected" do
    with_files([["widget/ns.rb", "Widget = Class.new"]]) do
      loader.inflector.inflect("ns" => "not-a-cname")
      loader.push_dir(".")
      loader.setup

      assert_kind_of Class, Widget
    end
  end
end

class TestNsfilesErrorConditions < LoaderTest
  def setup
    super
    loader.nsfile = "ns.rb"
  end

  test "nsfiles on external namespaces raise (root directory)" do
    with_files(["ns.rb"]) do
      loader.push_dir(".")

      assert_raises(Zeitwerk::NameConflict) { loader.setup }
    end
  end

  test "nsfiles on external namespaces raise (nested directory)" do
    with_files(["test_nsfiles_error_conditions/ns.rb"]) do
      loader.push_dir(".")

      assert_raises(Zeitwerk::NameConflict) { loader.setup }
    end
  end

  test "a namespace can have at most one nsfile" do
    with_files([["rd1/foo/ns.rb"], ["rd2/foo/ns.rb"]]) do
      loader.push_dir("rd1")
      loader.push_dir("rd2")

      assert_raises(Zeitwerk::NameConflict) { loader.setup }
    end
  end

  test "a namespace cannot be defined using both conventions (nsfile first)" do
    with_files([["rd1/foo/ns.rb"], ["rd2/foo.rb"]]) do
      loader.push_dir("rd1")
      loader.push_dir("rd2")

      assert_raises(Zeitwerk::NameConflict) { loader.setup }
    end
  end

  test "a namespace cannot be defined using both conventions (regular first)" do
    with_files([["rd1/foo.rb"], ["rd2/foo/ns.rb"]]) do
      loader.push_dir("rd1")
      loader.push_dir("rd2")

      assert_raises(Zeitwerk::NameConflict) { loader.setup }
    end
  end

  test "a namespace cannot be defined using both conventions (directory -> nsfile -> regular)" do
    with_files([["rd1/foo/x.rb"], ["rd2/foo/ns.rb"], ["rd3/foo.rb"]]) do
      loader.push_dir("rd1")
      loader.push_dir("rd2")
      loader.push_dir("rd3")

      assert_raises(Zeitwerk::NameConflict) { loader.setup }
    end
  end

  test "a namespace cannot be defined using both conventions (directory -> regular -> nsfile)" do
    with_files([["rd1/foo/x.rb"], ["rd2/foo.rb"], ["rd3/foo/ns.rb"]]) do
      loader.push_dir("rd1")
      loader.push_dir("rd2")
      loader.push_dir("rd3")

      assert_raises(Zeitwerk::NameConflict) { loader.setup }
    end
  end

  test "a namespace cannot be defined using both conventions (nsfile -> directory -> regular)" do
    with_files([["rd1/foo/ns.rb"], ["rd2/foo/x.rb"], ["rd3/foo.rb"]]) do
      loader.push_dir("rd1")
      loader.push_dir("rd2")
      loader.push_dir("rd3")

      assert_raises(Zeitwerk::NameConflict) { loader.setup }
    end
  end

  test "a namespace cannot be defined using both conventions (nsfile -> regular -> directory)" do
    with_files([["rd1/foo/ns.rb"], ["rd2/foo.rb"], ["rd3/foo/x.rb"]]) do
      loader.push_dir("rd1")
      loader.push_dir("rd2")
      loader.push_dir("rd3")

      assert_raises(Zeitwerk::NameConflict) { loader.setup }
    end
  end

  test "a namespace cannot be defined using both conventions (regular -> directory -> nsfile)" do
    with_files([["rd1/foo.rb"], ["rd2/foo/x.rb"], ["rd3/foo/ns.rb"]]) do
      loader.push_dir("rd1")
      loader.push_dir("rd2")
      loader.push_dir("rd3")

      assert_raises(Zeitwerk::NameConflict) { loader.setup }
    end
  end

  test "a namespace cannot be defined using both conventions (regular -> nsfile -> directory)" do
    with_files([["rd1/foo.rb"], ["rd2/foo/ns.rb"], ["rd3/foo/x.rb"]]) do
      loader.push_dir("rd1")
      loader.push_dir("rd2")
      loader.push_dir("rd3")

      assert_raises(Zeitwerk::NameConflict) { loader.setup }
    end
  end

  test "cpath_expected_at supports nsfiles" do
    with_setup([["widget/ns.rb", "Widget = Class.new"]]) do
      assert_equal "Widget", loader.cpath_expected_at("widget/ns.rb")
    end
  end
end
