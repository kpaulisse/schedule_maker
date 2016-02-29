# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker
  class Util
    # Select a random element given probabilities
    # -------------------------------------------
    def self.randomelement(array_in)
      x = -1
      x = rand while x < 1/(array_in.size + 1)
      array_index = (1/x).to_i - 1
      array_index = 0 if array_index < 0 || array_index >= array_in.size
      array_in[array_index]
    end



  end
end
