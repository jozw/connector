require 'gitlab'
require 'open-uri'

service 'gitlab-com' do
  listener 'push' do
    start do |data|
      begin
        endpoint       = data['endpoint'] || 'https://gitlab.com/api/v3/'
        token          = data['token'] || data['api_key']
        username, repo = data['repo'].split('/')
        branch         = data['branch'] || 'master'
      rescue
        fail "One of the required variables (api_key, username, repo) isn't set"
      end

      info "connecting to Gitlab on #{endpoint}"
      begin
        gitlab_settings = {
          endpoint:       endpoint,
          private_token:  token,
          user_agent:     'Factor.io Agent'
        }
        gitlab = Gitlab.client(gitlab_settings)
        all_projects = []
        page = 0
        begin
          projects = gitlab.projects(per_page: 100, page: page)
          all_projects.concat projects
          page=page+1
        end while projects.count == 100
        project = all_projects.select{|project| project.path_with_namespace == "#{username}/#{repo}"}.first
      rescue => ex
        fail 'Failed to connect to Gitlab. Check creds.', exception:ex, state:'stopped'
      end

      hook_url = web_hook id:'post_receive' do
        start do |listener_start_params, data, req, res|
          endpoint = listener_start_params['endpoint']
          token    = listener_start_params['token']
          username = listener_start_params['username']
          repo     = listener_start_params['repo']
          branch   = listener_start_params['branch'] || 'master'
          received_branch = data['ref'].split('/')[-1]

          if received_branch != branch
            warn "Received hook, but incorrect branch. Expected '#{branch}', got '#{received_branch}'"
          else
            info 'Pulling up information about repo'
            begin
              project = gitlab.projects.select do |p|
                p.path_with_namespace == "#{username}/#{repo}"
              end.first
            rescue
              fail "Couldn't find the repo #{username}/#{repo}"
            end

            fail "Couldn't find the repo #{username}/#{repo}" if !project

            url            = "#{endpoint}projects/#{project.id}/repository/archive.zip?ref=#{branch}"
            url_with_token = "#{url}&private_token=#{token}"

            start_workflow content: url_with_token
          end
        end
      end

      info 'Checking for existing hook'
      begin
        hooks = gitlab.project_hooks(project.id).select do |h|
          h.url == hook_url
        end
        if hooks.count > 0
          webhook_id = hooks.first.id
          info 'Found existing hook'
        end
      rescue
        fail "Couldn't get list of existing hooks. Check username/repo.", state:'stopped'
      end

      unless webhook_id
        info 'Creating hook in Gitlab'
        begin
          webhook_id = gitlab.add_project_hook(project.id,hook_url).id
        rescue => ex
          fail 'Hook creation in Github failed', state:'stopped', exception: ex
        end
        info "Created hook with id '#{webhook_id}'"
      end
    end

    stop do |data|
      begin
        endpoint    = data['endpoint']
        token       = data['token']
        username    = data['username']
        repo        = data['repo']
      rescue
        fail "One of the required variables (api_key, username, repo) isn't set"
      end

      info 'Connecting to Gitlab'
      begin
        gitlab_settings = {
          endpoint:       endpoint,
          private_token:  token,
          user_agent:     'Factor.io Agent'
        }
        gitlab = Gitlab.client(gitlab_settings)
        all_projects = []
        page = 0
        begin
          projects = gitlab.projects(per_page: 100, page: page)
          all_projects.concat projects
          page = page + 1
        end while projects.count == 100
        project = all_projects.select{|project| project.path_with_namespace == "#{username}/#{repo}"}.first
      rescue
        fail 'Connection failed. Check endpoint and token.', state:'started'
      end

      fail "Couldn't find project #{username}/#{repo}" if !project

      hook_url=get_web_hook('post_receive')
      begin
        hooks = gitlab.project_hooks(project.id).select{|h| h.url==hook_url}
      rescue
        fail 'Getting info about the hook from Github failed', state:'stopped'
      end

      if !hooks || hooks.count == 0
        fail "Hook wasn't found.", state:'stopped'
      else
        info "Found #{hooks.count} hook#{hooks.count>1 ? 's' : ''} to delete"
        begin
          hooks.each do |hook|
            info "Deleting hook with id #{hook.id}"
            gitlab.delete_project_hook(project.id,hook.id)
          end
        rescue
          fail 'Deleting hook failed', state:'started'
        end
      end
    end
  end

  action 'download_repo' do |data|
    begin
      endpoint       = data['endpoint'] || 'https://gitlab.com/api/v3/'
      token          = data['token'] || data['api_key']
      username, repo = data['repo'].split('/')
      branch         = data['branch'] || 'master'
    rescue
      fail "One of the required variables (api_key, username, repo) isn't set"
    end

    info "Connecting to Gitlab on #{endpoint}"
    begin
      gitlab_settings = {
        endpoint:       endpoint,
        private_token:  token,
        user_agent:     'Factor.io Agent'
      }
      gitlab = Gitlab.client(gitlab_settings)
      all_projects = []
      page = 0
      begin
        projects = gitlab.projects(per_page: 100, page: page)
        all_projects.concat projects
        page = page+1
      end while projects.count == 100
      project = all_projects.select do |p|
        p.path_with_namespace == "#{username}/#{repo}"
      end.first
    rescue => ex
      fail 'Failed to connect to Gitlab. Check creds.', exception: ex
    end

    fail "Couldn't find the repo #{username}/#{repo}" if !project

    url            = "#{endpoint}projects/#{project.id}/repository/archive.zip?ref=#{branch}"
    url_with_token = "#{url}&private_token=#{token}"

    action_callback content: url_with_token
  end
end
