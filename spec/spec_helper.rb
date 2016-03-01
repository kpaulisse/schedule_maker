require_relative '../lib/schedule_maker'
require 'yaml'

module ScheduleMaker
  class Spec
    def self.load_rotation
      rotation_file = File.join(File.dirname(__FILE__), 'fixture', 'rotation.yaml')
      YAML.load_file(rotation_file)
    end

    def self.load_schedule
      rotation_file = File.join(File.dirname(__FILE__), 'fixture', 'schedule.yaml')
      YAML.load_file(rotation_file)
    end

    def self.create_schedule(schedule)
      result = []
      schedule.each do |period|
        result << ScheduleMaker::Period.new(period.keys[0], period.values[0])
      end
      result
    end
  end
end
