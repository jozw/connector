require 'httparty'

service 'hipchat' do

  listeners = %w(message notification exit enter topic_change).map{|r| "room_#{r}"}

  listeners.each do |listener_name|
    listener listener_name do
      start do |push_listener_params|
        room_id=push_listener_params['room_id']
        room_id||=push_listener_params['room']

        hook_url = get_web_hook(listener_options[:id])
        uri="https://api.hipchat.com/v2/room/#{room_id}/webhook?auth_token=#{push_listener_params['api_key']}"
        body={
          :url=>hook_url,
          :pattern=>push_listener_params['filter'],
          :event=>listener_name,
          :name=>'workflow'
        }
        headers={
          'Content-Type'=>'application/json',
          'Accept'=>'application/json'
        }

        info 'Getting hooks'
        begin
          http_response=HTTParty.get(uri,body:{}.to_json,:headers=>headers)
        rescue
          fail "Couldn't get list of hooks. Considering refreshing token.", {state:'stopped'}
        end

        if http_response.body
          response = JSON.parse(http_response.body)
          if response['items']
            hooks=response['items'].select{|hook| hook['url']==hook_url}
          elsif response['error']
            fail "Couldn't create web hook: #{response['error']['message']}", {state:'stopped'}
          end
        end

        if hooks && hooks.count>0
          info 'Looks like this bad boy is already running'
          hook_id=hooks.first['id']
        else
          info "Creating hook in `#{room_id}` room"
          begin
            http_response=HTTParty.post(uri,body:body.to_json,:headers=>headers)
          rescue
            fail '', {state:'stopped'}
          end

          if http_response.body
            response = JSON.parse(http_response.body)
            if response['error']
              fail "Couldn't create web hook: #{response['error']['message']}", {state:'stopped'}
            elsif response['id']
              hook_id=response['id']
            end
          end
        end

        hook_url = web_hook id:listener_name do
          start do |listener_start_params,data,req,res|
            info 'Triggering workflow...'
            begin
              filter = push_listener_params['filter']
              original_message=data['item']['message']['message']
              regexp=Regexp.new(filter)
              matches=regexp.match(original_message).captures
              data['matches']=matches
              data['message']=original_message
            rescue => ex
              fail "Couldn't parse message from Hipchat", exception:ex
            end

            begin
              start_workflow data
            rescue => ex
              fail 'Internal error: failed to send message for next step', exception:ex
            end
          end
        end
      end

      stop do |push_listener_params|
        room_id=push_listener_params['room_id']
        room_id||=push_listener_params['room']

        info "Deleting hook #{listener_options[:id]}"
        hook_url = get_web_hook(listener_options[:id])

        uri="https://api.hipchat.com/v2/room/#{room_id}/webhook?auth_token=#{push_listener_params['api_key']}"

        headers={
          'Content-Type'=>'application/json',
          'Accept'=>'application/json'
        }

        info 'Getting hooks'
        begin
          http_response=HTTParty.get(uri,body:{}.to_json,:headers=>headers)
        rescue => ex
          fail "Couldn't get list of hooks. Consider refreshing token.", exception: ex
        end

        if http_response.body
          response = JSON.parse(http_response.body)
          if response['items']
            hooks=response['items'].select{|hook| hook['url']==hook_url}

            hooks.each do |hook|
              begin
                delete_uri="https://api.hipchat.com/v2/room/#{room_id}/webhook/#{hook['id']}?auth_token=#{push_listener_params['api_key']}"
                http_response=HTTParty.delete(delete_uri,:headers=>headers)
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

  action 'send' do
    start do |data|
      room_id=data['room_id'] || data['room']
      color = data['color'] || 'gray'
      format = data['format'] || 'text'
      uri="https://api.hipchat.com/v2/room/#{room_id}/notification?auth_token=#{data['api_key']}"
      body={
        :message=>data['message'],
        :message_format=>format,
        :color=>color,
        :format=>'json'
      }
      headers={
        'Content-Type'=>'application/json',
        'Accept'=>'application/json'
      }

      info "Posting message to `#{room_id}` room"
      begin
        http_response=HTTParty.post(uri,body:body.to_json,:headers=>headers)
      rescue
        fail "Couldn't post message"
      end

      if http_response.response.code == '204'
        action_callback status:'sent'
      else
        action_callback status:'failed'
      end


    end
  end
end
