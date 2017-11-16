class AddIsGovernmentToPositions < ActiveRecord::Migration
  def change
  	add_column :position, :is_government, :boolean
  end
end
