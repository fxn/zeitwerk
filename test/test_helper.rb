# frozen_string_literal: true

require "minitest/autorun"
require "minitest/focus"
require "minitest/proveit"

require "minitest/reporters"
Minitest::Reporters.use!(Minitest::Reporters::DefaultReporter.new)

# require_relative "support/no_warnings_policy"
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
