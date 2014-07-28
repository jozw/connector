# encoding: UTF-8

require 'net/ssh'
require 'net/scp'
require 'net/sftp'
require 'tempfile'
require 'securerandom'
require 'uri'

service 'ssh' do
  action 'execute' do |params|
    host_param  = params['host']
    private_key = params['private_key']
    commands    = params['commands']

    fail 'Command is required' unless commands
    fail 'Commands must be an array of strings' unless commands.all? { |c| c.is_a?(String) }
    fail 'Host is required' unless host_param

    output = ''
    command_lines = {}

    info 'Setting up private key'
    begin
      key_file = Tempfile.new('private')
      key_file.write(private_key)
      key_file.close
    rescue
      fail 'Failed to setup private key'
    end

    begin
      uri       = URI("ssh://#{host_param}")
      host      = uri.host
      port      = uri.port
      user      = uri.user
    rescue => ex
      fail "Couldn't parse input parameters", exception: ex
    end

    ssh_settings = { keys: [key_file.path] }
    ssh_settings[:port] = port if port

    fail 'User (user) is required in host address' unless user
    fail 'Host variable must specific host address' unless host

    begin
      Net::SSH.start(host, user, ssh_settings) do |ssh|
        commands.each do |command|
          info "Executing '#{command}'"
          output_lines = ssh.exec!(command)
          encode_settings = {
            invalid: :replace,
            undef: :replace,
            replace: '?'
          }
          output_lines = output_lines.to_s.encode('UTF-8', encode_settings)
          output << output_lines
          command_lines << {
            lines: output_lines.split("\n"),
            all: output_lines
          }
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
    return_info = {
      line: output.split("\n"),
      all: output,
      command: command_lines
    }
    action_callback return_info
  end

  action 'upload' do |params|
    content = params['content']

    info 'Setting up private key'
    begin
      output = ''
      key_file = Tempfile.new('private')
      private_key = params['private_key']
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
      uri       = URI("ssh://#{params['host']}")
      host      = uri.host
      port      = uri.port || params['port']
      user      = uri.user || params['username']

      ssh_settings = { keys: [key_file.path] }
      ssh_settings[:port] = port if port
    rescue
      fail "couldn't parse input parameters"
    end

    begin
      trail = params['remote_path'][-1] == '/' ? '' : '/'
      remote_directory = "#{params['remote_path']}#{trail}"
    rescue
      fail "The remote path '#{params['remote_path']}' was unparsable"
    end

    fail "The path #{remote_directory} must be an absolute path" if remote_directory[0] != '/'

    begin
      Net::SSH.start(host, user, ssh_settings) do |ssh|
        source_path = File.absolute_path(source)

        Zip::ZipFile.open(source_path) do |zipfile|
          root_path = zipfile.first.name
          zipfile.each do |file|
            next unless file.file?
            remote_zip_path  = file.name[root_path.length .. -1]
            destination_path = "#{remote_directory}#{remote_zip_path}"
            info "Uploading #{destination_path}"
            file_contents = file.get_input_stream.read
            string_io     = StringIO.new(file_contents)
            zip_dir_path  = File.dirname(destination_path)
            begin
              ssh.exec!("mkdir #{zip_dir_path}")
            rescue => ex
              fail "couldn't create the directory #{zip_dir_path}", exception:ex
            end
            begin
              ssh.scp.upload!(string_io, destination_path)
            rescue => ex
              fail "couldn't upload #{destination_path}", exception:ex
            end
          end
        end
      end
    rescue FactorChannelError
      raise
    rescue => ex
      fail "Couldn't connect to the server #{user}@#{host}:#{port || '22'}, please check credentials.", exception:ex
    end
    key_file.unlink
    action_callback
  end
end
