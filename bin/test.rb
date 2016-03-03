#!/usr/bin/env ruby

require File.join(
  File.expand_path(File.join(File.dirname(__FILE__), '..')), 'lib', 'schedule_maker.rb')

rotation = {
  'apple' => { 'period_length' => 2, 'start' => '2016-05-01T00:00:00' },
  'banana' => 4,
  'cherry' => { 'period_length' => 2, 'start' => '2016-05-01T00:00:00' },
  'date' => 2,
  'endive' => 4,
  'fig' => 1,
  'grape' => 1,
  'honeydew' => 1,
  'rhubarb' => 1,
  'starfruit' => 4,
  'tangerine' => { 'period_length' => 4, 'start' => '2016-06-15T00:00:00' },
  'uglifruit' => 4,
  'watercress' => 4,
  'yam' => 1
}

start = '2016-04-13T00:00:00'
x = ScheduleMaker::Schedule.new(rotation, rotation_count: 3, debug: true, start: start, period_length: 1)
x.optimize
puts x.as_schedule(start)
