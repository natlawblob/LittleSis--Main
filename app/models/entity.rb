# frozen_string_literal: true

class Entity < ApplicationRecord
  include SingularTable
  include SoftDelete
  include Referenceable
  include Political
  include Api::Serializable
  include EntityPaths
  include EntitySearch
  include Tagable
  include NetworkAnalysis
  include Pagination
  # self.default_timezone = :local
  # self.skip_time_zone_conversion_for_attributes = [:created_at, :updated_at]

  EXCERPT_SIZE = 150
  PER_PAGE = 20
  BULK_LIMIT = 10

  has_paper_trail :ignore => [:link_count, :delta, :last_user_id],
                  :on =>  [:create, :destroy, :update],
                  :meta => {
                    :association_data => proc { |e|
                      e.get_association_data.to_yaml if e.paper_trail_event == 'soft_delete'
                    }
                  }

  has_many :aliases, inverse_of: :entity, dependent: :destroy
  has_many :images, inverse_of: :entity, dependent: :destroy
  has_many :list_entities, inverse_of: :entity, dependent: :destroy
  has_many :lists, through: :list_entities
  has_many :links, foreign_key: "entity1_id", inverse_of: :entity, dependent: :destroy
  has_many :reverse_links, class_name: "Link", foreign_key: "entity2_id", inverse_of: :related, dependent: :destroy
  has_many :relationships, through: :links
  has_many :relateds, -> { distinct }, through: :links
  has_many :groups, through: :lists, inverse_of: :entities
  has_many :campaigns, through: :groups, inverse_of: :entities
  belongs_to :last_user, class_name: "SfGuardUser", foreign_key: "last_user_id", inverse_of: :edited_entities
  has_many :os_entity_transactions, inverse_of: :entity, dependent: :destroy
  has_many :os_entity_preprocesses, inverse_of: :entity, dependent: :destroy
  has_many :extension_records, inverse_of: :entity, dependent: :destroy
  has_many :extension_definitions, through: :extension_records, inverse_of: :entities
  has_many :os_entity_categories, inverse_of: :entity
  has_many :os_categories, through: :os_entity_categories, inverse_of: :entities
  has_many :entity_fields, inverse_of: :entity, dependent: :destroy
  has_many :fields, through: :entity_fields, inverse_of: :entities
  has_many :article_entities, inverse_of: :entity, dependent: :destroy
  has_many :articles, through: :article_entities, inverse_of: :entities
  has_many :queue_entities, inverse_of: :entity, dependent: :destroy

  # extensions
  has_one :person, inverse_of: :entity, dependent: :destroy
  has_one :org, inverse_of: :entity, dependent: :destroy
  has_one :couple, inverse_of: :entity, dependent: :destroy
  has_one :public_company, inverse_of: :entity, dependent: :destroy
  has_one :school, inverse_of: :entity, dependent: :destroy
  has_one :business_person, inverse_of: :entity, dependent: :destroy
  has_one :lobbyist, inverse_of: :entity, dependent: :destroy
  has_one :political_candidate, inverse_of: :entity, dependent: :destroy
  has_one :elected_representative, inverse_of: :entity, dependent: :destroy
  has_one :business, inverse_of: :entity, dependent: :destroy
  has_one :government_body, inverse_of: :entity, dependent: :destroy
  has_one :political_fundraising, inverse_of: :entity, dependent: :destroy

  ## extension nexted attributes
  accepts_nested_attributes_for :person
  accepts_nested_attributes_for :public_company
  accepts_nested_attributes_for :school

  # contact
  has_many :addresses, inverse_of: :entity, dependent: :destroy
  has_many :phones, inverse_of: :entity, dependent: :destroy
  has_many :emails, inverse_of: :entity, dependent: :destroy

  # OpenSecrets
  has_many :matched_contributions, class_name: "OsMatch", inverse_of: :donor, foreign_key: "donor_id"
  has_many :contributions, through: :matched_contributions, source: :os_donation
  has_many :donors, class_name: "OsMatch", inverse_of: :recipient, foreign_key: "recip_id"
  has_many :committee_donors, class_name: "OsMatch", inverse_of: :committee, foreign_key: "cmte_id"

  # NY Election 
  has_many :ny_filer_entities
  has_many :ny_filers, through: :ny_filer_entities

  # SCOPES
  scope :people, -> { where(primary_ext: 'Person') }
  scope :orgs, -> { where(primary_ext: 'Org') }
  scope :profile_scope, -> { includes(:aliases, list_entities: [:list]) }

  validates :primary_ext, presence: true
  validates :name, presence: true, entity_name: true
  validates :blurb, length: { maximum: 200 }
  validates :start_date, length: { maximum: 10 }, date: true
  validates :end_date, length: { maximum: 10 }, date: true

  before_validation :trim_name_whitespace, :set_last_user_id
  after_create :create_primary_alias, :create_primary_ext

  ##
  # aliases
  #

  # creates primary alias if the entity does not have one
  def create_primary_alias
    return nil if aliases.where(is_primary: true).count.positive?
    Alias.without_versioning do
      a = Alias.new(entity: self, name: name, is_primary: true, last_user_id: last_user_id)
      a.skip_update_entity_callback = true
      a.save
    end
  end

  # retrives the primary alias -> <Alias>
  def primary_alias
    aliases.find_by_is_primary(true)
  end

  def also_known_as
    aliases.where(is_primary: false).map(&:name)
  end

  ##
  # extensions
  #

  def create_primary_ext
    fields = person? ? NameParser.parse_to_hash(name) : {}
    add_extension(primary_ext, fields)
  end

  def to_param
    # return nil unless persisted?
    "#{id}-#{self.class.parameterize_name(name)}"
  end

  def person?
    primary_ext == 'Person'
  end

  def org?
    primary_ext == 'Org'
  end

  def couple?
    primary_ext == 'Couple'
  end

  def school?
    org? && has_extension?('School')
  end

  def other_ext
    person? ? 'Org' : 'Person'
  end

  def primary_extension_model
    return person if person?
    return org if org?
  end

  def all_attributes
    attributes.merge!(extension_attributes).reject { |k,v| v.nil? }
  end

  # Returns a hash of all attributes for all extensions (that have attrs) for the entity.
  # All entities will have attributes associated with 'Person' or 'Org'
  def extension_attributes
    extensions_with_attributes.values.reduce(:merge)
  end

  # Returns an array of all extension models
  def extension_models
    (extension_names & Entity.all_extension_names_with_fields).map do |name|
      name.constantize.find_by_entity_id(id)
    end
  end

  def types
    extension_definitions.map(&:display_name)
  end

  # Returns a hash where the key in each key/value pair is the extension name
  # and the value is a hash of the attributes for that extension
  def extensions_with_attributes
    extension_models.reduce({}) do |memo, model|
      memo.merge(model.class.name => model.attributes.except('id', 'entity_id') )
    end
  end

  def extension_ids
    extension_records.map(&:definition_id)
  end

  def extension_ids_without_primary
    extension_ids.delete_if { |id| id == 1 || id == 2 }
  end

  # used in the edit entities view as value for extension_definition_ids
  def extension_ids_without_primary_stringified
    extension_ids_without_primary.join(',')
  end

  # Returns array containing the name of all entity extensions (ExtensionRecord)
  # All entities will have at least one: 'Person' or 'Org
  def extension_names
    extension_ids.collect { |id| self.class.all_extension_names[id] }
  end

  def has_extension?(name_or_id)
    name_or_id_to_name(name_or_id)
    def_id = self.class.all_extension_names.index(name_or_id) if name_or_id.is_a? String
    def_id = name_or_id if name_or_id.is_a? Integer
    extension_ids.include?(def_id)
  end

  # Adds a new extension. Creates ExtensionRecord and extension model if required
  # Call with the name of the extenion model or with the definition id
  # It will not create duplicates and is safe to run multiple times with with the same value
  # Example: Entity.find(123).add_extension('Business')
  def add_extension(name_or_id, fields = {})
    name = name_or_id_to_name(name_or_id)
    fields[:entity] = self
    name.constantize.create(fields) if extension_with_fields?(name) && name.constantize.where(entity_id: id).count.zero?
    def_id = ExtensionDefinition.find_by_name(name).id
    ExtensionRecord.find_or_create_by(entity_id: id, definition_id: def_id)
    self
  end

  # Removes existing ExtensionRecord and associated model
  def remove_extension(name_or_id)
    name = name_or_id_to_name(name_or_id)
    # This func cannot be used to remove a primary extension
    raise ArgumentError if %w(None Org Person).include?(name)
    def_id = self.class.all_extension_names.index(name)
    extension_records.find_by_definition_id(def_id).try(:destroy)
    send(name.underscore).try(:destroy) if extension_with_fields?(name)
    self
  end

  # Merges extensions attribues for already existing extensions
  # This will only merge fields that are nil -- it won't update already existing fields
  # Example:
  #   If school.attributes['tuition'] => 'nil'
  #   then merge_extension('school', { tuition' => 20_000 }) will change
  #   the school tutition attribute to 20_000.
  #   However if school.attributes['tuition'] => 5_000, merge_extension('school', { tuition' => 20_000 }) will do nothing
  #   and school.attributes['tuition']  will remain at 5_000
  def merge_extension(name_or_id, fields)
    name = name_or_id_to_name(name_or_id)
    unless extension_with_fields?(name) && has_extension?(name)
      throw ArgumentError, "merge_extension can only be used with extensions that have fields"
    end
    extension = name.constantize.find_by_entity_id(id)

    update_attrs = ActiveSupport::HashWithIndifferentAccess
                          .new(fields)
                          .delete_if { |_, v| v.nil? }
                          .slice(*extension.attributes.select { |_, v| v.nil? }.keys)

    extension.update(update_attrs) unless update_attrs.empty?
    self
  end

  # Create new extension by definition ids
  # Accepts array of ids
  def add_extensions_by_def_ids(ids)
    ids.each { |def_id| add_extension(def_id) }
  end

  # Removes extensions by definition id
  def remove_extensions_by_def_ids(ids)
    ids.each { |def_id| remove_extension(def_id) }
  end

  def update_extension_records(def_ids)
    return nil unless def_ids.is_a? Array
    def_ids_to_delete = extension_ids_without_primary.delete_if { |x| def_ids.include?(x) }
    def_ids_to_create = def_ids.delete_if { |x| extension_ids_without_primary.include?(x) }
    add_extensions_by_def_ids(def_ids_to_create)
    remove_extensions_by_def_ids(def_ids_to_delete)
  end

  def self.with_exts(exts)
    ext_ids = exts.map { |ext| all_extension_names.index(ext) }.compact
    joins(:extension_records).where(extension_record: { definition_id: ext_ids })
  end

  # Names of the extensions (ExtensionDefinition) in order of their definition_id
  # Can be used as a look up table. For instance
  # Entity.all_extension_names[27] => LaborUnion
  def self.all_extension_names
    [
      'None',
      'Person',
      'Org',
      'PoliticalCandidate',
      'ElectedRepresentative',
      'Business',
      'GovernmentBody',
      'School',
      'MembershipOrg',
      'Philanthropy',
      'NonProfit',
      'PoliticalFundraising',
      'PrivateCompany',
      'PublicCompany',
      'IndustryTrade',
      'LawFirm',
      'LobbyingFirm',
      'PublicRelationsFirm',
      'IndividualCampaignCommittee',
      'Pac',
      'OtherCampaignCommittee',
      'MediaOrg',
      'ThinkTank',
      'Cultural',
      'SocialClub',
      'ProfessionalAssociation',
      'PoliticalParty',
      'LaborUnion',
      'Gse',
      'BusinessPerson',
      'Lobbyist',
      'Academic',
      'MediaPersonality',
      'ConsultingFirm',
      'PublicIntellectual',
      'PublicOfficial',
      'Lawyer',
      'Couple',
      'ResearchInstitute',
      'GovernmentAdvisoryBody',
      'EliteConsensus'
    ]
  end

  def self.all_extension_names_with_fields
    [
      'Person',
      'Org',
      'PoliticalCandidate',
      'ElectedRepresentative',
      'Business',
      'School',
      'PublicCompany',
      'GovernmentBody',
      'BusinessPerson',
      'Lobbyist',
      'PoliticalFundraising',
      'Couple'
    ]
  end

  def self.extension_with_field?(name_or_id)
    all_extension_names_with_fields.include? ext_name_or_id_to_name(name_or_id)
  end

  ##
  # images
  #
  def default_image_url
    return "/images/system/anon.png" if person?
    "/images/system/anons.png"
  end

  def has_featured_image
    images.featured.count > 0
  end

  def featured_image
    images.featured.first
  end

  def featured_image_url(type=nil)
    image = featured_image
    return default_image_url if image.nil?
    type = (image.has_square ? "square" : "profile") if type.nil?
    image.image_path(type)
  end

  def featured_image_source_url
    return nil unless image = featured_image
    image.url
  end

  def add_image_from_url(url, force_featured = false, caption = nil)
    return if images.find { |i| i.url == url }
    image = Image.new_from_url(url)
    return false unless image
    image.title = name
    image.caption = caption
    images << image
    image.feature if force_featured or !has_featured_image
    image
  end

  ##
  # interlocks
  #

  def relateds_by_count(num=5, primary_ext=nil)
    r = relateds.select("entity.*, COUNT(link.id) AS num").group("link.entity2_id").order("num DESC").limit(num)
    r.where("entity.primary_ext = ?", primary_ext) unless primary_ext.nil?
    r
  end

  def interlocks_by_count(options={}, only_count=false)
    order1 = options[:order1]
    order2 = options[:order2]
    cat1_ids = options[:cat1_ids]
    cat2_ids = options[:cat2_ids]
    ext2_ids = options[:ext2_ids]
    past1 = options[:past1]
    past2 = options[:past2]
    num = options[:num] || 20
    max_num = options[:max_num]
    page = options[:page]

    r = Link.select("link2.entity2_id AS degree2_id, GROUP_CONCAT(DISTINCT link2.entity1_id) AS degree1_ids, COUNT(DISTINCT link2.entity1_id) AS num")
      .joins("LEFT JOIN link AS link2 ON link.entity2_id = link2.entity1_id")
      .where("link.entity1_id = ?", id)
      .where("link2.entity2_id <> ?", id)
      .group("link2.entity2_id")
      .order("num DESC")

    r = r.where("link.is_reverse = ?", (order1 == 2)) if order1.present?
    r = r.where("link2.is_reverse = ?", (order2 == 2)) if order2.present?

    r = r.where("link.category_id" => cat1_ids) if cat1_ids.present?
    r = r.where("link2.category_id" => cat2_ids) if cat2_ids.present?

    if ext2_ids.present?
      r = r.joins("LEFT JOIN entity e ON e.id = link2.entity2_id LEFT JOIN extension_record er ON er.entity_id = e.id")
      r = r.where("er.definition_id" => ext2_ids)
    end

    if past1.present?
      r = r.joins("LEFT JOIN relationship r1 ON r1.id = link.relationship_id")
      r = r.where("(r1.is_current = 1 OR r1.is_current IS NULL) AND r1.end_date IS NULL")
    end

    if past2.present?
      r = r.joins("LEFT JOIN relationship r2 ON r2.id = link2.relationship_id")
      r = r.where("(r2.is_current = 1 OR r2.is_current IS NULL) AND r2.end_date IS NULL")
    end

    if only_count
      r = r.select("COUNT(DISTINCT l2.entity2_id)")
      r = r.group(nil)
      r = r.order(nil)
    else
      num = [num, max_num].min if max_num.present?
      r = r.limit(num) if num.present?
      r = r.offset(num * (page-1)) if page.present?
    end

    return r.first if only_count

    entities = r.to_a.collect do |row|
      entity = Entity.find_by_id(row[:degree2_id])
      if entity.nil?
        nil
      else
        { entity: entity, degree1_num: row[:num], degree1_ids: row[:degree1_ids] }
      end
    end.compact

    entities
  end

  def self.interlock_ids(entity1_id, entity2_id)
    related_ids = Link.where(entity1_id: entity1_id).pluck(:entity2_id).uniq
    Link.where(entity1_id: entity2_id, entity2_id: related_ids).pluck(:entity2_id).uniq - [entity1_id, entity2_id].map(&:to_i)
  end

  ##
  # utilities
  #

  # The cacheable concern overrides 'cache_key' and uses it for legacy caching.
  # So until we rid ourselves of legacy cache, will use alt_cache_key  @('_')@
  def alt_cache_key
    "entity/#{id}-#{updated_at.to_i}"
  end

  # A type checker for definition id and names
  # input: String or Integer
  # output: String or throws ArgumentError
  def self.ext_name_or_id_to_name(name_or_id)
    case name_or_id
    when String
      return name_or_id if all_extension_names.include?(name_or_id)
      raise ArgumentError, "there are no extensions associated with name: #{name_or_id}"
    when Integer
      name = all_extension_names[name_or_id]
      return name unless name.nil?
      raise ArgumentError, "there is no extension associated with id #{name_or_id}"
    else
      raise ArgumentError, "input must be a string or an integer"
    end
  end

  def self.rubin # :)
    find(1164)
  end

  # Input: <Entity> | String | Integer
  # Output: Integer
  def self.entity_id_for(entity)
    entity.is_a?(Entity) ? entity.id : entity.to_i
  end

  # Input: <Entity> | String | Integer
  # Output: Entity
  def self.entity_for(entity_or_id)
    return entity_or_id if entity_or_id.is_a? Entity
    return Entity.find(entity_or_id.to_i) if entity_or_id.is_a?(String) || entity_or_id.is_a?(Integer)
    raise ArgumentError, "Accepted types: Entity, Integer, or String"
  end

  def set_attribute(key, value)
    if has_attribute?(key)
      update_attribute(key.to_sym, value)
    else
      extensions_with_attributes.each do |ext, hash|
        if hash.has_key?(key)
          ext.constantize.find_by(entity_id: id).update_attribute(key, value)
          break
        end
      end
    end
  end

  def update_link_count
    update(link_count: links.count)
  end

  def name_without_initials
    name.gsub('.', '').split(' ').select { |part| part.length > 1 }.join(' ')
  end

  def affiliations
    relateds.where('link.category_id IN (1, 3)')
  end

  def industries
    os_categories.map(&:industry_name).uniq
  end

  def name_regexes(require_first = true)
    if person?
      regex = person.name_regex(require_first) rescue nil
      [regex].concat(aliases.map { |a| a.name_regex(require_first) rescue nil }).uniq.compact
    else
      []
    end
  end

  ##
  # User-related methods
  #

  # This update the timestamps and last_user_id as needed.
  # valid inputs:
  #   - string/integer of the SF GUARD user id
  #   - SfGuardUser
  #   - User
  # If input is any other class it will default to using the default 'system' user
  def update_timestamp_for(input)
    touch_by(input)
    self
  end

  def set_last_user_id
    self.last_user_id = Lilsis::Application.config.system_user_id unless self.last_user_id.present?
  end

  def last_new_user
    last_user.user
  end

  ##
  # Entity Fields
  #

  def all_field_details
    entity_fields.includes(:field)
  end

  def field_value(name)
    return nil unless details = field_details(name)
    details.value
  end

  def field_details(name)
    entity_fields.joins(:field).where(fields: { name: name }).first
  end

  def set_field(name, value, display_name = nil, type = "text")
    return false unless name.present? and value.present?

    EntityField.transaction do
      field = Field.find_or_create_by!(name: name) do |f|
        f.display_name = display_name.present? ? display_name : name.titleize
        f.type = type
      end

      ef = EntityField.find_or_initialize_by(entity: self, field: field)
      ef.update_attributes(value: value)
      ef
    end
  end

  def update_fields(hash)
    # underscore keys
    hash = Hash[hash.map { |k, v| [k.downcase.underscore.gsub(/\s+/, '_'), v] }]

    EntityField.transaction do
      # delete fields
      entity_fields.includes(:field).each do |ef|
        ef.delete if hash[ef.field.name].blank? or !hash.keys.include?(ef.field.name)
      end

      # update or create fields
      hash.each do |name, value|
        set_field(name, value)
      end
    end
  end

  def delete_field(name)
    ef.destroy if ef = field_details(name)
  end

  def map_field_values(field, value)
    if field == 'gender_id'
      v = {
        '1' => 'Female',
        '2' => 'Male',
        '3' => 'Other'
      }[value]
      k = 'gender'
    elsif field == 'party_id'
      v = Entity.where(id: value).pluck(:name).first
      k = 'party_affiliation'
    else
      k = field
      v = value
    end

    [k, v]
  end

  def update_fields_from_extensions
    return false unless id
    skip_cols = %w(id entity_id updated_at created_at name name_prefix name_first name_middle name_last name_suffix name_nick name_maiden)
    conn = ApplicationRecord.connection
    hash = {}
    self.class.all_extension_names_with_fields.each do |ext|
      sql = "SELECT * FROM #{ext.underscore} WHERE entity_id = #{id}"
      result = conn.execute(sql)
      if row = result.first
        row.each_with_index do |value, i|
          next unless value.present?
          col = result.fields[i]
          col, value = map_field_values(col, value)
          next if skip_cols.include?(col)
          hash[col] = value.to_s
        end
      end
    end
    hash
    update_fields(hash)
  end

  ##
  # Couple
  #

  def self.create_couple(name, partner1, partner2)
    blurb = [partner1.blurb, partner2.blurb].compact.join('; ')
    blurb = nil unless blurb.present?

    e = create(
      name: name,
      blurb: blurb,
      primary_ext: 'Couple',
      last_user_id: Lilsis::Application.config.system_user_id
    )
    e.couple.partner1_id = partner1.id
    e.couple.partner2_id = partner2.id
    e.couple.save
    e
  end

  def self.find_couple(partner1_id, partner2_id)
    joins(:couple).where("(couple.partner1_id = ? AND couple.partner2_id = ?) OR (couple.partner1_id = ? AND couple.partner2_id = ?)", partner1_id, partner2_id, partner2_id, partner1_id).first
  end

  def couples
    Couple.where("couple.partner1_id = ? OR couple.partner2_id = ?", id, id)
  end

  def partners
    couples.map { |c| c.partner1_id == id ? c.partner2 : c.partner1 }
  end

  ##
  # articles, addresses, references
  #

  # Returns all associated references and references for all relationships the entity is in
  def all_references
    Reference.all_entity_references(self)
  end

  def featured_articles
    articles.where(article_entities: { is_featured: true} )
  end

  def add_article(hash, featured=true)
    article_entity = nil

    ApplicationRecord.transaction do
      article = Article.create(hash)
      article_entity = ArticleEntity.create(
        article_id: article.id,
        entity_id: id,
        is_featured: featured
      )
    end

    article_entity
  end

  def children
    Entity.where(parent_id: id)
  end

  def party_members
    Entity.joins(:person).where(person: { party_id: id})
  end

  def unique_addresses
    # returns addresses without geocoding and the most recent address per unique lonlat
    index = {}
    adrs = addresses.order("created_at DESC")
    nils = adrs.select { |a| a.latitude.nil? or a.longitude.nil? }
    adrs.select { |a| a.latitude.present? and a.longitude.present? }.each do |a|
      hash = a.latitude.to_s[0..5] + "," + a.longitude.to_s[0..5]
      next if index[hash].present?
      index[hash] = a
    end

    index.values.concat(nils)
  end

  ##
  # View Helpers
  # TODO: Move these to a presenter
  #

  def description
    blurb
  end

  def summary_excerpt
    return nil if summary.nil?
    return summary if summary.length <= EXCERPT_SIZE

    if summary.slice(0, EXCERPT_SIZE).include? "\n"
      return summary.slice(0, summary.index("\n")) + '...'
    end

    summary.truncate(EXCERPT_SIZE, separator: ' ')
  end

  # returns hash of basc info for the given entity
  def basic_info
    info = {}
    info[:types] = types.join(', ')
    if person?
      info[:gender] = person.gender unless person.gender_id.nil?
      info[:birthday] = LsDate.new(start_date).basic_info_display unless start_date.nil?
      info[:date_of_death] = LsDate.new(end_date).basic_info_display unless end_date.nil?
    end
    if org?
      info[:start_date] = LsDate.new(start_date).basic_info_display unless start_date.nil?
      info[:end_date] = LsDate.new(end_date).basic_info_display unless end_date.nil?
      info[:revenue] = ActiveSupport::NumberHelper.number_to_human(org.revenue) unless org.revenue.blank?
    end
    info[:website] = website unless website.blank?
    #info[:industries] = industries.join(', ') unless industries.empty?
    info[:aliases] = also_known_as.join(', ') unless also_known_as.empty?
    # TODO: address
    info
  end

  ##
  # Merging, and history History
  #

  class EntityDeleted < Exceptions::ModelIsDeletedError
  end

  # When an entity is deleted we will store information
  # from it's associated models that gets deleted
  # in a 'meta' field with the PaperTrail version
  def get_association_data
    {
      'extension_ids' => extension_ids,
      'relationship_ids' => relationship_ids,
      'aliases' => aliases.where(is_primary: false).map(&:name),
      'tags' => tags.map(&:name)
    }
  end

  # un-deletes an entity
  # Essentially this just reverts
  # what happens in #after_soft_delete
  def restore!(restore_relationships = false)
    raise Exceptions::CannotRestoreError unless is_deleted
    association_data = retrieve_deleted_association_data
    raise Exceptions::MissingEntityAssociationDataError if association_data.nil?

    create_primary_ext
    create_primary_alias
    add_extensions_by_def_ids(association_data['extension_ids'])
    association_data['aliases'].each do |name|
      aliases.create(name: name, is_primary: false, last_user_id: Lilsis::Application.config.system_user_id)
    end

    association_data['tags'].each { |tag_name| add_tag_without_callbacks(tag_name) }
    Image.unscoped.where(entity_id: self.id).update_all(is_deleted: false)

    update(is_deleted: false)

    if restore_relationships
      association_data['relationship_ids'].each do |rel_id|
        Relationship.unscoped.find(rel_id).restore!
      end
    end
  end

  def slug
    "/#{primary_ext.downcase}/#{to_param}"
  end

  # MERGING --v
  # TODO: extract these 4 methods into a concern?

  def merge_with(dest)
    EntityMerger.new(source: self, dest: dest).merge!
  end

  def self.find_with_merges(id:, skope: :itself)
    e = Entity.unscoped.send(skope).find_by_id(id)
    raise Exceptions::MergedEntityError.new(e.resolve_merges(skope)) if e&.has_merges?
    raise ActiveRecord::RecordNotFound if e.nil? or e&.is_deleted?
    e
  end

  # ?Symbol -> Entity
  def resolve_merges(skope = :itself)
    return Entity.unscoped.send(skope).find_by_id(merged_id).resolve_merges(skope) if has_merges?
    self
  end

  def has_merges?
    merged_id.present?
  end

  # ^-- MERGING

  ##
  # Private helper methods
  #

  private

  # Callbacks for Soft Delete
  def after_soft_delete
    Alias.without_versioning { aliases.destroy_all }
    extension_models.each(&:destroy)
    extension_records.destroy_all
    images.each(&:soft_delete)
    list_entities.each(&:destroy)
    relationships.each(&:soft_delete)
    taggings.destroy_all
    # ArticleEntity
  end

  def name_or_id_to_name(name_or_id)
    self.class.send(:ext_name_or_id_to_name, name_or_id)
  end

  def extension_with_fields?(name)
    self.class.all_extension_names_with_fields.include?(name)
  end

  def trim_name_whitespace
    self.name = self.name.strip unless self.name.nil?
  end
end
