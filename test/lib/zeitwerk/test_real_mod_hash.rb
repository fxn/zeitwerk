# frozen_string_literal: true

require "test_helper"

class TestRealModHash < Minitest::Test
  include Zeitwerk::RealModHash

  test "real_mod_hash returns the original hash (not overridden)" do
    [Module.new, Class.new].each do |mod|
      assert_equal mod.hash, real_mod_hash(mod)
    end
  end

  test "real_mod_hash returns the original hash (overridden)" do
    [new_overridden_module, new_overridden_class].each do |mod|
      assert_equal mod.real_hash, real_mod_hash(mod)
    end
  end
end
