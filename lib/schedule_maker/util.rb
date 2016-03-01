# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker
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
  end
end
