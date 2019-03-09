require "minitest/autorun"
require "minitest/focus"

require "minitest/reporters"
Minitest::Reporters.use!(Minitest::Reporters::DefaultReporter.new)

require "zeitwerk"

require "support/test_macro"
require "support/delete_loaded_feature"
require "support/loader_test"

Minitest::Test.class_eval do
  extend TestMacro
  include DeleteLoadedFeature
end
