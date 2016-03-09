# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker
  # Create statistics for a rotation
  class Stats
    # Calculate statistics about a rotation, including total days, total shifts,
    # shift length, and spacing.
    # @param schedule [ScheduleMaker::Schedule] Computed schedule
    # @param start [DateTime] Start date/time for schedule
    # @param participants [Hash] Participants hash (for time zone calculations)
    def self.stats(schedule, start, options = {})
      last_assignee = nil
      participants = options.fetch(:participants, schedule.rotation.participants)
      sked = options.fetch(:initial_schedule, schedule.as_schedule(start))
      rotation = options.fetch(:rotation, schedule.rotation)

      stats = {}
      timezones = {}
      participants.each do |key, val|
        timezones[key] = ScheduleMaker::Util.get_element_from_hash(val, :timezone, 'UTC')
        stats[key] = {
          days: 0, shifts: 0, spacing: [], min_shift: nil, max_shift: nil, score: 0,
          sunday: 0, monday: 0, tuesday: 0, wednesday: 0, thursday: 0, friday: 0, saturday: 0,
          weekend: 0, weekday: 0
        }
      end

      weekday_obj = ScheduleMaker::DataModel::Weekdays.new
      weekday_calc = weekday_obj.pain(rotation, force_calc: true)
      weekday_calc.each do |participant, obj|
        obj.each do |key, val|
          stats[participant][key] += val if val.is_a?(Fixnum)
        end
      end

      sked.each do |obj|
        stats[obj[:assignee]][:days] += 1
        stats[obj[:assignee]][:spacing] << obj[:prev].to_i if obj.key?(:prev) && obj[:assignee] != last_assignee
        if stats[obj[:assignee]][:min_shift].nil? || obj[:length] < stats[obj[:assignee]][:min_shift]
          stats[obj[:assignee]][:min_shift] = obj[:length]
        end
        if stats[obj[:assignee]][:max_shift].nil? || obj[:length] > stats[obj[:assignee]][:max_shift]
          stats[obj[:assignee]][:max_shift] = obj[:length]
        end
        last_assignee = obj[:assignee]
      end
      stats
    end
  end
end
