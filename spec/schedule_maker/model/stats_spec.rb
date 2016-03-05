describe ScheduleMaker::Model::Stats do
  before(:all) do
    @rotations = ScheduleMaker::Spec.load_rotation
    @start = ScheduleMaker::Util.dateparse('2016-01-01T00:00:00')
    @schedule = ScheduleMaker::Schedule.new(@rotations['mixed_format'], start: @start, rotation_count: 1)
    @stats = ScheduleMaker::Model::Stats.new(@schedule)
  end

  describe '#new' do
    it 'Should provide sufficient information to render the ERB' do
      expect { ScheduleMaker::Util.render_erb('stats/individual_stats', @stats) }.not_to raise_error
      expect { ScheduleMaker::Util.render_erb('stats/summary_stats', @stats) }.not_to raise_error
      erb = ScheduleMaker::Util.render_erb('spec/schedule_maker/model/stats', @stats)
      expect(erb).to match(/## apple: 4, 3;9;4, 96 ##/)
      expect(erb).to match(/## target_spacings: 1,2,4 ##/)
      expect(erb).to match(/## valid_shift_lengths: 1,2,4 ##/)
      expect(erb).to match(/## sked_size: 22 ##/)
      expect(erb).to match(/## sked: 2016-01-01T00:00:00\+00:00; 2016-01-02T00:00:00\+00:00; apple ##/)
    end
  end

  describe '#percentage' do
    it 'Should be able to do math' do
      expect(ScheduleMaker::Model::Stats.percentage(0, 1)).to eq('0.00%')
      expect(ScheduleMaker::Model::Stats.percentage(1, 1)).to eq('100.00%')
      expect(ScheduleMaker::Model::Stats.percentage(1, 2)).to eq('50.00%')
      expect(ScheduleMaker::Model::Stats.percentage(2, 1)).to eq('200.00%')
    end

    it 'Should handle floats in addition to integers' do
      expect(ScheduleMaker::Model::Stats.percentage(0.5, 1)).to eq('50.00%')
      expect(ScheduleMaker::Model::Stats.percentage(3, 1.5)).to eq('200.00%')
      expect(ScheduleMaker::Model::Stats.percentage(0.5, 2.5)).to eq('20.00%')
    end

    it 'Should return 0% if dividing by zero' do
      expect(ScheduleMaker::Model::Stats.percentage(1, 0)).to eq('0.00%')
      expect(ScheduleMaker::Model::Stats.percentage(1, 0.0)).to eq('0.00%')
      expect(ScheduleMaker::Model::Stats.percentage(1.0, 0)).to eq('0.00%')
      expect(ScheduleMaker::Model::Stats.percentage(1.0, 0.0)).to eq('0.00%')
    end
  end
end
