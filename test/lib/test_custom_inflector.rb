# frozen_string_literal: true

require "test_helper"

class TestCustomInflector < LoaderTest
  test "raises TypeError if the inflector #camelize does not return a string" do
    with_files([["foo.rb", nil]]) do
      loader.inflector = Class.new(Zeitwerk::Inflector) do
        def camelize(_basename, _abspath)
          :Foo # this is wrong
        end
      end.new

      loader.push_dir(".")

      error = assert_raises TypeError do
        loader.setup
      end

      assert_includes error.message, "#camelize must return a String"
    end
  end

  test "raises if the returned constant names has ::" do
    with_files([["foo-bar.rb", nil]]) do
      loader.inflector = Class.new(Zeitwerk::Inflector) do
        def camelize(basename, _abspath)
          if basename == "foo-bar"
            "Foo::Bar" # this is wrong
          else
            super
          end
        end
      end.new

      loader.push_dir(".")

      error = assert_raises Zeitwerk::NameError do
        loader.setup
      end

      assert_includes error.message, "wrong constant name Foo::Bar"
      assert_includes error.message, "#camelize should return a simple constant name"
    end
  end
end
