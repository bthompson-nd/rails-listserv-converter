require 'json'

class DiscontinueListWorker
  include SuckerPunch::Job
  def perform(conversion)
    ActiveRecord::Base.connection_pool.with_connection do
      Log.create(:user=>conversion.owner,
                 :list=>conversion.listservlist.address,
                 :group=>conversion.address,
                 :message=>"Discontinuing #{conversion.listservlist.address}")

      ConversionMailer.hold(conversion).deliver_now
      ConversionMailer.disc(conversion.listservlist.address, conversion.owner).deliver_now
      conversion.status = {size:1, processed: 1, message: "Discontinued"}.to_json
      conversion.save!
    end #End ActiveRecord pooled block
  end
end