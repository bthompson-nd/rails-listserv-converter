class ListservlistsController < ApplicationController
  before_action :authorize
  before_action :extend_session

  def index
    @admin = false
    if (session[:administrator])
      @listservlists = Listservlist.includes(:conversion).all.order(address: :asc, title: :asc)
      @admin = true
    else
      @listservlists = Listservlist.includes(:conversion).joins(:owners).where(owners: {address: session[:alternate_emails]}, listservlists: {visible:[nil,true]}).distinct.paginate(:page=>params[:page], :per_page=>10).order('listservlists.address ASC, listservlists.title ASC')
    end
    @user_email = session[:user_email]
    @groups = list_groups(session[:service_credentials])
    @alt_emails = session[:alternate_emails]
    last_update_log = Log.where(:message=>'Listserv Import Finished.').order(created_at: :desc).take
    @last_update = "Never"
    if last_update_log.class == Log #If you found an entry in the log indicating the ingestion job finished...
      @last_update = ActiveSupport::TimeZone["EST"].at(last_update_log.created_at).strftime("%m/%d/%Y %I:%M%p")
    end

  end

  def create
    render status: 403, template: 'errors/403.html.erb'
  end

  def new
    render status: 403, template: 'errors/403.html.erb'
  end


  def edit
    #Check if the authenticated user is an admin
    if admins.include? session[:user_email]
      #show the admin edit page
    else
      render status: 403, template: 'errors/403.html.erb'
    end
  end

  def show
    @list = Listservlist.find(params[:id])
    #if @list.owners.include? Owner.where(:address=>[session[:user_email]])
    #else
    #  render status: 403, template: "errors/403.html.erb"
    #end
  end

  def discontinue_ask
    if session[:administrator]
      @list = Listservlist.find(params[:id])
    else
      @list = Listservlist.joins(:owners).where(id: params[:id], owners: {address: session[:alternate_emails]}).first
    end
  end

  def discontinue
    if session[:administrator]
      @list = Listservlist.find(params[:id])
    else
      @list = Listservlist.joins(:owners).where(id: params[:id], owners: {address: session[:alternate_emails]}).first
    end
    if @list
      conversion = Conversion.create(
          :title => "DISCONTINUED",
          :listservlist => @list,
          :address => "N/A",
          :owner => session[:user_email],
          :status => {size: 1, processed: 0, message: 'Discontinuing...'}.to_json
      )
      conversion.save!
      DiscontinueListWorker.new.async.perform(conversion)
    end
      redirect_to({controller:'listservlists', action:'index'}, {flash: {notice: 'Your list has been put on hold. Messages sent to this email list will no longer be delivered.'}})
  end

  def update
    list = Listservlist.find(params[:id])
    list.visible = params[:visible]
    list.save!
    render :json => {:visible=>list.visible}
  end

  def destroy
    render status: 403, template: 'errors/403.html.erb'
  end

  def gengroups()
    
  end


private
  #Check if user is authorized with Google
  #def authorize
  #  session[:root_url] = root_url
  #  client = Google::APIClient.new
  #  if client.authorization.nil? || !session[:authorized] || !session[:access_token]
  #    redirect_to client.authorization.authorization_uri.to_s
  #  end
  #end
  def authorize
    if !session[:authorized] || !session[:access_token] || session[:expiry] < Time.now.to_i
      client_secrets = Google::APIClient::ClientSecrets.load ENV['OAUTH_SECRET_PATH']
      auth_client = client_secrets.to_authorization
      auth_client.update!(
        :scope => 'https://www.googleapis.com/auth/userinfo.email',
        :redirect_uri => JSON.parse(ENV['GOOGLE_REDIRECT_URIS'])[2] + "?redirect=listservlists"
        )
      redirect_to auth_client.authorization_uri.to_s
    end
  end

  def extend_session
    session[:expiry] = Time.now.to_i + 3600
  end
  
  def list_groups(credentials)
    get_uri = URI("https://www.googleapis.com/admin/directory/v1/groups?domain=nd.edu&access_token=#{credentials['access_token']}")
    get = Net::HTTP::Get.new get_uri
    get["Authorization"] = "Bearer #{credentials['access_token']}"
    response = Net::HTTP.start(get_uri.host, get_uri.port,
      :use_ssl => true) do |http|
      http.request(get)
    end
    data = JSON.parse response.body
    return data
  end

end