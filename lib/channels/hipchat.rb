# encoding: UTF-8

require 'httparty'

service 'hipchat' do
  listeners = %w(message notification exit enter topic_change)
  end
  listeners.each do |listener_name|
    listener listener_name do
      start do |params|
        room_id     = params['room_id'] || params['room']
        api_key     = params['api_key']
        filter      = params['filter']
        listener_id = "room_#{listener_name}"

        fail 'API Key is required' unless api_key
        fail 'Room ID is required' unless room_id
        fail 'Filter is required' if !filter && listener_name == 'message'

        hook_url = get_web_hook(listener_id)

        base       = 'https://api.hipchat.com/v2/'
        path       = ['room', room_id, 'webhook'].join('/')
        auth_query = "?auth_token=#{api_key}"
        uri        = base + path + auth_query

        headers = {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }

        info 'Getting hooks'
        begin
          http_response = HTTParty.get(uri, body: {}.to_json, headers: headers)
        rescue
          fail 'Could not get list of hooks. Check your creds.'
        end

        if http_response.body
          response = JSON.parse(http_response.body)
          if response['items']
            hook = response['items'].find { |h| h['url'] == hook_url }
          elsif response['error']
            fail "Couldn't create web hook: #{response['error']['message']}"
          end
        end

        if hook
          info 'Looks like this web hook is already registered'
          hook_id = hook['id']
        else
          info "Creating hook in `#{room_id}` room"
          begin
            body = {
              url: hook_url,
              event: listener_id,
              name: 'workflow'
            }
            body[:pattern] = filter if filter
            post_params = {
              body: body.to_json,
              headers: headers
            }
            http_response = HTTParty.post(uri, post_params)
          rescue
            fail 'Could not connect to Hipchat'
          end

          if http_response.body
            response = JSON.parse(http_response.body)
            if response['error']
              fail "Couldn't create web hook: #{response['error']['message']}"
            elsif response['id']
              hook_id = response['id']
            end
          end
        end

        hook_url = web_hook id: listener_id do
          start do |listener_start_params, hook_data, _req, _res|
            info 'Triggering workflow...'
            begin
              filter = listener_start_params['filter']

              if hook_data['item']['message'] && hook_data['item']['message']['message']
                original_message = hook_data['item']['message']['message']
                hook_data['message']  = original_message
              
                if filter
                  regexp               = Regexp.new(filter)
                  matches              = regexp.match(original_message).captures
                  hook_data['matches'] = matches
                end
              end
              
              hook_data['hook_id']  = hook_id
            rescue => ex
              fail "Couldn't parse message from Hipchat", exception: ex
            end

            begin
              start_workflow hook_data
            rescue => ex
              fail 'Internal error: failed to send message for next step', exception: ex
            end
          end
        end
      end

      stop do |params|
        room_id = params['room_id'] || params['room']
        api_key = params['api_key']

        fail 'API Key is required' unless api_key
        fail 'Room ID is required' unless room_id

        info "Deleting hook #{listener_name}"
        hook_url = get_web_hook(listener_id)

        base       = 'https://api.hipchat.com/v2/'
        path       = ['room', room_id, 'webhook'].join('/')
        auth_query = "?auth_token=#{api_key}"
        uri        = base + path + auth_query

        headers = {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }

        info 'Getting hooks'
        begin
          http_response = HTTParty.get(uri, body: {}.to_json, headers: headers)
        rescue => ex
          fail "Couldn't get list of hooks. Consider refreshing token.", exception: ex
        end

        if http_response.body
          response = JSON.parse(http_response.body)
          if response['items']
            hooks = response['items'].select { |h| h['url'] == hook_url }

            hooks.each do |hook|
              begin
                base       = 'https://api.hipchat.com/v2/'
                path       = ['room', room_id, 'webhook', hook['id']].join('/')
                auth_query = "?auth_token=#{api_key}"
                delete_uri = base + path + auth_query

                http_response = HTTParty.delete(delete_uri, headers: headers)
              rescue => ex
                fail "Couldn't delete hook with id #{hook['id']}", exception: ex
              end
            end
          elsif response['error']
            fail "Couldn't delete web hook: #{response['error']['message']}"
          end
        else
          fail "Couldn't get list of hooks from Hipchat"
        end
      end
    end
  end

  action 'send' do |data|
    room_id = data['room_id'] || data['room']
    color   = data['color'] || 'gray'
    format  = data['format'] || 'text'
    api_key = data['api_key']
    message = data['message']

    fail 'API Key is required' unless api_key
    fail 'Message is required' unless message
    fail 'Room ID is required' unless room_id

    base       = 'https://api.hipchat.com/v2/'
    path       = ['room', room_id, 'notification'].join('/')
    auth_query = "?auth_token=#{api_key}"
    uri        = base + path + auth_query

    body = {
      message: message,
      message_format: format,
      color: color,
      format: 'json'
    }

    headers = {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }

    info "Posting message to `#{room_id}` room"
    begin
      http_response = HTTParty.post(uri, body: body.to_json, headers: headers)
    rescue
      fail "Couldn't post message"
    end

    if http_response.response.code == '204'
      action_callback status: 'sent'
    else
      action_callback status: 'failed'
    end
  end
end
