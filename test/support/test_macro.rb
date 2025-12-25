# frozen_string_literal: true

module TestMacro
  def test(description, &)
    method_name = "test_#{description}".gsub(/\W/, "_")
    define_method(method_name, &)
  end
end
