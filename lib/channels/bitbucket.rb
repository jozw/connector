# encoding: UTF-8

require 'bitbucket_rest_api'
require 'open-uri'

service 'bitbucket' do
  listener 'push' do
    start do |data|
      account_username = data['username']
      account_password = data['password']
      username, repo   = data['repo'].split('/')
      branch           = data['branch'] || 'master'

      fail 'Must specify username' unless account_username
      fail 'Must specify password' unless account_password
      fail 'Must specify repo username & password' if !username || !repo
      fail 'Branch cant be empty' if branch.empty?

      info 'Connecting to Bitbucket'
      begin
        creds = {
          login: account_username,
          password: account_password
        }
        bitbucket = BitBucket.new creds
      rescue
        fail 'Failed to connect to BitBucket. Try re-activating Bitbucket service.'
      end

      hook_url = web_hook id: 'post_receive' do
        start do |listener_start_params, hook_data, _req, _res|
          zip_uri = "https://#{listener_start_params['username']}:#{listener_start_params['password']}@bitbucket.org/#{username}/#{repo}/get/#{branch}.zip"
          response_data = hook_data.merge('content' => zip_uri)
          start_workflow response_data
        end
      end

      info 'Checking for existing hook'
      begin
        hook = bitbucket.repos.services.list(username, repo).find do |h|
          service      = h['service']
          right_hook   = service['fields'][0]['value'] == hook_url
          right_method = service['type'] == 'POST'
          right_url    = service['fields'][0]['name'] == 'URL'
          right_hook && right_method && right_url
        end

        if hook
          bitbucket_webhook_id = hook['id']
          info 'Found existing hook'
        end
      rescue
        fail "Couldn't get list of existing hooks. Check username/repo."
      end

      unless bitbucket_webhook_id
        info 'Creating hook in BitBucket'
        begin
          bitbucket_hook_settings = {
            'type'  => 'POST',
            'URL'   => hook_url
          }
          bitbucket_webhook_id = bitbucket.repos.services.create(username, repo, bitbucket_hook_settings)['id']
        rescue
          fail 'Hook creation in BitBucket failed'
        end
        info "Created hook with id '#{bitbucket_webhook_id}'"
      end
    end

    stop do |data|
      username = data['username']
      repo     = data['repo']
      hook_url = get_web_hook('post_receive')

      info 'Connecting to BitBucket'
      begin
        creds = {
          login:    data['account_username'],
          password: data['account_password']
        }
        bitbucket = BitBucket.new creds
      rescue
        fail 'Connection failed. Try re-activating BitBucket in the sevices page.'
      end

      info 'Pulling up the hook info from BitBucket'
      begin
        hook = bitbucket.repos.services.list(username, repo).find do |h|
          service      = h['service']
          right_hook   = service['fields'][0]['value'] == hook_url
          right_method = service['type'] == 'POST'
          right_url    = service['fields'][0]['name'] == 'URL'
          right_hook && right_method && right_url
        end
      rescue
        fail 'Getting info about the hook from BitBucket failed'
      end

      fail "Hook wasn't found." unless hook

      info 'Deleting hook'
      begin
        bitbucket.repos.services.delete username, repo, hook['id']
      rescue
        fail 'Deleting hook failed'
      end
      {}
    end
  end

end
