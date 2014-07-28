# encoding: UTF-8

require 'gitlab'
require 'open-uri'

service 'gitlab' do
  listener 'push' do
    start do |data|
      endpoint       = data['endpoint'] || 'https://gitlab.com/api/v3/'
      token          = data['token'] || data['api_key']
      username, repo = data['repo'].split('/')
      branch         = data['branch'] || 'master'

      fail 'Endpoint cant be empty' if endpoint.empty?
      fail 'Token is required' unless token
      fail 'Username/Repo is required' if !username || !repo
      fail 'Branch cant be empty' if branch.empty?

      info "Connecting to Gitlab on #{endpoint}"
      begin
        gitlab_settings = {
          endpoint: endpoint,
          private_token: token,
          user_agent: 'Factor.io Agent'
        }
        gitlab = Gitlab.client(gitlab_settings)
        all_projects = []
        page = 0
        loop do
          projects = gitlab.projects(per_page: 100, page: page)
          all_projects.concat projects
          page += 1
          break unless projects.count == 100
        end
        project = all_projects.find do |p|
          p.path_with_namespace == "#{username}/#{repo}"
        end
      rescue => ex
        fail 'Failed to connect to Gitlab. Check creds.', exception: ex
      end

      hook_url = web_hook id: 'post_receive' do
        start do |listener_start_params, hook_data, _req, _res|
          endpoint        = listener_start_params['endpoint']
          token           = listener_start_params['token']
          username        = listener_start_params['username']
          repo            = listener_start_params['repo']
          branch          = listener_start_params['branch'] || 'master'
          received_branch = hook_data['ref'].split('/')[-1]

          if received_branch != branch
            warn 'Received hook, but incorrect branch.'
            warn "Expected '#{branch}', got '#{received_branch}'"
          else
            info 'Pulling up information about repo'
            begin
              project = gitlab.projects.find do |p|
                p.path_with_namespace == "#{username}/#{repo}"
              end
            rescue
              fail "Couldn't find the repo #{username}/#{repo}"
            end

            fail "Couldn't find the repo #{username}/#{repo}" unless project

            url = "#{endpoint}projects/#{project.id}/repository/archive.zip"
            url_with_ref   = "#{url}?ref=#{branch}"
            url_with_token = "#{url_with_ref}&private_token=#{token}"

            start_workflow content: url_with_token
          end

        end
      end

      info 'Checking for existing hook'
      begin
        hook = gitlab.project_hooks(project.id).find do |h|
          h.url == hook_url
        end

        if hook
          webhook_id = hook.id
          info 'Found existing hook'
        end
      rescue
        fail "Couldn't get list of existing hooks. Check username/repo."
      end

      unless webhook_id
        info 'Creating hook in Gitlab'
        begin
          webhook = gitlab.add_project_hook(project.id, hook_url)
          webhook_id = webhook.id
        rescue => ex
          fail 'Hook creation in Github failed', exception: ex
        end
        info "Created hook with id '#{webhook_id}'"
      end
    end

    stop do |data|
      endpoint       = data['endpoint'] || 'https://gitlab.com/api/v3/'
      token          = data['token'] || data['api_key']
      username, repo = data['repo'].split('/')
      branch         = data['branch'] || 'master'

      fail 'Endpoint cant be empty' if endpoint.empty?
      fail 'Token is required' unless token
      fail 'Username/Repo is required' if !username || !repo
      fail 'Branch cant be empty' if branch.empty?

      info "Connecting to Gitlab on #{endpoint}"
      begin
        gitlab_settings = {
          endpoint: endpoint,
          private_token: token,
          user_agent: 'Factor.io Agent'
        }
        gitlab = Gitlab.client(gitlab_settings)
        all_projects = []
        page = 0
        loop do
          projects = gitlab.projects(per_page: 100, page: page)
          all_projects.concat projects
          page += 1
          break unless projects.count == 100
        end
        project = all_projects.find do |p|
          p.path_with_namespace == "#{username}/#{repo}"
        end
      rescue => ex
        fail 'Failed to connect to Gitlab. Check creds.', exception: ex
      end

      fail "Couldn't find project #{username}/#{repo}" unless project

      hook_url = get_web_hook('post_receive')
      begin
        hooks = gitlab.project_hooks(project.id).select do |h|
          h.url == hook_url
        end
      rescue
        fail 'Getting info about the hook from Github failed'
      end

      if !hooks || hooks.count == 0
        fail 'Hook wasnt found.'
      else
        info "Found #{hooks.count} hooks to delete"
        begin
          hooks.each do |hook|
            info "Deleting hook with id #{hook.id}"
            gitlab.delete_project_hook(project.id, hook.id)
          end
        rescue
          fail 'Deleting hook failed'
        end
      end
    end
  end

  action 'download_repo' do |data|
    endpoint       = data['endpoint'] || 'https://gitlab.com/api/v3/'
    token          = data['token'] || data['api_key']
    username, repo = data['repo'].split('/')
    branch         = data['branch'] || 'master'

    fail 'Endpoint cant be empty' if endpoint.empty?
    fail 'Token is required' unless token
    fail 'Username/Repo is required' if !username || !repo
    fail 'Branch cant be empty' if branch.empty?

    info "Connecting to Gitlab on #{endpoint}"
    begin
      gitlab_settings = {
        endpoint: endpoint,
        private_token: token,
        user_agent: 'Factor.io Agent'
      }
      gitlab = Gitlab.client(gitlab_settings)
      all_projects = []
      page = 0
      loop do
        projects = gitlab.projects(per_page: 100, page: page)
        all_projects.concat projects
        page += 1
        break unless projects.count == 100
      end
      project = all_projects.find do |p|
        p.path_with_namespace == "#{username}/#{repo}"
      end
    rescue => ex
      fail 'Failed to connect to Gitlab. Check creds.', exception: ex
    end

    fail "Couldn't find the repo #{username}/#{repo}" unless project

    url = "#{endpoint}projects/#{project.id}/repository/archive.zip"
    url_with_ref   = "#{url}?ref=#{branch}"
    url_with_token = "#{url_with_ref}&private_token=#{token}"

    action_callback content: url_with_token
  end
end
