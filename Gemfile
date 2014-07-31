source 'https://rubygems.org'

gem 'sinatra', '1.4.4'
gem 'sinatra-contrib', '1.4.1'
gem 'thin', '1.5.1'
gem 'rest-client', '1.6.7'
gem 'awesome_print','1.2.0'
gem 'foreman'
gem 'sinatra-websocket'
gem 'addressable'
gem 'celluloid'
gem 'rubyzip'
gem 'faye-websocket'

group :channels do
  # Hipchat Channel
  group :hipchat do
    gem 'httparty'
    gem 'httmultiparty'
  end

  # Github Channel
  group :github do
    gem 'github_api','0.11.3'
  end

  # AWS, Rackspace, etc Channels
  group :iaas do
    gem 'fog','1.15.0'
  end

  # SSH Channel
  group :ssh do
    gem 'net-sftp','2.1.2'
    gem 'net-ssh','2.7.0'
    gem 'net-scp','1.1.2'
    gem 'sshkey','1.6.0'
  end

  group :heroku do
    gem 'heroku-anvil-factor','0.15.0'
    gem 'heroku-api','0.3.15'
  end

  group :cloudfoundry do
    gem 'cfoundry','1.0.0'
  end


  group :bitbucket do
    gem 'bitbucket_rest_api'
  end

  group :timer do
    gem 'rufus-scheduler'
  end

  group :mail do
    gem 'mail'
  end

  group :gitlab do
    gem 'gitlab'
  end

  group :bitballoon do
    gem 'bitballoon'
  end

  group :gitter do
    gem 'eventmachine'
    gem 'em-http-request'
  end

  group :travis do
    gem 'travis'
  end
end

group :development do
  gem 'debugger'
end

