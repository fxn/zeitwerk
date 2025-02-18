# frozen_string_literal: true

require "test_helper"

class TestCrefMap < Minitest::Test
  def setup
    @map = Zeitwerk::Cref::Map.new

    @m = Module.new
    @cref_mx = Zeitwerk::Cref.new(@m, :X)
    @cref_my = Zeitwerk::Cref.new(@m, :Y)

    @n = Module.new
    @cref_nx = Zeitwerk::Cref.new(@n, :X)
    @cref_ny = Zeitwerk::Cref.new(@n, :Y)
  end

  def initialize_map
    @map[@cref_mx] = "mx"
    @map[@cref_my] = "my"
    @map[@cref_nx] = "nx"
    @map[@cref_ny] = "ny"
  end

  test "initially empty" do
    assert @map.empty?
  end

  test "[]= sets a value, [] reads it back" do
    initialize_map

    assert_equal "mx", @map[@cref_mx]
    assert_equal "my", @map[@cref_my]
    assert_equal "nx", @map[@cref_nx]
    assert_equal "ny", @map[@cref_ny]
  end

  test "[] returns nil if the value does not exist" do
    assert_nil @map[@cref_mx]
  end

  test "get_or_set returns the value if the key exists" do
    @map[@cref_mx] = "mx"

    assert_equal "mx", @map.get_or_set(@cref_mx) { "not-mx" }
  end

  test "get_or_set sets the value if the key does not exist" do
    assert_same false, @map.get_or_set(@cref_mx) { false }
    assert_same false, @map[@cref_mx]
  end

  test "delete removes and returns an existing value" do
    initialize_map

    assert_equal "mx", @map.delete(@cref_mx)
    assert_nil @map[@cref_mx]
    assert_equal "my", @map.delete(@cref_my)
    assert_nil @map[@cref_my]
    assert_equal "nx", @map.delete(@cref_nx)
    assert_nil @map[@cref_nx]
    assert_equal "ny", @map.delete(@cref_ny)
    assert_nil @map[@cref_ny]

    assert @map.empty?
  end

  test "delete returns nil if the cref is not present" do
    @map[@cref_mx] = "mx"

    assert_nil @map.delete(@cref_my)
    assert_nil @map.delete(@cref_nx)
  end

  test "delete_mod_cname removes and returns an existing value" do
    @map[@cref_mx] = "mx"

    assert_equal "mx", @map.delete_mod_cname(@m, :X)
    assert @map.empty?
  end

  test "delete_mod_cname returns nil if the cref is not present" do
    assert_nil @map.delete_mod_cname(@m, :X)
  end

  test "delete_by_value removes all cnames with the given value" do
    @map[@cref_mx] = 0
    @map[@cref_my] = 1
    @map[@cref_nx] = 0
    @map[@cref_ny] = 1

    @map.delete_by_value(0)

    assert_nil @map[@cref_mx]
    assert_equal 1, @map[@cref_my]
    assert_nil @map[@cref_nx]
    assert_equal 1, @map[@cref_ny]
  end

  test "each_key does not yield if the map is empty" do
    yielded = false
    @map.each_key { yielded = true }
    assert !yielded
  end

  test "each_key yields all keys in an undefined order" do
    initialize_map

    keys = []
    @map.each_key { |key| keys << [key.mod, key.cname] }

    assert_equal 4, keys.size

    assert keys.include?([@m, :X])
    assert keys.include?([@m, :Y])
    assert keys.include?([@n, :X])
    assert keys.include?([@n, :Y])
  end

  test "clear empties the map" do
    initialize_map

    @map.clear
    assert @map.empty?
  end

  # See https://github.com/fxn/zeitwerk/issues/188.
  test "the map is robust to hash overrides" do
    # This module is not hashable because the `hash` method has been overridden
    # to mean something else. In particular, it has even a different arity.
    m = Module.new do
      def self.hash(_) = nil
    end

    assert_raises(ArgumentError, 'wrong number of arguments (given 0, expected 1)') do
      { m => 0 }
    end

    n = Module.new do
      def self.hash(_) = nil
    end

    # This map is designed to be able to use class and module objects as keys
    # even if they are not technically hashable.
    map = Zeitwerk::Cref::Map.new
    cref_m = Zeitwerk::Cref.new(m, :X)
    cref_n = Zeitwerk::Cref.new(n, :X)

    map[cref_m] = 0
    map[cref_n] = 1

    assert_equal 0, map[cref_m]
    assert_equal 1, map[cref_n]
  end
end
