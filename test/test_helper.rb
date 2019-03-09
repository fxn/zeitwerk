require "minitest/autorun"
require "minitest/focus"

require "minitest/reporters"
Minitest::Reporters.use!(Minitest::Reporters::DefaultReporter.new)

require "zeitwerk"

require "support/test_macro"
require "support/delete_loaded_feature"
require "support/loader_test"
require "support/remove_const"
require "support/on_teardown"

Minitest::Test.class_eval do
  extend TestMacro
  include DeleteLoadedFeature
  include RemoveConst
  include OnTeardown
end
