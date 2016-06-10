class CreateListservlists < ActiveRecord::Migration
  def change
    create_table :listservlists do |t|
      t.string :title
      t.string :address
      t.string :google_settings

      t.timestamps null: false
    end
  end
end
