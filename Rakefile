# frozen_string_literal: true

require 'rake/testtask'

task :default => :test

Rake::TestTask.new do |t|
  t.test_files = Dir.glob('test/lib/**/test_*.rb')
  t.libs << "test"
  t.warning = true
end
