class Member < ActiveRecord::Base
  has_many :listmembers
  has_many :listservlists, :through => :listmembers
end
