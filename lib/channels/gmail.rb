# encoding: UTF-8

require 'mail'

service 'gmail' do
  action 'send' do |params|
    info 'Setting up parameters'

    password   = params['password']
    to         = params['to']
    message    = params['message']
    subject    = params['subject']
    username   = params['username']

    fail 'Username (email address) required' unless username
    fail 'Password required' unless password
    fail 'To address required' unless to
    fail 'Message required' unless message
    fail 'Subject required' unless subject

    email      = Mail::Address.new(username)
    domain     = email.domain
    address    = email.address
    settings   = {
      address:        'smtp.gmail.com',
      port:           587,
      domain:         domain,
      user_name:      address,
      password:       password,
      authentication: 'plain',
      enable_starttls_auto: true
    }
    email_info = {
      to:       to,
      from:     address,
      subject:  subject,
      body:     message
    }

    info 'Settig up email client'
    Mail.defaults do
      delivery_method :smtp, settings
    end

    info 'Sending email'
    begin
      mail_info = Mail.deliver email_info
    rescue => ex
      fail "Couldn't send message: #{ex.message}", exception: ex
    end
    action_callback mail_info
  end
end
