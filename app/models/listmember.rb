class Listmember < ActiveRecord::Base
  belongs_to :listservlist
  belongs_to :member
end
