class AdminController < ApplicationController
	before_action :authorize, except: [:logout, :reject]

  def index
  end
  
  def log
    queries = {
      :from => "logs.created_at >= :from",
      :to => "logs.created_at <= :to",
      :user => "logs.user = :user",
      :group => "logs.group = :group",
      :list => "logs.list = :list"
    }
  	@users = Log.select(:user).order(user: :asc).distinct.map   { |u| u.user }
    @groups = Log.select(:group).order(group: :asc).distinct.map { |g| g.group }
    @lists = Log.select(:list).order(list: :asc).distinct.map   { |l| l.list }
    @logs = Log.all.order('created_at DESC')
    query_values = {}
    query_clauses = []
    [:from,:to,:user,:group,:list].each do |field|
      if params[field] == nil or params[field].size < 1
        next
      else
        query_clauses.push queries[field]
        query_values[field] = params[field]
      end
    end
    

    @logs = Log.where(query_clauses.join(" AND "), query_values).order('created_at DESC')

  end

  def status
  end

  def logout
    ActiveRecord::SessionStore::Session.where(:session_id => session.id).each {|s| s.delete}
    redirect_to '/'
  end

  def lists
  	@lists = Listservlist.all
  end

  def conversions
  	@conversions = Conversion.all
  end

  def reject
  end

  def download_cron
    filename = '/apps/listserv-converter/log/cron.log'
    if File.exists? filename
      f = File.open(filename,mode:'rb')
      @text = f.read
    else
      @text = ''
    end
    render :text => @text
  end

  private
  #Check if user is authorized with Google
  def authorize
    if (session[:authorized] && session[:access_token] && session[:expiry] > Time.now.to_i) && !session[:administrator]
      # If logged in but not an administrator...
      redirect_to '/admin/reject'
    end
    if !session[:authorized] || !session[:access_token] || session[:expiry] < Time.now.to_i
      client_secrets = Google::APIClient::ClientSecrets.load ENV['OAUTH_SECRET_PATH']
      auth_client = client_secrets.to_authorization
      auth_client.update!(
        :scope => 'https://www.googleapis.com/auth/userinfo.email',
        :redirect_uri => JSON.parse(ENV['GOOGLE_REDIRECT_URIS'])[2]+"?redirect=#{params[:controller]}/#{params[:action]}"
        )
      redirect_to auth_client.authorization_uri.to_s
    end
  end
end
