class AddLogMetaColumns < ActiveRecord::Migration
  def change
  	add_column :logs, :user, :string
  	add_column :logs, :group, :string
  	add_column :logs, :list, :string
  end
end
