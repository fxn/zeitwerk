# frozen_string_literal: true

require "minitest/autorun"
require "minitest/focus"
require "minitest/mock"
require "minitest/proveit"

require "minitest/reporters"
Minitest::Reporters.use!(Minitest::Reporters::DefaultReporter.new)

require "warning"
Warning.process do |msg|
  # This warning is issued by Zeitwerk itself, ignore it.
  if msg.include?("Zeitwerk defines the constant")
    :default
  # These ones are issued by the test "autovivification is synchronized" from
  # test_autovivification.rb, but only on Ruby 2.5. They can be ignored, the
  # test verifies the constant is set only once. I suspect this is related to
  # the internal representation of constants in CRuby and
  #
  #     https://github.com/ruby/ruby/commit/b74131132f8872d23e405c61ecfe18dece17292f
  #
  # fixed it, but have not verified it.
  elsif msg.include?("already initialized constant Admin::V2") || msg.include?("previous definition of V2 was here")
    :default
  else
    :raise
  end
end

require_relative "support/test_macro"
require_relative "support/delete_loaded_feature"
require_relative "support/loader_test"
require_relative "support/remove_const"
require_relative "support/on_teardown"

require "zeitwerk"

Minitest::Test.class_eval do
  extend TestMacro
  include DeleteLoadedFeature
  include RemoveConst
  include OnTeardown

  prove_it!
end
