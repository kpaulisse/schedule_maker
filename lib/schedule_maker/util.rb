# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

require 'date'
require 'erb'
require 'tzinfo'

module ScheduleMaker
  # Some static methods that are generally useful.
  class Util
    # Select a random element from an array given probabilities. Pass in an ordered
    # array in the order from most to least likely.
    # - The first element has ~1/2 chance
    # - The second element has ~1/6 chance (1/2 - 1/3)
    # - The third has ~1/12 chance (1/3 - 1/4)
    # - ...
    # The probabilities aren't exactly as stated, because there is a probability
    # that the random number will be out of range and resampling will occur.
    #
    # @param array_in [Array<Object>] The array from which to choose an element at random
    # @return [Object] A randomly selected element from the array (or nil if array was empty)
    def self.randomelement(array_in)
      # Array validation
      raise ArgumentError, "First argument must be array, you gave #{array_in.class}" unless array_in.is_a?(Array)
      return nil if array_in.empty?
      return array_in[0] if array_in.size == 1

      # Random element choice
      x = -1
      x = rand while x < 1 / (array_in.size + 1)
      array_index = (1 / x).to_i - 1
      array_index = 0 if array_index < 0 || array_index >= array_in.size
      array_in[array_index]
    end

    # Get an element from a hash either by its name or symbol
    # @param hash_in [Hash<>] Hash to inspect
    # @param key [Symbol] Key to retrieve
    def self.get_element_from_hash(hash_in, key, default = nil)
      return default unless hash_in.is_a?(Hash)
      return hash_in[key] if hash_in.key?(key)
      return hash_in[key.to_s] if hash_in.key?(key.to_s)
      default
    end

    # Get the date/time object corresponding to midnight today
    def self.midnight_today
      now = DateTime.now
      DateTime.new(now.year, now.month, now.day)
    end

    # Parse date string
    # @param date_in [String] Date in the format XXXX-XX-XXTXX:XX:XX
    # @param timezone [String] Time zone to return object in (assuming date_in is UTC)
    # @return DateTime object
    def self.dateparse(date_in, timezone = nil)
      return offset_tz(date_in, timezone) if date_in.is_a?(DateTime)
      raise ArgumentError, 'Date string cannot be nil' if date_in.nil?
      raise ArgumentError, 'Date expects string' unless date_in.is_a?(String)
      raise ArgumentError, 'Date expects format XXXX-XX-XXTXX:XX:XX' unless date_in =~ /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})/
      offset_tz(DateTime.parse("#{date_in}+00:00"), timezone)
    end

    # Offset timezone
    def self.offset_tz(date_in, timezone = nil)
      return date_in if timezone.nil?
      offset = TZInfo::Timezone.get(timezone).current_period.utc_total_offset / (24.0 * 60 * 60)
      date_in.new_offset(offset)
    end

    # Render ERB
    # @param filename [String] Filename (minus .erb extension) in the ERB templates directory
    # @param obj [Object] Object to use when rendering ERB
    # @param prefix [String] Optional prefix for each rendered line (useful to comment stuff out)
    def self.render_erb(filename, obj, prefix = '')
      template_dir = File.join(File.expand_path('../../..', __FILE__), 'templates')
      raise "Bad ERB template directory (#{template_dir})" unless File.directory?(template_dir)
      file_path = File.join(template_dir, filename + '.erb')
      raise "Bad ERB template filename (#{file_path})" unless File.file?(file_path)
      text = ERB.new(File.read(file_path), nil, '-').result(obj.getbinding)
      return text if prefix.empty?
      text.split("\n").map { |line| prefix + line + "\n" }.join('')
    end

    # Load a rotation from a YAML file
    # @param filepath [String] Full path to file to load
    # @param valid_shift_lengths [Array<Fixnum>] Valid shift lengths to validate
    # @return [Hash] An array of participants
    def self.load_rotation_from_yaml(filepath, valid_shift_lengths = [])
      rotation = {}
      participants = YAML.load_file(filepath)
      participants.keys.each do |participant|
        participant_value = participants[participant]
        if participant_value.is_a?(Fixnum)
          unless valid_shift_lengths.empty? || valid_shift_lengths.include?(participant_value)
            raise "Invalid shift length '#{participant_value}' for #{participant}"
          end
          rotation[participant] = { 'period_length' => participant_value }
        elsif participant_value.is_a?(Hash)
          raise "Configuration for #{participant} missing period_length" unless participant_value.key?('period_length')
          period_length = participant_value['period_length']
          unless valid_shift_lengths.empty? || valid_shift_lengths.include?(period_length)
            raise "Invalid shift length '#{period_length}' for #{participant}"
          end
          rotation[participant] = { 'period_length' => period_length }
          if participant_value.key?('start')
            raise "Please quote the start time for #{participant}" unless participant_value['start'].is_a?(String)
            rotation[participant]['start'] = ScheduleMaker::Util.dateparse(participant_value['start'])
          end
          if participant_value.key?('timezone')
            raise "Please quote the timezone for #{participant}" unless participant_value['timezone'].is_a?(String)
            rotation[participant]['timezone'] = participant_value['timezone']
          end
        else
          raise "Invalid entry for #{participant} (#{participant_value.class})"
        end
      end
      rotation
    end
  end
end
