class AddVisibleToListservlists < ActiveRecord::Migration
  def change
    add_column :listservlists, :visible, :boolean
  end
end
