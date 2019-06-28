require "test_helper"

class TestInflector < Minitest::Test
  def camelize(str)
    Zeitwerk::Inflector.new.camelize(str, nil)
  end

  test "capitalizes the first letter" do
    assert_equal "User", camelize("user")
  end

  test "camelizes snake case basenames" do
    assert_equal "UsersController", camelize("users_controller")
  end

  test "supports segments that do not capitalize" do
    assert_equal "Point3dValue", camelize("point_3d_value")
  end

  test "knows nothing about acronyms" do
    assert_equal "HtmlParser", camelize("html_parser")
  end
end
