require 'net/ssh'
require 'net/scp'
require 'net/sftp'
require 'tempfile'
require 'securerandom'
require 'uri'


service 'ssh' do

  action 'execute' do
    
    start do |params|
      output=''
      command_lines={}

      info 'Setting up private key'
      begin
        key_file = Tempfile.new('private')
        key_file.write(params['private_key'])
        key_file.close
      rescue
        fail 'Failed to setup private key'
      end

      info 'Parsing input variables'
      begin
        uri       = URI("ssh://#{params["host"]}")
        host      = uri.host
        port      = uri.port || params['port']
        user      = uri.user || params['username']

        ssh_settings={:keys=>[key_file.path]}
        ssh_settings[:port]=port if port
        commands = params['command'].split(/;|\n/) if params['command'].is_a?(String)
        commands ||= params['command'] if params['command'].is_a?(Array)
        commands ||= params['commands'].split(/;|\n/) if params['commands'].is_a?(String)
        commands ||= params['commands'] if params['commands'].is_a?(Array)
      rescue => ex
        fail "Couldn't parse input parameters", exception: ex
      end

      fail "Couldn't parse the command" if !commands
      fail 'The user was never specified. Please set username value or provide username in host' if !user
      fail "You must specify a value for 'host'" if !host

      begin
        Net::SSH.start(host, user, ssh_settings) do |ssh|
          commands.each_with_index do |command,index|
            info "Executing '#{command}'"
            output_lines = ssh.exec!(command)
            output_lines = output_lines.to_s.encode('UTF-8', {:invalid => :replace, :undef => :replace, :replace => '?'})
            output << output_lines
            command_lines[index.to_s]={:line=>Hash[*output_lines.split("\n").each_with_index.map{|l,i|[i.to_s,l]}.flatten],:all=>output_lines}
          end
        end
      rescue Net::SSH::AuthenticationFailed
        fail 'Authentication failure, check your SSH key, username, and host'
      rescue => ex
        fail "Couldn't connect to the server #{user}@#{host}:#{port || '22'}, please check credentials.", exception:ex
      end

      info 'Cleaning up.'
      begin
        key_file.unlink
      rescue
        warn 'Failed to clean up, but no worries, work will go on.'
      end
      action_callback line: Hash[*output.split("\n").each_with_index.map{|l,i|[i.to_s,l]}.flatten], all: output, command: command_lines
    end
  end


  action 'upload' do
    start do |params|
      content = params['content']

      info 'Setting up private key'
      begin
        output=''
        key_file = Tempfile.new('private')
        private_key=params['private_key']
        key_file.write(private_key)
        key_file.rewind
        key_file.close
      rescue
        fail 'Private key setup failed'
      end

      info 'Getting resource'
      begin
        source = Tempfile.new('source')
        source.write open(content).read
        source.rewind
      rescue
        fail 'Getting the resource failed'
      end

      info 'Parsing input variables'
      begin
        uri       = URI("ssh://#{params["host"]}")
        host      = uri.host
        port      = uri.port || params['port']
        user      = uri.user || params['username']

        ssh_settings={:keys=>[key_file.path]}
        ssh_settings[:port]=port if port
      rescue
        fail "couldn't parse input parameters"
      end

      begin
        remote_directory=params['remote_path'] + (params['remote_path'][-1]=='/' ? '' : '/')
      rescue
        fail "The remote path '#{params['remote_path']}' was unparsable"
      end

      fail "The path #{remote_directory} must be an absolute path" if remote_directory[0]!='/'

      zip_code=SecureRandom.hex
      zip_filename="#{zip_code}.zip"
      zip_path="#{remote_directory}#{zip_filename}"
      unzip_path="#{remote_directory}#{zip_code}/"

      begin
        Net::SSH.start(host, user, ssh_settings) do |ssh|
          source_path=File.absolute_path(source)

          Zip::ZipFile.open(source_path) do |zipfile|
            root_path=zipfile.first.name
            zipfile.each do |file|
              if file.file?
                remote_zip_path=file.name[root_path.length .. -1] if file.file?
                destination_path="#{remote_directory}#{remote_zip_path}"
                info "uploading #{destination_path}"
                file_contents=file.get_input_stream.read
                string_io=StringIO.new(file_contents)
                zip_dir_path=File.dirname(destination_path)
                begin
                  ssh.exec!("mkdir #{zip_dir_path}")
                rescue=>ex
                  fail "couldn't create the directory #{zip_dir_path}", exception:ex
                end
                begin
                  ssh.scp.upload!(string_io,destination_path)
                rescue=>ex
                  fail "couldn't upload #{destination_path}", exception:ex
                end
              end
            end
          end
        end
      rescue FactorChannelError
        raise
      rescue=>ex
        fail "Couldn't connect to the server #{user}@#{host}:#{port || '22'}, please check credentials.", exception:ex
      end
      key_file.unlink
      action_callback
    end
  end
end

