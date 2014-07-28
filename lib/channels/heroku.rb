# encoding: UTF-8

require 'json'
require 'rest-client'
require 'heroku-api'
require 'anvil'
require 'anvil/engine'
require 'uri'
require 'zip'
require 'zip/zip'
require 'zip/zipfilesystem'
require 'tmpdir'
require 'oauth2'
require 'open-uri'
require 'tempfile'

service 'heroku' do
  action 'deploy' do |params|
    app      = params['app']
    content  = params['content']
    user     = 'factorbot'
    api_key  = params['api_key']

    fail 'No content specified. What am I supposed to deploy?' unless content
    fail 'No app specified. Where am I supposed to deploy it?' unless app
    fail 'You need to activate Heroku on the services page' unless api_key

    def release(api_key, app, description, slug_url)
      payload = {
        description: description,
        slug_url: slug_url
      }

      options = {
        'User-Agent'       => 'heroku-push-cli/0.7-ALPHA',
        'X-Ruby-Version'   => RUBY_VERSION,
        'X-Ruby-Platform'  => RUBY_PLATFORM,
        :content_type => :json,
        :accept => :json
      }

      release_uri = "https://:#{api_key}@cisaurus.heroku.com/v1/apps/#{app}/release"

      response = RestClient.post release_uri, JSON.generate(payload), options
      while response.code == 202
        release_status_uri = "https://:#{api_key}@cisaurus.heroku.com/#{response.headers[:location]}"
        response = RestClient.get release_status_uri, options
        sleep(1)
      end
      JSON.parse response
    end

    info 'Getting the resource files from previous step'
    begin
      source = Tempfile.new('source')
      source.write open(content).read
      source.rewind
    rescue => ex
      fail 'Internal error: failed to get resource files', exception: ex
    end

    info 'Unzipping file'
    begin
      temp_dir = Dir.mktmpdir
      Zip::ZipFile.open(source) do |zip_file|
        zip_file.each do |f|
          f_path = File.join(temp_dir, f.name)
          FileUtils.mkdir_p(File.dirname(f_path))
          zip_file.extract(f, f_path) unless File.exist?(f_path)
        end
      end

      if File.directory?(temp_dir)
        dir_list = Dir.glob("#{temp_dir}/*")
        temp_dir = dir_list[0] if dir_list.length == 1
      end
    rescue => ex
      fail 'Unzip failed', exception: ex
    end

    info "Building the buildpack using Heroku's Anvil service"
    begin
      Anvil.append_agent '(heroku-push)'
      Anvil.headers['X-Heroku-App']  = app

      begin
        capture = StringIO.new
        old_std = $stdout
        $stdout = capture

        slug_url = Anvil::Engine.build(temp_dir)
        begin
          $stdout.string.split("\n").each do |line|
            info line
          end
        rescue
          warn "Build completed but couldn't pull up results of build."
        end
      ensure
        $stdout = old_std
      end
    rescue => ex
      fail 'Build failed', exception:ex
    end

    info 'Pushing buildpack to Heroku'
    begin
      release = release(api_key, app, "Pushed by #{user}", slug_url)
      info "Release `#{release['release']}` complete"

      action_callback release
    rescue => ex
      fail "Upload failed: #{ex.message}", exception: ex
    end
  end
end
