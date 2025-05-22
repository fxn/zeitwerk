# frozen_string_literal: true

require "test_helper"

class TestAllExpectedCpaths < LoaderTest
  module Namespace
    def self.name
      "overridden"
    end
  end

  test "returns an empty hash if there are no root directories" do
    with_setup do
      expected_cpaths({})
    end
  end

  test "honors a real root module name" do
    files = [["x.rb", "#{self.class}::Namespace::X = 1"]]
    with_setup(files, namespace: Namespace) do
      expected_cpaths(
        "." => "#{self.class.name}::Namespace",
        "x.rb" => "#{self.class.name}::Namespace::X"
      )
    end
  end

  test "does not include ignored files and directories" do
    files = [
      ["x.rb", "X = 1"],
      ["ignored.rb", ""],
      ["ignored/x.rb", ""]
    ]
    with_setup(files) do
      expected_cpaths(
        "." => "Object",
        "x.rb" => "X"
      )
    end
  end

  test "does not include hidden files" do
    files = [
      [".foo.rb", ""],
      ["x.rb", "X = 1"]
    ]
    with_setup(files) do
      expected_cpaths(
        "." => "Object",
        "x.rb" => "X"
      )
    end
  end

  test "does not include directories without Ruby files " do
    files = [
      ["x.rb", "X = 1"],
      ["empty", ""],
      ["assets/js/index.js", ""],
      ["assets/css/index.css", ""],
      ["m/ignored.rb", ""]
    ]
    with_setup(files) do
      expected_cpaths(
        "." => "Object",
        "x.rb" => "X"
      )
    end
  end

  test "includes shadowed files" do
    files = [
      ["rd1/x.rb", "X = 1"],
      ["rd2/x.rb", "X = 1"],
    ]
    with_setup(files) do
      expected_cpaths(
        "rd1" => "Object",
        "rd1/x.rb" => "X",
        "rd2" => "Object",
        "rd2/x.rb" => "X"
      )
    end
  end

  test "honors collapsed directories" do
    files = [
      ["x.rb", "X = 1"],
      ["collapsed/y.rb", "Y = 1"],
      ["m/collapsed/n/x.rb", "M::N::X = 1"]
    ]
    with_setup(files) do
      expected_cpaths(
        "." => "Object",
        "x.rb" => "X",
        "collapsed" => "Object",
        "collapsed/y.rb" => "Y",
        "m" => "M",
        "m/collapsed" => "M",
        "m/collapsed/n" => "M::N",
        "m/collapsed/n/x.rb" => "M::N::X"
      )
    end
  end

  test "implicit namespaces" do
    files = [
      ["x.rb", "X = 1"],
      ["m/x.rb", "M::X = 1"],
      ["m/n/x.rb", "M::N::X = 1"]
    ]
    with_setup(files) do
      expected_cpaths(
        "." => "Object",
        "x.rb" => "X",
        "m" => "M",
        "m/x.rb" => "M::X",
        "m/n" => "M::N",
        "m/n/x.rb" => "M::N::X"
      )
    end
  end

  test "explicit namespaces" do
    files = [
      ["x.rb", "X = 1"],
      ["m.rb", "module M; end"],
      ["m/x.rb", "M::X = 1"],
      ["m/n.rb", "module M::N; end"],
      ["m/n/x.rb", "M::N::X = 1"]
    ]
    with_setup(files) do
      expected_cpaths(
        "." => "Object",
        "x.rb" => "X",
        "m.rb" => "M",
        "m" => "M",
        "m/x.rb" => "M::X",
        "m/n.rb" => "M::N",
        "m/n" => "M::N",
        "m/n/x.rb" => "M::N::X"
      )
    end
  end

  private def expected_cpaths(expected)
    actual = loader.all_expected_cpaths

    assert_equal expected.size, actual.size
    expected.each do |relpath, expected_cpath|
      assert_equal expected_cpath, actual[File.expand_path(relpath)]
    end
  end
end
