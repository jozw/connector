require 'net/ftp'
require 'tempfile'
require 'securerandom'
require 'uri'


service 'ftp' do
  action 'list' do
    start do |params|
      output=''
      command_lines={}
      username  = params['username']
      password  = params['password']
      server    = params['endpoint']
      path      = params['path'] || '/'

      fail 'You need to specify the credentials (username, password, endpoint)' if !username || !password || !endpoint

      files=[]
      begin
        Net::FTP.open(server) do |ftp|
          if username && password
            ftp.login(username,password)
          else
            ftp.login
          end
          files = ftp.list(path)
        end
      rescue => ex
        fail "Couldn't connect to the server #{username}@#{server}, please check credentials.", exception:ex
      end

      action_callback files:files
    end
  end
end
