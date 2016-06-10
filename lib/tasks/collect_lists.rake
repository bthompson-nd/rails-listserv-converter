
require 'json'


task :collect_lists => :environment do
  Log.create(:message=>'Starting Listserv Import...',:user=>'Application')
  
  #Run the shell script for copying files
  output = `sh /apps/listserv-converter/copy_lists.sh`
  Log.create(:message=>'Copied files from Listserv to webserver...',:user=>'Application')

  #Run go get the .list files
  Dir.chdir('tmp/listserv')
  files = Dir.glob('*.list')
  filecount = files.count
  curfile = 0
  #Load each file in its entirety and process it.
  files.each do |f|
    #puts f
    start_time = Time.now
    curfile += 1
    #puts "#{Time.now.to_datetime} - Processing #{curfile}/#{filecount} - #{f}..."
    size = File.size(f)

    # Catch the error and skip the file if there's an encoding error
    begin
      list_address = "#{f[0..-6]}@listserv.nd.edu"
      offset = 11
      length = 100
      #Set default Google settings
      google_settings = {
          :whoCanPostMessage        => 'MEMBERS_ONLY',
          :whoCanViewMembership     => 'ALL_MEMBERS_CAN_VIEW',
          :replyTo                  => 'REPLY_TO_IGNORE',
          :membersCanPostAsTheGroup => false,
          :showInGroupDirectory     => false,
          :whoCanJoin               => 'INVITED_CAN_JOIN'
      }

      # Title might be on first or second line.
      title = IO.read(f, length, offset, mode:'rb').strip[2..-1]
      if title == nil || title.size < 3 # So if getting it at the first line failed...
        offset += 100 # Advance 100 chars and try again.
        title = IO.read(f, length, offset, mode:'rb').strip[2..-1] || "[Untitled]"
      end

      parsed = {
        :title => title[0..59], # Title must be 60 characters or less.
        :filename => f,
        :owners => Array.new,
        :moderators => Array.new,
        :members => Array.new,
        :sublists => Array.new,
        :maxsize => '25M',
        :google_settings => google_settings,
        :pw => ''
      }


      text = IO.read(f, mode:'rb')

      # First, grab the password and store it.
      pw_match = text.scan(/PW= (\S+)/).flatten
        if pw_match.count > 0
          parsed[:pw] = pw_match[0]
        end


      # Downcase the text so email addresses are always lowercase and the regex has fewer surprises
      text.downcase!

      #Read member emails only to count them for now. Will read them again during Google Group creation.
      member_emails = get_emails text.scan(/(.{1,80})[\S]{12}\/\/\/\/    /)
      parsed[:member_count] = member_emails.count


      # "* Owner= " denotes an owner
      owners = get_emails text.scan(/\*\s{1,2}owner= (.{1,90})/)
      owners.each do |o|
        parsed[:owners].push o
        # If an owner can be identified as an existing list, add a Sublist record
        if Listservlist.where(:address=>o).count > 0
          parsed[:sublists].push(:superlist => o, :sublist => list_address)
        end
      end

      superlists = text.scan(/\*\s{1,2}owner= \S+\(([a-z0-9_\-]+)\)\s{0,79}\*/).flatten
      superlists.map! do |sl|
        sl = sl.split(',')
      end
      superlists.flatten!
      superlists.each do |sl|
        superlist = sl.strip
        if superlist != 'hd-staff'
          parsed[:sublists].push(:superlist=>"#{superlist}@listserv.nd.edu", :sublist=>list_address)
        end
      end

      # If the text starts with "* Moderator =", it is a moderator
      moderators = get_emails text.scan(/\*\s{1,2}moderator= (.{1,86})/)
      moderators.each do |m|
        parsed[:moderators].push m
      end


      # If the text starts with "* Editor= ", it is an editor, but we'll store that as a moderator
      # Google only has two kinds of administrative users, Owner and Moderator
      editors = get_emails text.scan(/\*\s{1,2}editor= (.{1,89})/)

      editors.each do |e|
        parsed[:moderators].push e
        #puts "Inserting (Editor)Moderator: #{e}"
      end

      # Sub-lists= sublist1,sublist2...sublistn
      sublists = text.scan(/\*\s{1,2}sub-lists= (.{0,86})/).flatten
      if sublists.count > 0
        sublists = sublists[0].split(',')
      end
      sublists.each do |s|
        parsed[:sublists].push(:superlist=>list_address, :sublist=>"#{s.strip}@listerv.nd.edu")
      end

      #Send= Public[,Confirm][,Non-Member]
      #Send= Private[,Confirm]
      #Send= Editor[,Hold][,Confirm[,Non-Member | All]][,Semi-Moderated][,NoMIME]
      #Send= other-access-level[,Confirm]
      # Determines whether users can send mail to this list
      whocansend = text.scan(/\*\s{1,2}send= (.{0,92})/).flatten
      if whocansend.count > 0
        send = whocansend[0].strip
        if send.include? 'editor' or send.include? 'owner'
          parsed[:google_settings][:whoCanPostMessage] = 'ALL_MANAGERS_CAN_POST'
        elsif send.include? 'public'
          parsed[:google_settings][:whoCanPostMessage] = 'ANYONE_CAN_POST'
        elsif send.include? 'private'
          parsed[:google_settings][:whoCanPostMessage] = 'MEMBERS_ONLY'
        end

        if send.include? 'hold'
          parsed[:google_settings][:messageModerationLevel] = 'MODERATE_ALL_MESSAGES'
        end

      end

      #Review= access-level
      whocanreview = text.scan(/\*\s{1,2}review= (.{0,90})/).flatten
      if whocanreview.count > 0
        review = whocanreview[0].strip
        if review.include? 'private'
          parsed[:google_settings][:whoCanViewMembership] = 'ALL_MANAGERS_CAN_VIEW'
        elsif review.include? 'editor'
          parsed[:google_settings][:whoCanViewMembership] = 'ALL_MANAGERS_CAN_VIEW'
        end
      end

      #Subscription= Open [,Confirm]
      #Subscription= By_Owner[,Confirm]
      #Subscription= Closed
      # Determines whether new users are allowed to subscribe and/or if they require approval.
      # Default is INVITED_CAN_JOIN. Here are conditions for the other values
      subscription = text.scan(/\*\s{1,2}subscription= (.{84})/).flatten
      if subscription.count > 0
        sub = subscription[0].strip
        if sub.include? 'open'
          parsed[:google_settings][:whoCanJoin] = 'ANYONE_CAN_JOIN'
        end
        if sub.include? 'open,confirm'
          parsed[:google_settings][:whoCanJoin] = 'CAN_REQUEST_TO_JOIN'
        end
      end

      #Confidential= Yes
      #Confidential= No
      #Confidential= Service
      # Determines whether the list is visible in the directory. Default is false, here are conditions for true
      confidential = text.scan(/\*\s{1,2}confidential= (.{0,84})/).flatten
      if confidential.count > 0
        conf = confidential[0].strip
        if conf.include? 'no'
          parsed[:google_settings][:showInGroupDirectory] = true
        elsif conf.include? 'service'
          parsed[:google_settings][:showInGroupDirectory] = true
        end
      end

      #Reply-To= List|Sender|Both|None|net-address,[Respect|Ignore]
      # Determines whether replies go to list, sender or something else
      # Default at Google is REPLY_TO_IGNORE
      replyto = text.scan(/\*\s{1,2}reply-to= (.{0,88})/).flatten
      if replyto.count > 0
        reply = replyto[0].strip
        if reply.include? 'list'
          parsed[:google_settings][:replyTo] = 'REPLY_TO_LIST'
        elsif reply.include? 'sender'
          parsed[:google_settings][:replyTo] = 'REPLY_TO_SENDER'
        end
      end

      customreply = text.scan(/\*\s{1,2}reply-to= ([a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,})/).flatten
      if customreply.count > 0
        customreply = customreply[0].strip
        parsed[:google_settings][:customReplyTo] = customreply
        parsed[:google_settings][:replyTo] = 'REPLY_TO_CUSTOM'
        #puts "- HAS CUSTOM REPLYTO"
      end


    rescue StandardError => err
      Log.create(:message=> "Could not read #{f}: #{err.message} | #{err.backtrace}", :user=>'Application')
      next
    end

    # If there were no errors reading the file...
    #puts "#{Time.now.to_datetime} - Parsing Complete, Inserting List #{parsed[:title]}"
    parse_end = Time.now
    list = Listservlist.find_or_create_by(:filename => parsed[:filename])
    list.title = parsed[:title]
    list.address = list_address
    list.pw = parsed[:pw]
    list.membercount = parsed[:member_count]

    # Modify owners and moderators based on file contents
    extant_owners = list.owners.map {|o| o[:address] }
    extant_moderators = list.moderators.map {|m| m[:address] }
    owners_to_add = parsed[:owners] - extant_owners
    owners_to_remove = extant_owners - parsed[:owners]
    moderators_to_add = parsed[:moderators] - extant_moderators
    moderators_to_remove = extant_moderators - parsed[:moderators]
    
    #parsed[:owners].each {|o| list.owners.push Owner.find_or_create_by(:address => o, :listservlist => list)}
    owners_to_add.each {|o| list.owners.push Owner.find_or_create_by(:address => o, :listservlist => list)}
    owners_to_remove.each {|o| list.owners.delete(list.owners.where(address: o))}
    #parsed[:moderators].each {|mod| list.moderators.push Moderator.find_or_create_by(:address => mod, :listservlist => list)}
    moderators_to_add.each {|m| list.moderators.push Moderator.find_or_create_by(:address => m, :listservlist => list)}
    moderators_to_remove.each {|m| list.moderators.delete(list.moderators.where(address: m))}
    
    parsed[:sublists].each {|sublist_hash| Sublist.find_or_create_by(sublist_hash)}

    list.google_settings = parsed[:google_settings].to_json

    # Set the list to invisible if necessary
    # Should be done if there are any superlists, or if the list has any parts dynamically defined
    if list.visible == nil && (Sublist.where(:sublist=>list_address).count > 0 || text.scan(/(query\()/).count > 0)
      list.visible = false
    end
    # When an admin sets it to Visible or Invisible manually,
    # list.visible ceases to be nil,
    # so future runs will not set visibility.

    list.save
    #Log.create(:message=>"#{Time.now.to_datetime}: Finished creating list #{parsed[:title]}", :user=>"Application")
    insert_end = Time.now
    parse_time = parse_end - start_time
    insert_time = insert_end - parse_end
    #puts "- Seconds to Parse: #{parse_time}"
    #puts "- Seconds to Insert:#{insert_time}"
  end # End of files loop

  #Listservlist.where(:address => Sublist.select(:))

  Log.create(:message=>'Listserv Import Finished.', :user=>'Application')

end # End of task

def get_emails(matches)
  matches.flatten! #Flattens the match array in case the original contained any arrays (it probably didn't)
  matches.map! {|m| m.split(',')} #Split any elements of the match array if they are comma-delimited
  matches.flatten! #Flatten the split comma-delimited elements back down so this is a 1-D array again
  output = [] #The output variable
  matches.each do |match|
    #Find any email addresses in a match
    emails = match.scan(/[a-z'0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,5}/)
    emails.each do |email|
      output.push email #Put those email addresses into the output variable
    end
  end
  return output #Return a flat array of email addresses.
end