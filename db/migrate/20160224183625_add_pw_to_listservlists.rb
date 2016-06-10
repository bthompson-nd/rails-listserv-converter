class AddPwToListservlists < ActiveRecord::Migration
  def change
    add_column :listservlists, :pw, :string
  end
end
