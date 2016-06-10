class ConversionMailer < ApplicationMailer
  def complete(conversion)
    @owner = conversion.owner
    @group_address = conversion.address
    @group_name = conversion.title
    @listserv_address = conversion.listservlist.address
    @listserv_name = conversion.listservlist.title
    @pw = conversion.listservlist.pw
    @list = conversion.listservlist.filename[0..-6].upcase
    mail(to: @owner, from: ENV['SMTP_USER'], subject: "Google Group [#{@group_name}] Is Ready", template_path:"conversion_mailer", template_name: "complete")
  end

  def hold(conversion)
    @list = conversion.listservlist.filename[0..-6].upcase
    @pw = conversion.listservlist.pw
    message = "From: lstadmin@listserv.nd.edu\nTo: listserv@listserv.nd.edu\nSubject: \nHOLD #{@list} PW=#{@pw}\n"
    Net::SMTP.start('listserv.nd.edu') do |smtp|
      smtp.send_message message, 'lstadmin@listserv.nd.edu', 'listserv@listserv.nd.edu'
    end
  end

  def failed(conversion)
    @owner = conversion.owner
    @group_address = conversion.address
    @group_name = conversion.title
    @listserv_address = conversion.listservlist.address
    @listserv_name = conversion.listservlist.title
    mail(to: @owner, from: ENV['SMTP_USER'], subject: "Listserv conversion failed for #{@listserv_name}.")
  end

  def undo(requester, conversion)
    @list = conversion.listservlist.filename[0..-6].upcase
    @group_name = conversion.title
    @group_address = conversion.address
    @listserv_address = conversion.listservlist.address
    mail(to: requester, from: ENV['SMTP_USER'], subject: "Google Group [#{@group_name}] Has Been Removed", template_path:'conversion_mailer', template_name:'undo_notice')
  end

  def free(conversion)
    @list = conversion.listservlist.filename[0..-6].upcase
    @pw = conversion.listservlist.pw
    message = "From: lstadmin@listserv.nd.edu\nTo: listserv@listserv.nd.edu\nSubject: \nFREE #{@list} PW=#{@pw}\n"
    Net::SMTP.start('listserv.nd.edu') do |smtp|
      smtp.send_message message, 'lstadmin@listserv.nd.edu', 'listserv@listserv.nd.edu'
    end
  end

  def disc(list_address, requester)
    @list_address = list_address
    mail(to: requester, from: ENV['SMTP_USER'], subject: "Listserv [#{list_address}] Has Been Discontinued", template_path: 'conversion_mailer', template_name: 'disc_notice')
  end

end
