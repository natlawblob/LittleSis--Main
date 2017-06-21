require 'rails_helper'

describe Person do
  it { should belong_to(:entity) }

  describe 'validations' do
    it { should validate_presence_of(:name_last) }
    it { should validate_presence_of(:name_first) }
    it { should validate_length_of(:name_last).is_at_most(50) }
    it { should validate_length_of(:name_last).is_at_most(50) }
  end

  describe 'titleize_names' do
    let(:the_reverend) { build(:a_person,
                               name_first: 'first',
                               name_last: 'last',
                               name_middle: 'middle',
                               name_suffix: 'II',
                               name_prefix: 'rev.',
                               name_nick: 'the rev') }
                           
    it 'titleizes first and last names' do
      rev = the_reverend
      rev.titleize_names
      expect(rev.name_first).to eq 'First'
      expect(rev.name_last).to eq 'Last'
    end

    it 'titleizes middle and nick name' do
      rev = the_reverend
      rev.titleize_names
      expect(rev.name_middle).to eq 'Middle'
      expect(rev.name_nick).to eq 'The rev'
    end
  end


  describe '#gender' do
    it 'returns correct gender for female, male, & other' do
      expect(build(:a_person, gender_id: 1).gender).to eq 'Female'
      expect(build(:a_person, gender_id: 2).gender).to eq 'Male'
      expect(build(:a_person, gender_id: 3).gender).to eq 'Other'
      expect(build(:a_person, gender_id: nil).gender).to be nil
    end
  end
end
