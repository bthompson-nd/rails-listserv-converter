require 'jwt'
require 'uri'
require 'net/http'


class ServiceAccount
  def initialize
    self.build
  end

  def build
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
    service_credentials['expiry'] = now + service_credentials['expires_in']
    @credentials = service_credentials
    return service_credentials
  end

  def list_groups
    if @credentials['expiry'] < (Time.now.to_i+30)
      @credentials = self.build
    end
    get_uri = URI("https://www.googleapis.com/admin/directory/v1/groups?domain=nd.edu&access_token=#{@credentials['access_token']}")
    get = Net::HTTP::Get.new get_uri
    get["Authorization"] = "Bearer #{@credentials['access_token']}"
    response = Net::HTTP.start(get_uri.host, get_uri.port,
      :use_ssl => true) do |http|
      http.request(get)
    end
    data = JSON.parse response.body
    return data
  end

  def get_group(address)
    if @credentials['expiry'] < (Time.now.to_i+30)
      @credentials = self.build
    end
    get_uri = URI("https://www.googleapis.com/admin/directory/v1/groups/#{address}?fields=email%2Cname&access_token=#{@credentials['access_token']}")
    get = Net::HTTP::Get.new get_uri
    get["Authorization"] = "Bearer #{@credentials['access_token']}"
    response = Net::HTTP.start(get_uri.host, get_uri.port,
      :use_ssl => true) do |http|
      http.request(get)
    end
    data = JSON.parse response.body
    return data
  end

  def delete(address)
    if @credentials['expiry'] < (Time.now.to_i+30)
      @credentials = self.build
    end
    delete_uri = URI("https://www.googleapis.com/admin/directory/v1/groups/#{address}?access_token=#{@credentials['access_token']}")
    delete = Net::HTTP::Delete.new delete_uri
    delete["Authorization"] = "Bearer #{@credentials['access_token']}"
    response = Net::HTTP.start(delete_uri.host, delete_uri.port,
      :use_ssl => true) do |http|
      http.request(delete)
    end
    puts response.to_json
    data = {:status => response.code}
    return data
  end
end