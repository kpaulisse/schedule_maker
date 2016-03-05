require_relative '../spec_helper'

describe ScheduleMaker::DataModel::Spacing do
  before(:all) do
    @rotations = ScheduleMaker::Spec.load_rotation
    @schedules = ScheduleMaker::Spec.load_schedule
    @start = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
    @testobj = ScheduleMaker::DataModel::Spacing.new
  end

  describe '#pain' do
    it 'Should correctly compute pain for a rotation with no repeats' do
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'])
      result = @testobj.pain(rotation)
      answer = { spacing: [0.0], score: 0, pain: false }
      expect(result['apple']).to eq(answer)
    end

    it 'Should correctly compute pain for a small rotation with repeats' do
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 5)
      result = @testobj.pain(rotation)
      answer = { spacing: [0.0, 0.0, 0.0, 0.0, 0.0], score: 0, pain: false }
      expect(result['apple']).to eq(answer)
    end

    it 'Should correctly compute pain for a rotation with small participant count' do
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1_point_5'], 2)
      result = @testobj.pain(rotation)
      answer_apple = { spacing: [0.0, 0.0, 0.0, 1.0], score: Math.exp(1), pain: true }
      expect(result['apple']).to eq(answer_apple)

      answer_banana = { spacing: [0.0, 1.0 / Math.sqrt(2)], score: Math.exp(1 / Math.sqrt(2)), pain: false }
      expect(result['banana']).to eq(answer_banana)
    end

    it 'Should correctly compute pain for a large rotation' do
      rotation = ScheduleMaker::Rotation.new(@rotations['variety'], 2)
      result = @testobj.pain(rotation)
      expect(result['apple'][:score].to_i).to eq(10_136_669)
      expect(result['apple'][:pain]).to be true
      expect(result['apple'][:spacing][1]).to eq(8.0)

      expect(result['nectarine'][:score].to_i).to eq(12_838)
      expect(result['nectarine'][:pain]).to be true
      expect(result['nectarine'][:spacing][2]).to eq((5.0 / 6.0) * Math.sqrt(6))
    end

    it 'Should impose a pain penalty for someone on the schedule before they are eligible' do
      start = ScheduleMaker::Util.dateparse('2016-02-01T00:00:00')
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 1, [], nil, start: start)
      rotation.override_participant_start_date_from_a_spec_test_only('apple', '2016-06-01T00:00:00')
      result = @testobj.pain(rotation)
      expect(result['apple'][:score].to_i).to eq(22_026)
      expect(result['apple'][:pain]).to be true
    end

    it 'Should take previous rotation into account when calculating pain' do
      prev = ScheduleMaker::Spec.create_schedule(@schedules['tiny_datetest_2'])
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 2, prev)
      result = @testobj.pain(rotation)
      expect(result['apple']).to eq(spacing: [1.0, 0.0], score: Math.exp(1), pain: true)
    end
  end

  describe '#valid?' do
    it 'Should accept a rotation with empty spacing arrays' do
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 5)
      pain = {
        'apple' => { spacing: [], score: 0, pain: false },
        'banana' => { spacing: [], score: 0, pain: false }
      }
      obj = @testobj.dup
      obj.override_pain_from_a_spec_test_only(pain)
      result = obj.valid?(rotation)
      expect(result).to be true
    end

    it 'Should accept a rotation with zeroes in spacing arrays' do
      rotation = ScheduleMaker::Rotation.new(@rotations['simple_1'], 5)
      result = @testobj.valid?(rotation)
      expect(result).to be true
    end

    it 'Should accept a valid rotation' do
      rotation = ScheduleMaker::Rotation.new(@rotations['small'], 3)
      pain = {
        'apple' => { spacing: [0.0, 1.0, 1.0], score: 2 * Math.exp(1), pain: false },
        'banana' => { spacing: [0.0, 1.0, 1.0], score: 2 * Math.exp(1), pain: false }
      }
      obj = @testobj.dup
      obj.override_pain_from_a_spec_test_only(pain)
      result = obj.valid?(rotation)
      expect(result).to be true
    end

    it 'Should accept a valid rotation with minimal pain' do
      rotation = ScheduleMaker::Rotation.new(@rotations['small'], 3)
      pain = {
        'apple' => { spacing: [0.0, 1.0, 2.0], score: Math.exp(1) + Math.exp(2), pain: true },
        'banana' => { spacing: [0.0, 1.0, 2.0], score: Math.exp(1) + Math.exp(2), pain: true }
      }
      obj = @testobj.dup
      obj.override_pain_from_a_spec_test_only(pain)
      result = obj.valid?(rotation)
      expect(result).to be true
    end

    it 'Should reject an invalid rotation with too much cumulative pain' do
      rotation = ScheduleMaker::Rotation.new(@rotations['small'], 3)
      pain = {
        'apple' => { spacing: [0.0, 2.0, 2.0], score: 2 * Math.exp(2), pain: true },
        'banana' => { spacing: [0.0, 2.0, 2.0], score: 2 * Math.exp(2), pain: true }
      }
      obj = @testobj.dup
      obj.override_pain_from_a_spec_test_only(pain)
      result = obj.valid?(rotation)
      expect(result).to be false
    end

    it 'Should reject an invalid rotation with one really bad pain score' do
      rotation = ScheduleMaker::Rotation.new(@rotations['small'], 3)
      pain = {
        'apple' => { spacing: [0.0, 0.0, 0.0], score: 0, pain: false },
        'banana' => { spacing: [0.0, 0.0, 3.0], score: Math.exp(3), pain: true }
      }
      obj = @testobj.dup
      obj.override_pain_from_a_spec_test_only(pain)
      result = obj.valid?(rotation)
      expect(result).to be false
    end

    it 'Should account for shift lengths when analyzing spacing' do
      rotation = ScheduleMaker::Rotation.new(@rotations['variety'])
      pain = {}
      pain['jalapeno'] = { spacing: [0.0, 2.0, 2.0], score: 2 * Math.exp(1), pain: true }
      obj = @testobj.dup
      obj.override_pain_from_a_spec_test_only(pain)
      expect(obj.valid?(rotation)).to be true

      pain['plum'] = { spacing: [0.0, 3.0, 3.0], score: 2 * Math.exp(3.0 / Math.sqrt(10)), pain: true }
      obj = @testobj.dup
      obj.override_pain_from_a_spec_test_only(pain)
      expect(obj.valid?(rotation)).to be true

      pain['plum'] = { spacing: [0.0, 4.0, 4.0], score: 2 * Math.exp(4.0 / Math.sqrt(10)), pain: true }
      obj = @testobj.dup
      obj.override_pain_from_a_spec_test_only(pain)
      expect(obj.valid?(rotation)).to be false
    end

    it 'Should return invalid when pain score exceeds key in threshold' do
      rotation = ScheduleMaker::Rotation.new(@rotations['variety'])
      pain = { 'jalapeno' => { spacing: [0.0, 2.0, 2.0], score: 2 * Math.exp(1), pain: true } }
      ruleset = { threshold: { 1 => { max_count: 1 } } }
      obj = @testobj.dup
      obj.override_pain_from_a_spec_test_only(pain)
      obj.apply_ruleset(ruleset)
      expect(obj.valid?(rotation)).to be false
    end

    it 'Should return valid when pain score does not exceed key in threshold' do
      rotation = ScheduleMaker::Rotation.new(@rotations['variety'])
      pain = { 'jalapeno' => { spacing: [0.0, 2.0, 2.0], score: 2 * Math.exp(1), pain: true } }
      ruleset = { threshold: { 4 => { max_count: 1 } } }
      obj = @testobj.dup
      obj.override_pain_from_a_spec_test_only(pain)
      obj.apply_ruleset(ruleset)
      expect(obj.valid?(rotation)).to be true
    end

    it 'Should respect absolute count for shift length = 1' do
      rotation = ScheduleMaker::Rotation.new(@rotations['variety'])
      pain = { 'apple' => { spacing: [0.0, 2.0, 2.0], score: 2 * Math.exp(1), pain: true } }
      obj = @testobj.dup
      obj.override_pain_from_a_spec_test_only(pain)

      ruleset = { threshold: { 1 => { max_count: 2 }, 4 => { max_count: 1 } } }
      obj.apply_ruleset(ruleset)
      expect(obj.valid?(rotation)).to be true

      ruleset = { threshold: { 2 => { max_count: 2 }, 4 => { max_count: 1 } } }
      obj.apply_ruleset(ruleset)
      expect(obj.valid?(rotation)).to be false
    end

    it 'Should respect absolute count for shift length > 1' do
      rotation = ScheduleMaker::Rotation.new(@rotations['variety'])
      pain = { 'jalapeno' => { spacing: [0.0, 2.0, 2.0], score: 2 * Math.exp(1), pain: true } }
      obj = @testobj.dup
      obj.override_pain_from_a_spec_test_only(pain)

      ruleset = { threshold: { 1 => { max_count: 2 }, 2 => nil, 4 => { max_count: 1 } } }
      obj.apply_ruleset(ruleset)
      expect(obj.valid?(rotation)).to be false

      ruleset = { threshold: { 1 => nil, 2 => { max_count: 2 }, 4 => { max_count: 1 } } }
      obj.apply_ruleset(ruleset)
      expect(obj.valid?(rotation)).to be true
    end

    it 'Should respect percentage cutoffs based on shift count' do
      rotation = ScheduleMaker::Rotation.new(@rotations['variety'])
      pain = { 'jalapeno' => { spacing: [0.0, 2.0, 2.0], score: 2 * Math.exp(1), pain: true } }
      obj = @testobj.dup
      obj.override_pain_from_a_spec_test_only(pain)

      ruleset = { threshold: { 1 => { max_percent: 0.5 }, 4 => { max_count: 1 } } }
      obj.apply_ruleset(ruleset)
      expect(obj.valid?(rotation)).to be false

      ruleset = { threshold: { 1 => { max_percent: 0.5, max_percent_cutoff: 4 }, 4 => { max_count: 1 } } }
      obj.apply_ruleset(ruleset)
      expect(obj.valid?(rotation)).to be true
    end

    it 'Should handle cumulative score' do
      rotation = ScheduleMaker::Rotation.new(@rotations['variety'])
      pain = { 'apple' => { spacing: [1.0, 1.0, 1.0], score: 3 * Math.exp(1), pain: true } }
      obj = @testobj.dup
      obj.override_pain_from_a_spec_test_only(pain)

      ruleset = { max: 37, threshold: { 1 => { weight: 0.5 }, 4 => { max_count: 1 } } }
      obj.apply_ruleset(ruleset)
      expect(obj.valid?(rotation)).to be true

      ruleset = { max: 1, threshold: { 1 => { weight: 0.5 }, 4 => { max_count: 1 } } }
      obj.apply_ruleset(ruleset)
      expect(obj.valid?(rotation)).to be false
    end

  end
end
