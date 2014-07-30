# encoding: UTF-8

require 'httparty'

service 'hipchat' do

  def hipchat_uri(params = {})
    base = 'https://api.hipchat.com/v2/'
    base += "room/#{params[:room]}" if params[:room]
    base += "webhook/#{params[:webhook]}" if params[:webhook]
    base += "/#{params[:path]}" if params[:path]
    base += "?auth_token=#{params[:token]}" if params[:token]
    base
  end

  listeners = %w(message notification exit enter topic_change).map do |n|
    "room_#{n}"
  end
  listeners.each do |listener_name|
    listener listener_name do
      start do |push_listener_params|
        room_id = push_listener_params['room_id']
        room_id ||= push_listener_params['room']

        hook_url = get_web_hook(listener_options[:id])
        webhook_uri_options = {
          room: room_id,
          path: 'webhook',
          token: push_listener_params['api_key']
        }
        uri = hipchat_uri webhook_uri_options

        headers = {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }

        info 'Getting hooks'
        begin
          http_response = HTTParty.get(uri, body: {}.to_json, headers: headers)
        rescue
          fail "Couldn't get list of hooks. Considering refreshing token."
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
          info 'Looks like this bad boy is already running'
          hook_id = hook['id']
        else
          info "Creating hook in `#{room_id}` room"
          begin
            body = {
              url: hook_url,
              pattern: push_listener_params['filter'],
              event: listener_name,
              name: 'workflow'
            }
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

        hook_url = web_hook id: listener_name do
          start do |_listener_start_params, hook_data, _req, _res|
            info 'Triggering workflow...'
            begin
              filter = push_listener_params['filter']
              original_message = hook_data['item']['message']['message']
              regexp           = Regexp.new(filter)
              matches          = regexp.match(original_message).captures
              hook_data['matches']  = matches
              hook_data['message']  = original_message
              hook_data['hook_id']  = hook_id
            rescue => ex
              fail "Couldn't parse message from Hipchat", exception: ex
            end

            begin
              start_workflow data
            rescue => ex
              fail 'Internal error: failed to send message for next step', exception: ex
            end
          end
        end
      end

      stop do |push_listener_params|
        room_id = push_listener_params['room_id']
        room_id ||= push_listener_params['room']

        info "Deleting hook #{listener_options[:id]}"
        hook_url = get_web_hook(listener_options[:id])

        webhook_uri_options = {
          room: room_id,
          path: 'webhook',
          token: push_listener_params['api_key']
        }
        uri = hipchat_uri webhook_uri_options

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
                webhook_delete_uri_options = {
                  room: room_id,
                  webhook: hook['id'],
                  token: push_listener_params['api_key']
                }
                delete_uri = hipchat_uri webhook_delete_uri_options

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
    uri_options = {
      room: room_id,
      path: 'notification',
      token: api_key
    }
    uri = hipchat_uri uri_options

    body = {
      message: data['message'],
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
