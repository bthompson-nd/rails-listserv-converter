class Owner < ActiveRecord::Base
  belongs_to :listservlist
  has_many :conversions
end
