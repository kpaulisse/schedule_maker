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
    def self.stats(schedule, start, participants = {})
      stats = {}
      last_assignee = nil
      sked = schedule.as_schedule(start)

      timezones = {}
      participants.each do |key, val|
        timezones[key] = ScheduleMaker::Util.get_element_from_hash(val, :timezone, 'UTC')
      end

      sked.each do |obj|
        stats[obj[:assignee]] ||= {
          days: 0, shifts: 0, spacing: [], min_shift: nil, max_shift: nil,
          sunday: 0, monday: 0, tuesday: 0, wednesday: 0, thursday: 0, friday: 0, saturday: 0,
          weekend: 0, weekday: 0
        }

        timezone = timezones.key?(obj[:assignee]) ? timezones[obj[:assignee]] : 'UTC'
        start_time = ScheduleMaker::Util.dateparse(obj[:start], timezone)
        end_time = ScheduleMaker::Util.dateparse(obj[:end], timezone)
        weekdays_seen = {}
        0.upto((24 * (end_time - start_time).to_f).to_i - 1) do |index|
          wday = (start_time + index * (1/24.0) + 0.00000001).wday
          weekdays_seen[wday] ||= 0
          weekdays_seen[wday] += 1
        end
        weekdays_seen.keys.each do |day_of_week|
          c = weekdays_seen[day_of_week]
          stats[obj[:assignee]][[:sunday, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday][day_of_week]] += c
          stats[obj[:assignee]][:weekday] += c if day_of_week >= 1 && day_of_week <= 5
          stats[obj[:assignee]][:weekend] += c if day_of_week == 0 || day_of_week == 6
        end

        stats[obj[:assignee]][:days] += 1
        stats[obj[:assignee]][:shifts] += 1 if last_assignee != obj[:assignee]
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
