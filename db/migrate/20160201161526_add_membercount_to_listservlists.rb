class AddMembercountToListservlists < ActiveRecord::Migration
  def change
    add_column :listservlists, :membercount, :string
  end
end
