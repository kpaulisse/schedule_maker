# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

require 'date'

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
    # @return DateTime object
    def self.dateparse(date_in)
      return date_in if date_in.is_a?(DateTime)
      raise ArgumentError, 'Date string cannot be nil' if date_in.nil?
      raise ArgumentError, 'Date expects string' unless date_in.is_a?(String)
      raise ArgumentError, 'Date expects format XXXX-XX-XXTXX:XX:XX' unless date_in =~ /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})/
      DateTime.parse("#{date_in}+00:00")
    end
  end
end
