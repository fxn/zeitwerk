# frozen_string_literal: true

require "test_helper"

class TestNullInflector < Minitest::Test
  def camelize(str)
    Zeitwerk::NullInflector.new.camelize(str, nil)
  end

  test "does not change the basename" do
    assert_equal "user", camelize("user")
  end

  test "preserves case (camel case)" do
    assert_equal "UsersController", camelize("UsersController")
  end

  test "preserves case (acronym)" do
    assert_equal "HTMLTag", camelize("HTMLTag")
  end
end
