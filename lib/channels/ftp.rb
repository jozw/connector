# encoding: UTF-8

require 'net/ftp'
require 'tempfile'
require 'securerandom'
require 'uri'

service 'ftp' do
  action 'list' do |params|
    username  = params['username']
    password  = params['password']
    server    = params['endpoint']
    path      = params['path'] || '/'

    fail 'Server endpoint (address) is required' unless server
    fail 'Path cant be empty' if path.empty?

    files = []
    begin
      Net::FTP.open(server) do |ftp|
        if username && password
          ftp.login(username, password)
        else
          ftp.login
        end
        files = ftp.list(path)
      end
    rescue => ex
      fail "Couldn't connect to the server #{username}@#{server}, please check credentials.", exception: ex
    end

    action_callback files: files
  end
end
