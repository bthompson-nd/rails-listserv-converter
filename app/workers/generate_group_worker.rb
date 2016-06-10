require 'json'

class GenerateGroupWorker
  include SuckerPunch::Job
  def perform(conversion_id)
    ActiveRecord::Base.connection_pool.with_connection do
      @service_credentials = authorize_service # Gets us authorized with Google
      @conversion = Conversion.find(conversion_id) # Finds the conversion record created moments ago by the controller.
      @listservlist = @conversion.listservlist # The Listserv list that we will be working with
      log("Beginning conversion...") # Note in the log that this job is starting
      @status = JSON::parse @conversion.status # The object we will be working with to make status updates
      # Initial status value looks like {size: conversion_size, processed: 0, message: 'Beginning Conversion...'}
      # Progress will be tracked by using the @status variable's message field and the ratio of processed/size.

      # Create LDAP connection
      begin
        @ldap = LdapFacade.new # Contains a Net::LDAP object authenticated and ready to run queries.
        # See config/initializers/ldap_facade.rb

      rescue StandardError => err
        log('Failed to establish LDAP connection! Exiting')
        @status['message'] = "Failed"
        @conversion.status = @status.to_json
        @conversion.save!
        return
      end

      begin
        @status['message'] = 'Preparing...'
        @conversion.status = @status.to_json
        @conversion.save!

        # Read the Listserv file and get the member/owner/manager lists
        log('Compiling members...')
        @members = read_members(@listservlist.filename) # Need to get these out of listservlist file
        log('Compiling owners...')
        @owners =  []
        @listservlist.owners.each do |o|
          @owners.push o.address
        end
        log('Compiling managers...')
        @managers = []
        @listservlist.moderators.each do |m|
          @managers.push m.address
        end
      rescue StandardError => err
        log("Failed to compile the list of users. Exiting. #{err.message} | #{err.backtrace}")
        @status['message'] = 'Failed'
        @conversion.status = @status.to_json
        @conversion.save!
        return
      end



      # Attempt to create the google group
      # If Google rejects (because of name collision, for example), log the error and email the user/admin
      @status['message'] = 'Creating Google Group...'
      @conversion.status = @status.to_json
      @conversion.save!
      response = create_group(@conversion)
      if response.has_key? "error"
        log("Failed to create Google group: #{response.to_json}")
        @status['message'] = 'Failed'
        @conversion.status = @status.to_json
        @conversion.save!
        return
      else
        log("Group Created => #{response.to_json}")
        @status['message'] = 'Group created, adding members...'
        @conversion.status = @status.to_json
        @conversion.save!
      end


      begin
        # Add all Google Group members, from highest rank to lowest. Repeats will be rejected as already existing.
        log('Adding Owners...')
        add_gg_members(@owners, 'OWNER')

        log('Adding Managers...')
        add_gg_members(@managers, 'MANAGER')

        log('Adding Members...')
        add_gg_members(@members, 'MEMBER')
      rescue StandardError => err
        log("Couldn't add members to the Group: #{err.message} | #{err.backtrace}")
        @status['message'] = 'Failed'
        @conversion.status = @status.to_json
        @conversion.save!
        return
      end

      # If we made it through all the member adding steps, update the status again to show we've moved on.
      @status['message'] = 'Members added, applying settings...'
      @conversion.status = @status.to_json
      @conversion.save!


      begin
        #Set Settings
        settings_result = patch_group_settings(@conversion.address, @listservlist.google_settings.to_s)
        log("Settings for #{@conversion.address} applied. Response: #{settings_result}")
      rescue StandardError => err
        log("Could not apply Group settings")
        @status['message'] = 'Failed'
        @conversion.status = @status.to_json
        @conversion.save!
        return
      end

      #Check for Superlists
      #Add each superlist (which will recursively add its)
      #End superlist treatment

      # If none of the above steps bailed out, we're done!
      @status['message'] = 'Complete'
      @conversion.status = @status.to_json
      @conversion.save!

      begin
        log("Sending confirmation message...")
        ConversionMailer.hold(@conversion).deliver_now
        ConversionMailer.complete(@conversion).deliver_now
      rescue StandardError => err
        log("Sending confirmation message failed: #{err.message} | #{err.backtrace}")
        @status['message'] = "Complete, but couldn't send confirmation email."
        @conversion.status = @status.to_json
        @conversion.save!
      end
    end #Ends ActiveRecord pooled block
  end

  def create_group(conversion)
    
    post_uri = URI("https://www.googleapis.com/admin/directory/v1/groups?domain=#{ENV['GOOGLE_DOMAIN']}&access_token=#{@service_credentials['access_token']}")
    data = {"email"=>conversion.address,"name"=>conversion.title}

    http = Net::HTTP.new(post_uri.host, post_uri.port)
    request = Net::HTTP::Post.new(post_uri.request_uri)
    request.body = data.to_json
    http.use_ssl = true
    request["Authorization"] = "Bearer #{@service_credentials['access_token']}"
    request["Content-Type"] = 'application/json'
    response = http.request(request)
    response_obj = JSON.parse response.body

    return response_obj
  end

  def add_member(group, member, role)
    post_uri = URI("https://www.googleapis.com/admin/directory/v1/groups/#{group}/members?access_token=#{@service_credentials['access_token']}")
    data = {'email'=>member, 'role'=>role}

    http = Net::HTTP.new(post_uri.host, post_uri.port)
    request = Net::HTTP::Post.new(post_uri.request_uri)
    request.body = data.to_json
    http.use_ssl = true
    request['Authorization'] = "Bearer #{@service_credentials['access_token']}"
    request['Content-Type'] = 'application/json'
    response = http.request(request)
    response_obj = JSON.parse response.body

    return response_obj
  end

  def patch_group_settings(group, settings_json)
    Log.create(
        :user=>@conversion.owner,
        :list=>@conversion.listservlist.address,
        :group=>@conversion.address,
        :message=>"About to put settings: #{settings_json}")
    begin
      post_uri = URI("https://www.googleapis.com/groups/v1/groups/#{group}?fields=allowExternalMembers%2CallowGoogleCommunication%2CallowWebPosting%2CarchiveOnly%2CcustomReplyTo%2CdefaultMessageDenyNotificationText%2Cdescription%2Cemail%2CincludeInGlobalAddressList%2CisArchived%2Ckind%2CmaxMessageBytes%2CmembersCanPostAsTheGroup%2CmessageDisplayFont%2CmessageModerationLevel%2Cname%2CprimaryLanguage%2CreplyTo%2CsendMessageDenyNotification%2CshowInGroupDirectory%2CspamModerationLevel%2CwhoCanContactOwner%2CwhoCanInvite%2CwhoCanJoin%2CwhoCanLeaveGroup%2CwhoCanPostMessage%2CwhoCanViewGroup%2CwhoCanViewMembership&access_token=#{@service_credentials['access_token']}")
      data = settings_json
      http = Net::HTTP.new(post_uri.host, post_uri.port)
      request = Net::HTTP::Patch.new(post_uri.request_uri)
      request.body = data
      http.use_ssl = true
      request["Authorization"] = "Bearer #{@service_credentials['access_token']}"
      request["Content-Type"] = 'application/json'
      response = http.request(request)
      return response.body unless !()
    rescue StandardError => err
      Log.create(
          :user=>@conversion.owner,
          :list=>@conversion.listservlist.address,
          :group=>@conversion.address,
          :message=>"Failed to put group settings: #{err.message}")
      return "[[Failed to put group settings]]"
    end
  end

  def authorize_service
    begin
      #Authorizes a service account which has been granted by an admin to access Google Groups
      f = File.open(ENV['CLIENT_SECRET_PATH'], 'r')
      credentials = JSON.parse f.read
      scope = 'https://www.googleapis.com/auth/apps.groups.settings https://www.googleapis.com/auth/admin.directory.group https://www.googleapis.com/auth/admin.directory.group.readonly'
      
      alg = 'RS256'
      now = Time.now.to_i
      exp = 3600 + now

      payload = {
        :iss => credentials['client_email'],
        :scope => scope,
        :aud => 'https://www.googleapis.com/oauth2/v3/token',
        :sub => ENV['SMTP_USER'],
        :iat => now,
        :exp => exp
      }
      privkey = OpenSSL::PKey::RSA.new(credentials['private_key'])

      token = JWT.encode payload, privkey, alg

      authcode_request_uri = URI('https://www.googleapis.com/oauth2/v3/token')
      authcode_request_data = {:grant_type => 'urn:ietf:params:oauth:grant-type:jwt-bearer', :assertion => token}

      authcode_response = Net::HTTP.post_form(authcode_request_uri, authcode_request_data)
      service_credentials = JSON.parse authcode_response.body

      return service_credentials
    rescue StandardError => exc
      Log.create(:user=>@conversion.owner, :list=>@conversion.listservlist.address, :group=>@conversion.address, :message=>"Error authorizing service with Google. #{exc.message}")
    end
  end



  def read_members(filename)
    # Read the list subscribers out of the listserv's .list file
    text = IO.read("tmp/listserv/#{filename}",mode:'rb')
    text.downcase!
    member_emails = get_emails text.scan(/([a-z'0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,5}).{0,80}[\S]{12}\/\/\/\/    /)
    return member_emails
  end

  def add_gg_members(members,role)
    members.each do |member|
      @status['processed'] = @status['processed'].to_i + 1
      @conversion.status = @status.to_json
      @conversion.save!
      email = member
      if member.scan(/@nd\.edu$|\.nd\.edu$/).count > 0 #If the email address ends in @nd.edu or .nd.edu, check LDAP
        email = @ldap.get_base_email(member)
        if email==false
          # Skip this person if you couldn't find them in LDAP
          log("Couldn't verify user #{member} against LDAP. Skipping.")
          next
        end
      end
      member_response = add_member(@conversion.address,email,role)
      if member_response.has_key? 'error'
        log("Could not add #{email} to #{@conversion.address} as MEMBER. #{member_response.to_json}")
        if member_response['error']['code'] == 404 && member_response['error']['message'] == 'Resource Not Found: groupKey'
          log("No Group #{@conversion.address}. Quitting.")
          return
        end
      end
    end
  end

  def get_emails(matches)
    # Used by read_members()
    # Some of the matches might be comma-delimited sets of email addresses.
    # map! {}.flatten will break those apart and assimilate them into the array.
    # There is an identical copy of this function in collect_lists
    matches = matches.flatten
    matches.map! {|o| o.split(',')}
    matches.flatten
  end

  def log(message)
    Log.create(:user=>@conversion.owner,
               :list=>@conversion.listservlist.address,
               :group=>@conversion.address,
               :message=>message)
  end
   
end