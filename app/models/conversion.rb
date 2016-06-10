class Conversion < ActiveRecord::Base
  validates :title, presence: true
  validates :address, presence: true


  belongs_to :listservlist

end
