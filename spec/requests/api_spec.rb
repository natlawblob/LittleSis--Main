require 'rails_helper'

describe Api, :pagination_helper do
  before(:all) do
    @user = create_really_basic_user
    @api_token = @user.create_api_token!
    @auth_header = { 'Littlesis-Api-Token': @api_token.token }
  end

  after(:all) do
    @user.sf_guard_user.delete
    @user.delete
    @api_token.delete
  end

  let(:meta) { Api::META }

  describe 'entities' do
    let(:lawyer) do
      create(:entity_person).tap { |e| e.add_extension('Lawyer') }
    end

    let(:expected) do
      {
        'data' => {
          'type' => 'entities',
          'id' => lawyer.id,
          'attributes' => {
            'id' => lawyer.id,
            'name' => lawyer.name,
            'blurb' => lawyer.blurb,
            'primary_ext' => 'Person',
            'summary' => lawyer.summary,
            'parent_id' => nil,
            'website' => lawyer.website,
            'start_date' => lawyer.start_date,
            'end_date' => lawyer.end_date,
            'types' => %w[Person Lawyer],
            'aliases' => lawyer.aliases.map(&:name),
            'updated_at' => lawyer.updated_at.iso8601
          },
          'links' => { 'self' => Rails.application.routes.url_helpers.entity_url(lawyer) }
        },
        'meta' => meta
      }
    end

    describe 'entity information /entities/:id' do
      before { get api_entity_path(lawyer), headers: @auth_header }
      specify { expect(response).to have_http_status 200 }
      specify { expect(json).to eql(expected) }
    end

    describe 'request for details: /entities/:id?details=true' do
      let(:with_details) do
        expected.deep_merge('data' => { 'attributes' => {
                                          'extensions' => {
                                            "Person" => {
                                              "name_last" => "Being",
                                              "name_first" => "Human",
                                              "name_middle" => nil,
                                              "name_prefix" => nil,
                                              "name_suffix" => nil,
                                              "name_nick" => nil,
                                              "birthplace" => nil,
                                              "gender_id" => nil,
                                              "party_id" => nil,
                                              "is_independent" => nil,
                                              "net_worth" => nil,
                                              "nationality" => [],
                                              "name_maiden" => nil
                                            } } } }) # rubocop:disable Layout/MultilineHashBraceLayout
      end
      before { get api_entity_path(lawyer), params: { 'details' => 'true' }, headers: @auth_header }
      specify { expect(response).to have_http_status 200 }
      specify { expect(json).to eql(with_details) }
    end

    describe 'record not found' do
      before { get api_entity_path(id: 1_000_000), headers: @auth_header }
      specify { expect(response).to have_http_status 404 }
      specify do
        expect(json).to eql('errors' => [{ 'title' => 'Record Missing' }],
                            'meta' => meta)
      end
    end

    describe 'record deleted' do
      before do
        deleted_pac = create(:pac, is_deleted: true)
        get api_entity_path(deleted_pac), headers: @auth_header
      end
      specify { expect(response).to have_http_status 410 }
      specify do
        expect(json).to eql('errors' => [{ 'title' => 'Record Deleted' }],
                            'meta' => meta)
      end
    end
  end # end describe entiites

  describe '/entities/:id/extensions' do
    let(:entity) { create(:entity_org).tap { |e| e.add_extension('PoliticalFundraising') } }
    let(:expected) do
      {
        'data' => [
          {
            'type' => 'extension-records',
            'id' => entity.extension_records.first.id,
            'attributes' => {
              "id" => entity.extension_records.first.id,
              "definition_id" => 2,
              "display_name" => "Organization",
              "name" => "Org"
            }
          },
          {
            'type' => 'extension-records',
            'id' => entity.extension_records.second.id,
            'attributes' => {
              'id' => entity.extension_records.second.id,
              "definition_id" => 11,
              "display_name" => "Political Fundraising Committee",
              "name" => "PoliticalFundraising"
            }
          }
        ],
        'meta' => meta
      }
    end

    before { get extensions_api_entity_path(entity), headers: @auth_header }
    specify { expect(response).to have_http_status 200 }
    specify { expect(json).to eql(expected) }
  end

  describe '/entities/:id/lists' do
    let(:entity) { create(:entity_person) }
    let(:lists) { Array.new(2) { create(:list) } }

    context 'entity with 2 lists' do
      before do
        lists.each { |l| ListEntity.create!(list_id: l.id, entity_id: entity.id) }
        get lists_api_entity_path(entity), headers: @auth_header
      end
      specify { expect(response).to have_http_status 200 }
      specify { expect(truncate_updated_at(json['data'])).to eql(truncate_updated_at(lists.map(&:api_data))) }
    end

    context 'entity with no lists' do
      before { get lists_api_entity_path(entity), headers: @auth_header }
      specify { expect(json).to eql('meta' => meta, 'data' => []) }
    end

    context 'entity with one open list and one private list' do
      let(:lists) { [create(:open_list), create(:private_list)] }
      before do
        lists.each { |l| ListEntity.create!(list_id: l.id, entity_id: entity.id) }
        get lists_api_entity_path(entity), headers: @auth_header
      end
      specify { expect(response).to have_http_status 200 }
      specify { expect(json['data']).to eql [lists.first.api_data] }
    end
  end

  describe '/entities/:id/relationships' do
    let!(:entity) { create(:entity_person) }
    subject { json }

    context 'request without page' do
      let!(:relationships) do
        Array.new(2) do
          create(:generic_relationship, entity: entity, related: create(:entity_person))
        end
      end
      before { get relationships_api_entity_path(entity), headers: @auth_header }
      specify { expect(response).to have_http_status 200 }
      specify do
        expect(json['meta']).to eql(meta.merge('pageCount' => 1, 'currentPage' => 1))
        expect(json['data'].to_set).to eql relationships.map(&:api_data).to_set
      end
    end

    context 'limiting to category type' do

      before do
        create(:position_relationship, entity: entity, related: create(:entity_org))
        create(:generic_relationship, entity: entity, related: create(:entity_org))
      end

      it 'returns error if requesting an invalid category' do
        get relationships_api_entity_path(entity), params: { category_id: '13' }, headers: @auth_header
        expect(response).to have_http_status 400
        expect(json).to have_key 'errors'
      end

      it 'returns two relationships by default' do
        get relationships_api_entity_path(entity), headers: @auth_header
        expect(response).to have_http_status 200
        expect(json['data'].length).to eql 2
      end

      it 'returns one relationships when a specific category is requested' do
        get relationships_api_entity_path(entity), params: { category_id: '1' }, headers: @auth_header
        expect(response).to have_http_status 200
        expect(json['data'].length).to eql 1
      end

      it 'returns zero relationships when a category without any relatinoships is selection' do
        get relationships_api_entity_path(entity), params: { category_id: '3' }, headers: @auth_header
        expect(response).to have_http_status 200
        expect(json['data'].length).to eql 0
      end
    end

    context 'pagination' do
      stub_page_limit Api::ApiController, limit: 2

      let!(:relationships) do
        Array.new(3) do |n|
          create(:generic_relationship, entity: entity, related: create(:entity_person)).tap do |r|
            r.update_column(:updated_at, n.days.ago)
          end
        end
      end

      let(:get_request) do
        proc do |page|
          get relationships_api_entity_path(entity), params: { page: page }, headers: @auth_header
        end
      end

      context 'requesting first page' do
        before { get_request.call(1) }
        specify { expect(response).to have_http_status 200 }
        specify { expect(json['data'].length).to eql 2 }

        it do
          is_expected.to eql('meta' => meta.merge('pageCount' => 2, 'currentPage' => 1),
                             'data' => relationships.first(2).map(&:api_data))
        end
      end

      context 'requesting second page' do
        before { get_request.call(2) }
        specify { expect(response).to have_http_status 200 }
        specify { expect(json['data'].length).to eql 1 }

        it do
          is_expected.to eql('meta' => meta.merge('pageCount' => 2, 'currentPage' => 2),
                             'data' => relationships.last(1).map(&:api_data))
        end
      end
    end

    
  end

  describe '/entities/search?q=NAME' do
    let(:entities) { TestSphinxResponse.new([build(:org), build(:person)]) }
    let(:mock_search) { double(:per => double(:page => entities)) }

    class TestSphinxResponse < Array
      def is_a?(klass)
        return true if klass == ThinkingSphinx::Search
        false
      end
      define_method(:current_page) { 1 }
      define_method(:total_pages) { 2 }
    end

    context 'missing param name' do
      before { get api_entities_search_path, headers: @auth_header }
      specify { expect(response).to have_http_status 400 }
    end

    context 'submission with param name' do
      before do
        expect(Entity::Search).to receive(:search).and_return(mock_search)
        get api_entities_search_path, params: { q: 'entity name' }, headers: @auth_header
      end

      specify { expect(response).to have_http_status 200 }
      specify { expect(json['data']).to be_a Array }
      specify { expect(json['data'].length).to eql 2 }
      specify do
        expect(json['meta'])
          .to eql('copyright' => Api::META['copyright'],
                  'license' => Api::META['license'],
                  'apiVersion' => Api::META['apiVersion'],
                  'currentPage' => 1,
                  'pageCount' => 2)
      end
    end
  end

  describe '/relationships/:id' do
    let(:entity1) { create(:entity_person) }
    let(:entity2) { create(:entity_org) }
    let(:relationship) { Relationship.create!(category_id: 1, entity: entity1, related: entity2) }

    before { get api_relationship_path(relationship), headers: @auth_header }

    specify { expect(response).to have_http_status 200 }
    specify do
      expect(json).to eql('data' => relationship.api_data,
                          'meta' => meta,
                          'included' => [entity1.api_data(exclude: :extensions), entity2.api_data(exclude: :extensions)])
    end
  end
end
