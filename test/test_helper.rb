require "minitest/autorun"
require "minitest/focus"

require "minitest/reporters"
Minitest::Reporters.use!(Minitest::Reporters::DefaultReporter.new)

require "minitest/fork_executor"
Minitest.parallel_executor = Minitest::ForkExecutor.new

require "zeitwerk"

require "support/test_macro"
require "support/loader_test"

Minitest::Test.class_eval do
  extend TestMacro
end
