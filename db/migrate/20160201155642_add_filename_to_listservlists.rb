class AddFilenameToListservlists < ActiveRecord::Migration
  def change
    add_column :listservlists, :filename, :string
  end
end
