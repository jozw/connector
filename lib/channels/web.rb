require 'restclient'

service 'web' do

  listener 'hook' do

    start do |data|
      info 'starting webhook'
      hook_id=data['id'] || 'post'
      hook_url = web_hook id: hook_id do
        start do |listener_start_params,data,req,res|
          info 'Got a Web Hook POST call'
          post_data=data.dup
          post_data.delete('service_id')
          post_data.delete('listener_id')
          post_data.delete('instance_id')
          post_data.delete('hook_id')
          post_data.delete('user_id')
          start_workflow({:response=>post_data})
        end
      end
      info "Webhook started at: #{hook_url}"
      uri=URI(hook_url)
      info "and #{uri.scheme}://#{uri.host}/v0.3/#{user_id}/#{hook_id}"
    end
    stop do |data|
    end
  end

  action 'post' do |params|
    begin
      if !params['query_string']
        contents={}
      elsif params['query_string'].is_a?(Hash)
        contents = params['query_string']
      elsif params['query_string'].is_a?(String)
        contents = JSON.parse(params['query_string'])
      else
        fail "Couldn't parse querystring"
      end
    rescue
      fail "Couldn't parse '#{params['query_string']}' as JSON"
    end

    begin
      if !params['headers']
        headers={}
      elsif params['headers'].is_a?(Hash)
        headers = params['headers']
      elsif
        headers = JSON.parse(params['headers'])
      else
        fail "couldn't parse headers"
      end
    rescue
      fail "Couldn't parse header"
    end
    if contents
      info "Posting to `#{params['url']}`"
      begin
        response = RestClient.post(params['url'],contents,headers)
        info 'Post complete'
        response
      rescue
        fail "Couldn't call '#{params['url']}'"
      end
    end
  end
end
