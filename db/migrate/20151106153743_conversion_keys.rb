class ConversionKeys < ActiveRecord::Migration
  def change
    add_foreign_key "conversions", "listservlists", name: "conversions_listservlist_id_fk"
  end
end