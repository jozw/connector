require 'github_api'
require 'open-uri'

def get_github_definition
  require 'nokogiri'
  require 'open-uri'
  url='https://developer.github.com/v3/activity/events/types/'

  github_events=[]

  doc = Nokogiri::HTML(open(url))

  doc.css('#markdown-toc > li > a').each do |link|

    css_id      = link['href']
    header      = doc.css(css_id)

    name                = header[0].content.gsub(/([a-z])([A-Z])/,'\1 \2').gsub(' Event','') # add space between lowercase followed by upper case
    description_element = header[0].next_element
    descriptions        = []

    begin
      descriptions << description_element.text.gsub("\n",' ')
      description_element = description_element.next_element
    end while description_element.name=='p'
    description=descriptions.join(' ')

    id_element = description_element.next_element

    id = id_element.text


    table_element = id_element.next_element.next_element

    event={id:id,description:description,name:name,output:[]}

    table_element.css('tbody > tr').each do |row|
      output_id,output_type,output_description = row.css('td').map{|e| e.text}



      output_name = output_id.gsub('[]','').gsub('[',' ').gsub(']','').gsub('_',' ').split(' ').map do |w|

        if w=='url' || w=='html' || w=='sha' || w=='uri'
          w.upcase
        else
          w.capitalize
        end

      end.join(' ')
      event[:output] << {id:output_id,name:output_name,description:output_description}
    end
    github_events << event
  end

  github_events
end

@@github_events||=get_github_definition

service 'github' do

  @@github_events.each do |github_event|

    listener github_event[:id] do

      start do |data|

        api_key=data['api_key']
        username=data['username']
        repo=data['repo']

        if !username && repo.include?('/')
          username,repo=repo.split('/')
        end

        branch=data['branch'] || 'master'

        fail 'No credentials provided. Please connect Github from the Services page.' if !api_key
        fail "No username provided. Please set the value for 'username'" if !username
        fail "No repo provided, please set the value for 'repo'" if !repo

        info 'connecting to Github'
        begin
          github = Github.new oauth_token: api_key
        rescue => ex
          fail 'Failed to connect to github. Try re-activating Github service.', exception: ex
        end


        hook_url = web_hook id:'post_receive' do
          start do |listener_start_params,data,req,res|
            received_branch = data['ref'].split('/')[-1] if data['ref']

            if data['zen']
              warn "Received ping for hook '#{data['hook_id']}'. Not triggering a workflow since this is not a push."
            elsif received_branch!=branch && github_event[:id]=='push'
              warn "Received hook, but incorrect branch. Expected '#{branch}', got '#{received_branch}'"
            else
              access_query="access_token=#{api_key}"

              info 'Getting the Archive URL of the repo'
              begin
                archive_url_template=github.repos.get(user:username, repo:repo).archive_url
                download_ref_uri=URI(archive_url_template.sub('{archive_format}','zipball/').sub('{/ref}',branch))
              rescue => ex
                fail 'Failed to get archive URL from Github', exception: ex
              end

              if download_ref_uri
                info "Downloading the repo from Github (#{download_ref_uri})"
                begin
                  client = Net::HTTP.new(download_ref_uri.host, download_ref_uri.port)
                  client.use_ssl = true
                  response = client.get("#{download_ref_uri.path}?#{access_query}")
                  location = response['location']
                  data['content'] = URI("#{location}#{location.include?('?') ? '&' : '?' }#{access_query}")
                rescue => ex
                  fail 'Failed to download the repo from Github', exception:ex
                end

                start_workflow data
              end
            end
          end
        end

        info 'Checking for existing hook'
        begin
          hooks = github.repos.hooks.list(username,repo).select{|h| h['config'] && h['config']['url'] && h['config']['url']==hook_url}
          if hooks.count>0
            github_webhook_id = hooks.first.id
            info 'Found existing hook'
          end
        rescue => ex
          fail "Couldn't get list of existing hooks. Check username/repo.", exception:ex
        end

        unless github_webhook_id
          info "Creating hook to '#{hook_url}' on #{username}/#{repo}."
          begin
            github_config={'url'=>hook_url,'content_type'=>'json'}
            github_settings={'name'=> 'web','active'=> true,'config'=>github_config, 'events'=>github_event[:id]}
            github_webhook_id = github.repos.hooks.create(username, repo, github_settings).id
          rescue => ex
            fail 'Hook creation in Github failed', state:'stopped', exception: ex
          end
          info "Created hook with id '#{github_webhook_id}'"
        end
      end

      stop do |data|
        begin
          api_key=data['api_key']
          username=data['username']
          repo=data['repo']
        rescue
          fail "One of the required parameters (api_key, username, repo) isn't set"
        end

        hook_url=get_web_hook('post_receive')

        info 'Connecting to Github'
        begin
          github = Github.new oauth_token: api_key
        rescue
          fail 'Connection failed. Try re-activating Github in the sevices page.', {state:'started'}
        end

        info 'Pulling up the hook info from Github'
        begin
          hooks = github.repos.hooks.list(username,repo)
          hook = hooks.select{|h| h['config'] && h['config']['url'] && h['config']['url']==hook_url}.first
        rescue
          fail 'Getting info about the hook from Github failed', {state:'stopped'}
        end


        if !hook
          fail "Hook wasn't found.", {state:'stopped'}
        else
          info 'Deleting hook'
          begin
            github.repos.hooks.delete username, repo, hook.id
          rescue
            fail 'Deleting hook failed', {state:'started'}
          end
        end
      end
    end
  end

  action 'download' do

    start do |params|

      api_key=params['api_key']
      username=params['username']
      repo=params['repo']
      branch=params['branch'] || 'master'

      username,repo=repo.split('/') if repo && repo.include?('/') && !username
      repo,branch = repo.split('#') if repo && repo.include?('#')

      fail 'Repo must be defined' if !repo
      fail 'API Key must be defined' if !api_key
      fail 'Username must be define' if !username

      info 'Connecting to Github'
      begin
        github = Github.new oauth_token: api_key
      rescue
        fail 'Failed to connect to github. Try re-activating Github service.', {state:'stopped'}
      end

      info 'Getting the Archive URL of the repo'
      begin
        archive_url_template=github.repos.get(user:username, repo:repo).archive_url
        download_ref_uri=URI(archive_url_template.sub('{archive_format}','zipball').sub('{/ref}',"/#{branch}"))
      rescue => ex
        fail 'Failed to get archive URL from Github', exception: ex
      end

      info 'Downloading the repo from Github'
      begin
        client = Net::HTTP.new(download_ref_uri.host, download_ref_uri.port)
        client.use_ssl = true
        access_query="access_token=#{api_key}"
        response = client.get("#{download_ref_uri.path}?#{access_query}")
        response_data = {content: "#{response['location']}#{response['location'].include?('?') ? '&' : '?' }#{access_query}"}
      rescue => ex
        fail 'Failed to download the repo from Github', exception:ex
      end

      action_callback response_data
    end
  end

end
