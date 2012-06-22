require 'rake/testtask'
require 'bundler'
Bundler::GemHelper.install_tasks

Rake::TestTask.new do |t|
  t.pattern = 'test/**/*_test.rb'
end

task :default => :test
