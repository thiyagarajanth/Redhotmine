class RenameBillableToBillableType < ActiveRecord::Migration
  def change
  	add_column :members, :billable_type_id, :integer
  	add_column :member_histories, :billable_type_id, :integer
  end
end
