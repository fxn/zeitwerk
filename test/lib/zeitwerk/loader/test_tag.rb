
# frozen_string_literal: true

require "test_helper"

class TestTag < LoaderTest
  test "a loader has a random tag by default" do
    loader = Zeitwerk::Loader.new
    assert_equal 6, loader.tag.length
  end

  test "the tag can be set to a custom value" do
    loader = Zeitwerk::Loader.new
    loader.tag = "foo"
    assert_equal "foo", loader.tag
  end

  test 'tags are converted to strings' do
    loader = Zeitwerk::Loader.new
    loader.tag = :foo
    assert_equal "foo", loader.tag
  end
end
