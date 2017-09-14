module Tagable
  extend ActiveSupport::Concern

  included do
    has_many :taggings, as: :tagable, foreign_type: :tagable_class
    has_many :tags, through: :taggings
  end

  class_methods do
    def category_str
      name.downcase.pluralize
    end

    def category_sym
      category_str.to_sym
    end
  end

  # str|sym -> ClassConstant
  def self.class_of(category)
    category.to_s.singularize.classify.constantize
  end

  # NOTE(@aguestuser): this constant *cannot* go before `included` and `class_methods` blocks
  TAGABLE_CLASSES = [Entity, List, Relationship]

  # CRUD METHODS

  # [String|Int] -> Tagable
  def update_tags(ids)
    server_tag_ids = tags.map(&:id).to_set
    client_tag_ids = ids.map(&:to_i).to_set
    actions = Tag.parse_update_actions(client_tag_ids, server_tag_ids)

    actions[:remove].each { |tag_id| remove_tag(tag_id) }
    actions[:add].each { |tag_id| tag(tag_id) }
    self
  end

  def tag(name_or_id)
    Tagging.find_or_create_by(tag_id:         parse_tag_id!(name_or_id),
                              tagable_class:  self.class.name,
                              tagable_id:     self.id)
    self
  end

  def tag_without_callbacks(name_or_id)
    Tagging.skip_callback(:save, :after, :update_tagable_timestamp)
    tag(name_or_id)
  ensure
    Tagging.set_callback(:save, :after, :update_tagable_timestamp)
  end

  def remove_tag(name_or_id)
    taggings
      .find_by_tag_id(parse_tag_id!(name_or_id))
      .destroy
  end

  def tags_for(user)
    {
      byId: hashify(add_permissions(Tag.all, user)),
      current: tags.map(&:id).map(&:to_s)
    }
  end

  private

  # NOTE: does NOT allow string-intergers as ids .ie. '1'
  def parse_tag_id!(name_or_id)
    msg = name_or_id.is_a?(String) ? :find_by_name! : :find
    Tag.public_send(msg, name_or_id).id
  end

  # Array[Tag] -> Hash{[id:string]: Tag}
  def hashify(tags)
    tags.reduce({}) do |acc, t|
      acc.merge(t['id'].to_s => t)
    end
  end

  # (Array[Tag], User) -> Array[AugmentedTag]
  def add_permissions(tags, user)
    tags.map do |t|
      t.attributes.merge('permissions' => user.permissions.tag_permissions(t))
    end
  end
end
