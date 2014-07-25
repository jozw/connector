require 'fog'
require 'sshkey'

service 'rackspace' do
  action 'create_server' do |params|
    info 'Connecting to Rackspace'
    begin
      connection = Fog::Compute.new({:provider=>'Rackspace',:rackspace_username=>params['username'],:rackspace_api_key=>params['api_key'],version: :v2})
    rescue
      fail "Failed to connect with username `#{params['username']}`"
    end
    server_settings={:name=>params['name'], :image_id=>params['image_id'], :flavor_id=>params['flavor_id'].to_i}
    info={}

    info 'Creating server. This may take a minute...'
    begin
      server = connection.servers.create(server_settings)
      password=server.password # need to save it because after the server is ACTIVE the password is removed
      server.wait_for { ready? }
      info.merge!(server.attributes)
      info['password']=password
    rescue
      fail 'Failed to create server'
    end
    action_callback info
  end

  action 'bootstrap_server' do |params|
    info 'Connecting to Rackspace'
    begin
      connection = Fog::Compute.new({:provider=>'Rackspace',:rackspace_username=>params['username'],:rackspace_api_key=>params['api_key'],version: :v2})
    rescue
      fail "Failed to connect with username `#{params['username']}`"
    end

    info 'Setting up private SSH Key'
    begin
      key = SSHKey.new(params['private_key'])
    rescue
      fail 'SSH Key creation failed'
    end
    
    info={}
    info 'Creating server. This may take a minute...'
    begin
      server_settings={
        :name=>params['name'],
        :image_id=>params['image_id'],
        :flavor_id=>params['flavor_id'].to_i,
        :public_key=>key.ssh_public_key,
        :private_key=>key.private_key,
        :username=>params['ssh_username']}
      server = connection.servers.bootstrap(server_settings)
      password=server.password # need to save it because after the server is ACTIVE the password is removed
      server.wait_for { ready? }
      info.merge!(server.attributes)
      info['password']=password
    rescue
      fail 'Failed to create server'
    end
    action_callback info
  end

  action 'list_servers' do |params|
    info 'Connecting to Rackspace'
    begin
      connection = Fog::Compute.new({:provider=>'Rackspace',:rackspace_username=>params['username'],:rackspace_api_key=>params['api_key'],version: :v2})
    rescue
      fail "Failed to connect with username `#{params['username']}`"
    end

    servers = []

    info 'Getting list of servers'
    begin
      connection.servers.each_with_index {|server,i| servers << server.attributes }
    rescue
      fail 'Failed to get list of servers'
    end

    action_callback servers:servers
  end

  action 'destroy_server' do |params|
    info 'Connecting to Rackspace'
    begin
      connection = Fog::Compute.new({:provider=>'Rackspace',:rackspace_username=>params['username'],:rackspace_api_key=>params['api_key'],version: :v2})
    rescue
      fail "Failed to connect with username `#{params['username']}`"
    end

    info "Getting server '#{params['server_id']}'"
    begin
      server = connection.servers.select { |server| server.id==params['server_id'] }.first
      if !server
        fail "No server with id #{params['server_id']} found"
      end
    rescue
      fail 'Failed to get server'
    end

    info "Destroying server #{params['server_id']}"
    begin
      server.destroy
      server_info = server.attributes
    rescue
      fail 'Failed to destroy server'
    end

    action_callback server_info
  end
end

