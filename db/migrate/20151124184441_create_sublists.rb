class CreateSublists < ActiveRecord::Migration
  def change
    create_table :sublists do |t|
    	t.string :sublist
    	t.string :superlist

      t.timestamps null: false
    end
  end
end
