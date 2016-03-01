#!/usr/bin/env ruby

require File.join(
  File.expand_path(File.join(File.dirname(__FILE__), '..')), 'lib', 'schedule_maker.rb')

rotation = {
  'four' => 4,
  'one' => 1,
  'uno' => 1,
  'un' => 1,
  'two' => 2,
  'deux' => 2
}

x = ScheduleMaker::Schedule.new(rotation, rotation_count: 2, debug: true)
x.optimize
puts x.as_schedule('2016-05-03T00:00:00')
