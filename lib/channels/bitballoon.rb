# encoding: UTF-8

require 'bitballoon'
require 'tempfile'
require 'open-uri'

service 'bitballoon' do
  action 'deploy' do |params|
    api_key = params['api_key']
    site_id = params['site'] || params['site_id']
    content = params['content']

    fail 'API Key must be specified' unless api_key
    fail 'Site ID must be spcified' unless site_id
    fail 'Content must be specified' unless content

    info 'Getting the resource files from previous step'
    begin
      source = Tempfile.new('source')
      source.write open(content).read
      source.rewind
    rescue => ex
      fail 'Internal error: failed to get resource files', exception: ex
    end

    begin
      bitballoon_settings = {
        client_id:      BITBALLOON_OAUTH_ID,
        client_secret:  BITBALLOON_OAUTH_SECRET,
        access_token:   api_key
      }
      bb = BitBalloon::Client.new(bitballoon_settings)
    rescue => ex
      fail "Couldn't initialize BitBalloon connection", exception: ex
    end

    begin
      site = begin
        bb.sites.get(site_id)
      rescue
        bb.sites.get("#{site_id}.bitballoon.com")
      end
    rescue => BitBalloon::Client::AuthenticationError
      fail 'API Key is incorrect. Try refreshing.'
    end
    fail "No site found with name, id or url `#{site_id}`" if !site

    begin
      site.update(zip: source)
    rescue => ex
      fail 'BitBalloon had an error when uploading the site.', exception: ex
    end

    info 'Waiting for processing'
    begin
      site.wait_for_ready do |site_state|
        info "Polling state '#{site_state.state}'"
      end
    rescue
      warn "Couldn't poll status"
    end

    deploy_info = begin
        site.deploys.find { |d| d.state == 'current' }.attributes
      rescue
        {}
      end
    action_callback deploy_info
  end
end
