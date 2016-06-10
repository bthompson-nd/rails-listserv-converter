class Listservlist < ActiveRecord::Base
  has_many :owners
  has_many :listmembers
  has_many :members, :through => :listmembers
  has_many :moderators
  has_one :conversion
  has_many :sublists, :through => :sublists, class_name: "Listservlist"
end
