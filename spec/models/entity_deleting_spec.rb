require 'rails_helper'

describe 'Deleting an Entity', type: :model do
  let(:tags) { { oil: create(:oil_tag), nyc: create(:nyc_tag) } }

  describe 'Deleting an entity with tags' do
    let(:entity) do
      entity = create(:entity_org)
      entity.tag('oil')
      entity.tag('nyc')
      entity
    end

    with_versioning do
      before { tags }

      it 'saves tags on paper trail version' do
        entity.soft_delete
        version = Entity.unscoped.find(entity.id).versions.last
        expect(YAML.load(version.association_data)['tags']).to eql %w(oil nyc)
      end

      it 'deletes the taggings' do
        entity
        expect { entity.soft_delete }.to change { Tagging.count }.by(-2)
      end
    end
  end

  describe 'restore!' do
    with_versioning do
      let(:entity) { create(:entity_org) }

      let(:business_academic) do
        tags
        person = create(:entity_person) #, last_user_id: APP_CONFIG['system_user_id'])
        person.aliases.create!(name: Faker::TwinPeaks.character)
        person.add_extension('BusinessPerson')
        person.add_extension('Academic')
        person.tag('oil')
        person.tag('nyc')
        person.images.create!(filename: Faker::File.file_name(nil, nil,'png'), title: 'image')
        person
      end

      it 'raises error if entity is not deleted' do
        expect { build(:entity_org, is_deleted: false).restore! }.to raise_error(Exceptions::CannotRestoreError)
      end

      it 'reverts is_deleted state' do
        entity
        expect { entity.soft_delete }.to change { entity.is_deleted }.to(true)
        expect { entity.restore! }.to change { entity.is_deleted }.to(false)
      end

      context 'extensions' do
        before do
          business_academic.soft_delete
          business_academic.reload
        end

        it 're-creates extension_models' do
          expect(business_academic.business_person).to be nil
          business_academic.restore!
          expect(business_academic.business_person).to be_a BusinessPerson
        end

        it 're-creates extension_records' do
          expect(business_academic.extension_records.length).to be_zero
          business_academic.restore!
          expect(business_academic.reload.extension_records.length).to eql 3

          [1, 29, 31].each do |definition_id|
            expect(business_academic.extension_records.map(&:definition_id)).to include definition_id
          end
        end
      end

      it "restores it's images" do
        business_academic
        expect { business_academic.soft_delete }.to change { Image.count }.by(-1)
        expect { business_academic.restore! }.to change { Image.count }.by(1)
      end

      it 're-creates aliases' do
        business_academic
        alias_name = business_academic.aliases.where(is_primary: false).first.name
        expect { business_academic.soft_delete }.to change { Alias.count }.by(-2)
        expect { business_academic.restore! }.to change { Alias.count }.by(2)
        expect(business_academic.reload.primary_alias.name).to eql business_academic.name
        expect(business_academic.aliases.where(is_primary: false).first.name).to eql alias_name
      end

      it "re-creates the entity's taggings" do
        business_academic
        expect { business_academic.soft_delete }.to change { Tagging.count }.by(-2)
        expect { business_academic.restore! }.to change  { Tagging.count }.by(2)
      end

      it "restores the entity's relationships" do
        business_academic
        rel = Relationship.create!(entity: entity, related: business_academic, category_id: Relationship::GENERIC_CATEGORY)

        expect { business_academic.soft_delete }
          .to change { Relationship.unscoped.find(rel.id).is_deleted }.to(true)

        expect { business_academic.restore!(true) }
          .to change { Relationship.unscoped.find(rel.id).is_deleted }.to(false)
      end

      it "does not restore the entity's relationships" do
        business_academic
        rel = Relationship.create!(entity: entity, related: business_academic, category_id: Relationship::GENERIC_CATEGORY)

        expect { business_academic.soft_delete }
          .to change { Relationship.unscoped.find(rel.id).is_deleted }.to(true)

        expect { business_academic.restore! }
          .not_to change { Relationship.unscoped.find(rel.id).is_deleted }
      end

      it "raises error if missing association data" do
        business_academic.soft_delete
        business_academic.versions.last.update_column(:association_data, nil)
        expect { business_academic.restore! }
          .to raise_error(Exceptions::MissingEntityAssociationDataError)
      end
    end
  end
end