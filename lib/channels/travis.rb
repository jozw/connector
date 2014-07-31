# encoding: UTF-8

require 'travis'

service 'travis' do

  action 'rebuild' do |params|
    repo_slug    = params['repo']
    access_token = params['access_token']
    github_token = params['github_token']
    use_pro      = params['pro']
    build_number = params['build']

    fail 'Must specify repo (e.g. rails/rails)' unless repo_slug
    unless access_token || github_token
      fail 'Must specify access_token or github_token'
    end

    travis = use_pro ? Travis::Pro : Travis

    product_name = use_pro ? 'Travis Pro' : 'Travis'
    token_type   = access_token ? 'access' : 'Github'

    info "Connecting to #{product_name} with #{token_type} token"
    begin
      if access_token
        travis.access_token = access_token
      elsif github_token
        travis.github_auth github_token
      end
      user = travis::User.current
      info "Connected with user #{user.name}"
    rescue
      fail 'Token is incorrect'
    end

    info "Looking up repo `#{repo_slug}`"
    begin
      repo = travis::Repository.find(repo_slug)
    rescue
      fail "Failed to find the repo '#{repo_slug}'"
    end

    begin
      if build_number
        info "Looking up build #{build_number}"
        build = repo.build(build_number)
      else
        info 'Looking up last build'
        build = repo.last_build
        info "Found build ##{build.number}"
      end
    rescue
      fail 'Failed to find the build'
    end

    info "Restarting build ##{build.number}"
    begin
      build.restart
    rescue
      fail 'Failed to restart the build'
    end

    build_info = {
      repository_id: build.repository_id,
      commit_id: build.commit_id,
      number: build.number,
      pull_request: build.pull_request,
      pull_request_number: build.pull_request_number,
      pull_request_title: build.pull_request_title,
      config: build.config,
      state: build.state,
      started_at: build.started_at,
      finished_at: build.finished_at,
      duration: build.duration,
      job_ids: build.job_ids
    }

    action_callback build_info
  end
end
