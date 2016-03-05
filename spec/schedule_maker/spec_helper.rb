require_relative '../../lib/schedule_maker'
require 'yaml'

module ScheduleMaker
  class Spec
    def self.load_rotation
      rotation_file = File.join(File.expand_path('../..', __FILE__), 'fixture', 'rotation.yaml')
      YAML.load_file(rotation_file)
    end

    def self.load_schedule
      rotation_file = File.join(File.expand_path('../..', __FILE__), 'fixture', 'schedule.yaml')
      YAML.load_file(rotation_file)
    end

    def self.create_schedule(schedule)
      raise "Invalid schedule (#{schedule.class} => #{schedule.inspect})" unless schedule.is_a?(Array)
      result = []
      schedule.each do |period|
        result << ScheduleMaker::Period.new(period.keys[0], period.values[0])
      end
      result
    end

    def self.include_shift_for(rotation, participant)
      rotation.each do |period|
        return true if period.participant == participant
      end
      false
    end
  end
end