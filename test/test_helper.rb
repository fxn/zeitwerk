# frozen_string_literal: true

require "minitest/autorun"
require "minitest/focus"

require "minitest/reporters"
Minitest::Reporters.use!(Minitest::Reporters::DefaultReporter.new)

require "support/no_warnings_policy"
require "support/test_macro"
require "support/delete_loaded_feature"
require "support/loader_test"
require "support/remove_const"
require "support/on_teardown"

require "zeitwerk"

Minitest::Test.class_eval do
  extend TestMacro
  include DeleteLoadedFeature
  include RemoveConst
  include OnTeardown
end
