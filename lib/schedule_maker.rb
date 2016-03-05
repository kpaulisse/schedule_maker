# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

%w(period rotation rotationutil schedule scheduleutil stats util).each do |file|
  require File.join(File.dirname(__FILE__), 'schedule_maker', file)
end

%w(blackout dummy spacing weekdays).each do |file|
  require File.join(File.dirname(__FILE__), 'schedule_maker', 'datamodel', file)
end

%w(stats).each do |file|
  require File.join(File.dirname(__FILE__), 'schedule_maker', 'model', file)
end
