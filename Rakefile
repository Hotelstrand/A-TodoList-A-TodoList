# frozen_string_literal: true

require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
task default: :spec

desc 'Lint using RuboCop'
RuboCop::RakeTask.new(:lint)

desc 'Generates a properties file for each job based on properties.X.Y used in templates'
task :job_properties do
  require 'fileutils'
  Dir['jobs/*'].each do |path|
    puts "Sear