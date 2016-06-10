class LdapFacade
  def initialize
      @ldap = Net::LDAP.new(
          :host => ENV['LDAP_HOST'],
          :port => ENV['LDAP_PORT'].to_i,
          :encryption => {:method => :simple_tls, :tls_options => OpenSSL::SSL::SSLContext::DEFAULT_PARAMS},
          :auth => {
              :method => :simple,
              :username => ENV['LDAP_USER'],
              :password => ENV['LDAP_PASS']
          })
  end

  def get_alt_emails(user_email)
    filter = Net::LDAP::Filter.eq('ndmail', user_email)
    treebase = ENV['LDAP_BASE']
    result = Array.new
    @ldap.search(:base=>treebase, :filter=>filter) do |entry|
      entry.each do |attribute, values|
        if attribute.to_s=="ndmail"
          values.each do |value|
            result.push value.to_s
          end
        end
      end
    end
    return result
  end

  def get_base_email(user_email)
    # Looks up the user's email in LDAP and returns the user's UID@nd.edu email if one is found.
    # If none found, returns false.
      filter = Net::LDAP::Filter.eq('ndmail', user_email)
      treebase = ENV['LDAP_BASE']
      result = false
      @ldap.search(:base=>treebase, :filter=>filter) do |entry|
        entry.each do |attribute, values|
          if attribute.to_s=='uid'
            values.each do |value|
              result = "#{value.to_s}@nd.edu"
            end
          end
        end
      end
      return result
  end


end