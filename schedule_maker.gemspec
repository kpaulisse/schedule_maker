# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

require 'rake'

Gem::Specification.new do |s|
  s.name        = 'schedule_maker'
  s.version     = '0.0.3'
  # s.platform    = Gem::Platform::RUBY
  s.authors     = 'Kevin Paulisse'
  s.date        = Time.now.strftime('%Y-%m-%d')
  #  s.email       = ""
  s.homepage    = 'http://github.com/kpaulisse/schedule_maker'
  s.summary     = 'Make schedules with evenly spaced variable length shifts'
  s.description = 'Used for creating on-call schedules'
  s.license     = 'Apache 2.0'

  s.files         = Dir['[A-Z]*[^~]'] + Dir['lib/**/*.rb'] + Dir['spec/*'] + ['.gitignore']
  s.test_files    = Dir['spec/*']
  s.executables   = []
  s.require_paths = ['lib']

  s.add_development_dependency 'rspec', '>= 3.0.0'
end
