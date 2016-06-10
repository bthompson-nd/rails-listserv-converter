class OauthController < ApplicationController
  def callback
    if params.has_key?(:code)
      session[:root_url] = root_url
      client = Google::APIClient.new(:application_name => "ND Listserv Converter", :application_version => "1.0.0")
      client_secrets = Google::APIClient::ClientSecrets.load ENV['OAUTH_SECRET_PATH']
      auth_client = client_secrets.to_authorization
      auth_client.update!(
        :scope => 'https://www.googleapis.com/auth/userinfo.email',
        :redirect_uri => JSON.parse(ENV['GOOGLE_REDIRECT_URIS'])[2] + "?redirect=#{params[:redirect]}"
      )
      client.authorization = auth_client
      error_message = 'Oops. Unable to verify your Google authorization information. Please try again.'
      #if client.authorization.nil?;
      #  flash[:error] = error_message
      #else
        client.authorization.code = params[:code]
        begin
          auth_hash = client.authorization.fetch_access_token!
          session[:access_token] = auth_hash['access_token']
          response = client.authorization.fetch_protected_resource(:uri => 'https://www.googleapis.com/oauth2/v1/userinfo?alt=json' )
          if response.status.to_i.between?(200, 299)
            profile = JSON.parse(response.body.to_s)
            session[:user_email] = profile.has_key?('email') ? profile['email'].downcase : 'unknown email address'
            session[:alternate_emails] = get_alt_emails(session[:user_email])

            is_in_admins_table = Administrator.where(:email => session[:alternate_emails]).count > 0
            session[:administrator] = (JSON::parse(ENV['ADMINISTRATORS']).include?(session[:user_email]) || is_in_admins_table)

            session[:authorized] = (profile.has_key?('email') && !(profile['email'].downcase =~ /.*@nd.edu$/).nil?)
            session[:expiry] = Time.now.to_i + 3600 #Session expires in an hour.
            if !session[:authorized]
              flash[:error] = 'You are not logged in to a University of Notre Dame Google account. Please log out of Google and try again.';
              session.clear
            else
              session[:credentials] = client.authorization.to_json
              session[:service_credentials] = authorize_service
              redirect_to "/#{params[:redirect]}"
            end
          end
        rescue Signet::AuthorizationError => e
          logger.error(e.message)
          flash[:error] = error_message
        end
      #end
    else
      flash[:error] = 'Unable to authorize application with Google!'
      if params.has_key?(:error)
        flash[:error] += ' (' + params[:error] +')'
      end
    end
  end

  private
  def authorize_service
    #Authorizes a service account which has been granted by an admin to access Google Groups
    f = File.open(ENV['CLIENT_SECRET_PATH'], "r")
    credentials = JSON.parse f.read
    scope = 'https://www.googleapis.com/auth/admin.directory.group https://www.googleapis.com/auth/admin.directory.group.readonly'
    
    alg = "RS256"
    now = Time.now.to_i
    exp = 3600 + now

    payload = {
      :iss => credentials["client_email"],
      :scope => scope,
      :aud => "https://www.googleapis.com/oauth2/v3/token",
      :sub => ENV['SMTP_USER'],
      :iat => now,
      :exp => exp
    }
    privkey = OpenSSL::PKey::RSA.new(credentials["private_key"])

    token = JWT.encode payload, privkey, alg

    authcode_request_uri = URI('https://www.googleapis.com/oauth2/v3/token')
    authcode_request_data = {:grant_type => "urn:ietf:params:oauth:grant-type:jwt-bearer", :assertion => token}

    authcode_response = Net::HTTP.post_form(authcode_request_uri, authcode_request_data)
    service_credentials = JSON.parse authcode_response.body

    return service_credentials
  end

  def get_alt_emails(user_email)
    begin
      ld = LdapFacade.new
      result = ld.get_alt_emails(user_email)
      return result
    rescue StandardError => err
      Log.create(:user=>"Application", :message=> "Couldn't get alternate emails for user #{user_email}, using only the logged-in email address.")
      puts err.message
      puts err.backtrace
      return [user_email]
    end
  end
end
