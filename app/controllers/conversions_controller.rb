class ConversionsController < ApplicationController
  before_action :authorize
  before_action :extend_session

  def index
    @conversions = Conversion.order(:created_at).all
  end

  def create
    listservlist = Listservlist.find(params[:listservlist_id].to_i)
    googlegroup = "#{params[:address].strip}-list@#{ENV['GOOGLE_DOMAIN']}"

    if listservlist.conversion
      flash[:error] = "A Google Group for this Listserv (#{listservlist.address}) has already been created by #{listservlist.conversion.owner}. You can find it at #{listservlist.conversion.address}"
      return #sends us to the redirect_to below
    end

    Log.create(:user=>session[:user_email],
               :list=>listservlist.address,
               :group=>googlegroup,
               :message=>"Creating Conversion based on Listserv ID #{listservlist.id}, #{listservlist.title}..."
    )
    conversion_size = listservlist.membercount.to_i + listservlist.owners.count.to_i + listservlist.moderators.count.to_i
    conversion = Conversion.create(
      :title => params[:title],
      :address => googlegroup,
      :owner => session[:user_email],
      :status => {size: conversion_size, processed: 0, message: 'Beginning Conversion...'}.to_json
    )

  	# Save the Conversion
    begin
      conversion.save!
    rescue StandardError => err
      Log.create(:user=>session[:user_email], :list=>listservlist.address, :group=>conversion.address, :message=>"Error while saving Conversion for Listserv #{listservlist.id}: #{err.message}")
    end
  
  	
    # Add the conversion to a Listservlist and to an Owner
    begin
      listservlist.conversion = conversion
      listservlist.save!
    	# If any of this fails, log it.
    rescue StandardError => err
      Log.create(:message=>"Error while associating Conversion #{conversion.id} with ListServList #{params[:listservlist_id]}: #{err.message}\n#{err.backtrace.to_s}")
    end

  	# Kick off group creation async task
    user_owns_list = Listservlist.joins(:owners).where(owners: {address: session[:alternate_emails]}, listservlists: {id: params[:listservlist_id].to_i}).count
    if user_owns_list > 0 or session[:user_email].in? ['bthomps5@nd.edu','pdrake@nd.edu'] # if the user owns this list or is an admin
      GenerateGroupWorker.new.async.perform(conversion.id)
      Log.create(:message=>"Begun GenerateGroupWorker...")
    else
      Log.create(:message=>"You don't have permission to convert this Listserv.", :user=>session[:user_email],:list=>listservlist.address,:group=>googlegroup)

    end
  	# Log the event

  	redirect_to({controller: 'listservlists', action: 'index'}, {flash: {notice: 'Thank you!  We are working to build your new Google Group.  You will get an email when it is ready.'}})
  end

  def new
  	@listservlist = Listservlist.find(params[:list_id])
    superlists = Sublist.where(:sublist=>@listservlist.address)
    @superlists = Array.new
    superlists.each do |sl|
      if Listservlist.joins(:conversion).where(listservlists:{address:sl.superlist},conversions:{status:"Complete"}).count < 1
        @superlists.push sl.superlist
      end
    end
  end

  def edit
  end

  def show
    conversion = Conversion.where(id: params[:id]).first
    if conversion
      status = JSON::parse conversion.status
      @percentage = ((status['processed'].to_f / status['size'].to_f) * 100).to_i
      status['percentage'] = @percentage
      #@message = status['message']
      render :json => status
    else
      render text: "Not Found", status: 404
    end
  end

  def update
  end

  def destroy
    conversion = Conversion.find(params[:id])
    #Log request to destroy conversion
    Log.create(:user=>session[:user_email], :group=>conversion.address, :list=>conversion.listservlist.address, :message=>"Undoing conversion")

    # Un-hold and send email
    ConversionMailer.free(conversion).deliver_now
    ConversionMailer.undo(session[:user_email], conversion).deliver_now unless conversion.address == "N/A" # We don't have to tell them we removed a Google Group if we aren't removing a Google Group.

    #Remove Google Group
    service_account = ServiceAccount.new
    response = service_account.delete(URI::encode(conversion.address))
    Log.create(:user=>session[:user_email], :group=>conversion.address, :list=>conversion.listservlist.address, :message=>"Group removed from Google: #{response.to_json}")

    #Delete conversion record
    success = "Deleted conversion record for #{conversion.listservlist.title}"
    if conversion.destroy
      Log.create(:user=>session[:user_email], :group=>conversion.address, :list=>conversion.listservlist.address, :message=>success)
    else
      Log.create(:user=>session[:user_email], :group=>conversion.address, :list=>conversion.listservlist.address, :message=>"Failed to delete conversion record for #{conversion.listservlist.title}")
    end
    render :json => {:response=>response}
  end

  def validate
    address = URI::encode("#{params[:address].strip}-list@#{ENV['GOOGLE_DOMAIN']}")

    #render :json => {:title_valid=>rand(10)%2, :address_valid=>rand(10)%2}.to_json
    s = ServiceAccount.new
    result = s.get_group address
    available = !(result.has_key?("email"))
    render :json => {:address_valid=>available, :response=>result.to_s}
  end

  def authorize
    client_secrets = Google::APIClient::ClientSecrets.load ENV['OAUTH_SECRET_PATH']
    auth_client = client_secrets.to_authorization
    auth_client.update!(
        :scope => 'https://www.googleapis.com/auth/userinfo.email',
        :redirect_uri => JSON.parse(ENV['GOOGLE_REDIRECT_URIS'])[2] + "?redirect=listservlists"
    )
    if !session[:authorized] || !session[:access_token] || session[:expiry] < Time.now.to_i
      redirect_to auth_client.authorization_uri.to_s
    end
  end

  def extend_session
    session[:expiry] = Time.now.to_i + 3600
  end
end