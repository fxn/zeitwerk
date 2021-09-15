# frozen_string_literal: true

require "test_helper"

class TestRealModName < Minitest::Test
  include Zeitwerk::RealModName

  test "returns nil for anonymous classes and modules" do
    [Class.new, Module.new].each do |mod|
      assert_nil real_mod_name(mod)
    end
  end

  test "returns nil for anonymous classes and modules that override #name" do
    [Class.new, Module.new].each do |mod|
      def mod.name; "X"; end
      assert_equal "X", mod.name
      assert_nil real_mod_name(mod)
    end
  end

  test "returns the name of regular classes an modules" do
    on_teardown do
      remove_const :C, from: self.class
      remove_const :M, from: self.class
    end

    C = Class.new
    M = Module.new

    [C, M].each do |mod|
      assert_equal mod.name, real_mod_name(mod)
    end
  end

  test "returns the real name of class and modules that override #name" do
    on_teardown do
      remove_const :C, from: self.class
      remove_const :M, from: self.class
    end

    C = Class.new { def self.name; "X"; end }
    M = Module.new { def self.name; "X"; end }

    [[C, "#{self.class}::C"], [M, "#{self.class}::M"]].each do |mod, real|
      assert_equal "X", mod.name
      assert_equal real, real_mod_name(mod)
    end
  end
end
