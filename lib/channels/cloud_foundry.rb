require 'cfoundry'

service 'cloudfoundry' do

  action 'deploy' do
    start do |params|
      endpoint  = params['endpoint']
      username  = params['username']
      password  = params['password']
      app       = params['app']
      content   = params['content']


      fail 'Endpoint must be specified' unless endpoint
      fail 'Username and password must be specified' if !username || !password
      fail 'App ID must be specified' unless app
      fail 'Content must be specified' unless content

      info "logging into '#{endpoint}'"
      begin
        cf = CFoundry::Client.new(endpoint)
        cf.login(username,password)
      rescue
        fail "failed to login with username #{username} to #{endpoint}"
      end

      info 'pulling up the resources for the workflow'
      begin
        source = Tempfile.new('source')
        source.write open(content).read
        source.rewind
      rescue
        fail 'Internal error: failed to get the needed resources.'
      end

      info "pulling up app #{app} and uploading new files"
      begin
        app = cf.app_by_name(app)
      rescue
        fail "failed to get #{app}"
      end

      info 'unzipping file for upload'
      begin
        temp_dir = Dir.mktmpdir
        Zip::ZipFile.open(source) { |zip_file|
          zip_file.each { |f|
            f_path=File.join(temp_dir, f.name)
            FileUtils.mkdir_p(File.dirname(f_path))
            zip_file.extract(f, f_path) unless File.exist?(f_path)
          }
        }
        if File.directory?(temp_dir)
          dir_list = Dir.glob("#{temp_dir}/*")
          temp_dir = dir_list[0] if dir_list.length==1
        end
      rescue
        fail 'failed to unzip files'
      end


      info 'uploading app...'
      begin
        app.upload(File.expand_path(temp_dir))
      rescue
        fail 'failed to upload app'
      end

      info 'restarting app...'
      begin
        app.restart!
      rescue
        fail "failed to restart #{params['app']}"
      end

      action_callback {}
    end

  end

end
