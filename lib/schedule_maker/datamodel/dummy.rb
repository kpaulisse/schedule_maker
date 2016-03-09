# Copyright (c) 2016 Kevin Paulisse
#
# schedule_maker is freely distributable under the terms of Apache 2.0 license.
# http://www.apache.org/licenses/LICENSE-2.0
#
# Find the source code, report issues, and contribute at:
# https://github.com/kpaulisse/schedule_maker

module ScheduleMaker
  module DataModel
    # This class is a dummy data model that can be used in spec tests, or as a template
    # for creating additional data models.
    class Dummy
      attr_accessor :violations

      # Constructor
      # @param options [Hash] Global options
      def initialize(options = {})
        apply_ruleset(options)
        @pain_override = nil
      end

      # Apply rule set - takes a hash of rules and updates @ruleset. Convention is that passing
      # in a key set to nil will delete that key, and passing in anything else will set that key.
      # You may have to modify this if you do more than a simple key-value store as your rule set.
      # @param options [Hash] Definition of rule set
      def apply_ruleset(options)
        @ruleset ||= {}
        options.each do |key, val|
          if val.nil?
            @ruleset.delete(key)
          else
            @ruleset[key] = val
          end
        end
      end

      # Calculate the pain for each participant. By convention the object in the result
      # is a hash that contains *at least* the following key:
      #   :score [Float]  => Pain score; the optimizer will try to reduce this
      #
      # @param rotation [ScheduleMaker::Rotation] Rotation object
      # @param options [Hash] Options to override global options
      # @result [Hash<Participant,Object>] Pain score for each participant
      def pain(rotation, _options_in = {})
        return @pain_override unless @pain_override.nil?
        result = {}
        rotation.rotation.each do |period|
          result[period.participant] ||= { score: 0 }
          # Do something to calculate the score here and
          # adjust result[period.participant][:score] accordingly
        end
        result
      end

      # Validate the rotation under the rules. This returns a boolean, true if the rotation is
      # valid, and false if it is not. In addition, you can provide an array of violations back
      # to the rotation object for further troubleshooting or reporting.
      #
      # By convention the violations is an array of hashes:
      # violations = [ { participant: 'Some participant', error: 'Your error message' } ]
      #
      # @param rotation [ScheduleMaker::Rotation] The rotation
      # @param options [Hash] Options
      # @return [Boolean] true if rotation is valid, false if not
      def valid?(rotation, options = nil)
        violations = []
        options = @global_options.merge(options_in)

        # Do something to populate violations if something has gone wrong
        if options.key?(:violation)
          violations << {
            participant: rotation.participants.keys[0],
            error: "Dummy violation: #{options[:violation]}"
          }
        end

        # Set violations in rotation object for later debugging
        rotation.set_violations(self.class.to_s, violations)

        # Return boolean
        violations.empty?
      end

      # Override pain array - FOR USE IN SPEC TESTING ONLY
      def override_pain_from_a_spec_test_only(pain)
        @pain_override = pain
      end
    end
  end
end
