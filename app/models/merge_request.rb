# frozen_string_literal: true

class MergeRequest < UserRequest
  # fields: user_id, type, status, source_id, dest_id, justification

  validates :source_id, presence: true
  validates :dest_id, presence: true

  belongs_to :source, class_name: 'Entity', foreign_key: 'source_id'
  belongs_to :dest, class_name: 'Entity', foreign_key: 'dest_id'

  def approve!
    source.merge_with(dest)
  end
end
