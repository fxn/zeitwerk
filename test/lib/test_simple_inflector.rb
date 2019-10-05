require "test_helper"

class TestSimpleInflector < Minitest::Test
  def inflections
    {
      "api" => "API",
      "global_id" => "GlobalID",
      "mysql" => "MySQL",
    }
  end

  test "camelizes using the inflections hash" do
    inflector = Zeitwerk::SimpleInflector.new(inflections)

    assert_equal "API", inflector.camelize("api", nil)
    assert_equal "GlobalID", inflector.camelize("global_id", nil)
    assert_equal "MySQL", inflector.camelize("mysql", nil)
  end

  test "camelizes basenames not in the inflections hash normally" do
    inflector = Zeitwerk::SimpleInflector.new(inflections)

    assert_equal "HtmlParser", inflector.camelize("html_parser", nil)
  end

  test "inflections can be added after initialization" do
    inflector = Zeitwerk::SimpleInflector.new
    inflector.inflect 'http', 'HTTP'

    assert_equal "HTTP", inflector.camelize("http", nil)
  end
end
