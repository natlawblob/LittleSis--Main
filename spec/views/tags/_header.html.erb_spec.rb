require 'rails_helper'

describe 'partial: tags/header', :type => :view do
  let(:tag) { build(:tag) }
  let(:active_tab) { :entities }

  before(:each) do
    render partial: 'tags/header.html.erb', locals: { tag: tag, active_tab: active_tab }
  end

  it 'contains correct tabs: all tagable classes and edits' do
    css 'ul.nav-tabs li', count: Tagable.categories.count + 1
    (Tagable.categories + [:edits]). each { |tab| css "\#tag-nav-tab-#{tab}" }
  end

  context 'lists tab is active' do
    let(:active_tab) { :lists }

    it 'sets correct active/inactive classes' do
      css 'li#tag-nav-tab-lists a.active', count: 1
      not_css 'li#tag-nav-tab-lists a.inactive'
      css 'li#tag-nav-tab-entities a.inactive'
    end
  end

  context 'edits tab is active' do
    let(:active_tab) { :edits }

    it 'sets correct active/inactive classes' do
      css 'li#tag-nav-tab-edits a.active', count: 1
      not_css 'li#tag-nav-tab-edits a.inactive'
      css 'li#tag-nav-tab-entities a.inactive'
    end
  end
end
