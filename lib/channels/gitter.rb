require 'httparty'
require 'eventmachine'
require 'em-http'
require 'oauth2'

service 'gitter' do

  listener 'room_message' do
    start do |chat_listener_params|
      room_name   = chat_listener_params['room']
      api_key     = chat_listener_params['api_key']
      filter      = chat_listener_params['filter']

      fail 'You need to specify a room with the room field' if !room_name
      fail 'Please setup the credentials for Gitter first' if !api_key

      headers = {
        'Content-Type'=>'application/json',
        'Accept'=>'application/json',
        'Authorization'=>"Bearer #{api_key}"
      }

      info 'Getting rooms'
      rooms_uri   = 'https://api.gitter.im/v1/rooms/'
      rooms       = HTTParty.get(rooms_uri,:headers=>headers)

      if rooms.response.code == '401'
        fail 'API key invalid'
      elsif rooms.response.code != '200'
        fail 'HTTP request failed for some reason. Check for typos and try again.'
      end

      begin
        data    = { 'room' => rooms.select{ |r| r['name'] == room_name}.first }
        room_id = data['room']['id']
        data['room']['url'] = "https://gitter.im/#{data['room']['uri']}"
      rescue
        fail 'Problem finding room. Check your API Key and/or room name for errors'
      end

      begin
        stream_url  = "https://stream.gitter.im/v1/rooms/#{room_id}/chatMessages"
        @http  = EM::HttpRequest.new(stream_url, keepalive: true, connect_timeout: 0, inactivity_timeout: 0)
        req   = @http.get(head:headers)
      rescue
        fail 'HTTP request failed'
      end

      req.stream do |chunk|
        unless chunk.strip.empty?
          message = JSON.parse(chunk)
          data['message'] = message

          data['message']['from'] = {
            'id'      => data['message']['fromUser']['id'],
            'name'    => data['message']['fromUser']['displayName'],
            'username'=> data['message']['fromUser']['username']
          } # Converts from lower camel to lower snake case

          if filter
            regexp  = Regexp.new(filter)
            matches =regexp.match(message['text'])
            if matches
              data['matches'] = matches.captures
              info 'Triggering workflow...'
              begin
                start_workflow data
              rescue => ex
                fail 'Internal error: failed to send message for next step', exception:ex
              end
            end
          end
        end
      end
    end

    stop do
      info 'Closing connection'
      begin
        @http.close
      rescue
        fail 'Failed to close connection'
      end
    end
  end

  action 'send' do
    start do |data|
      begin
        room_name   = data['room']
        api_key     = data['api_key']
      rescue
        fail "One of the required parameters (api_key, room, text) isn't set"
      end

      if data['text']
        body = { :text => data['text'] }
      else
        fail 'No text received from workflow.'
      end

      headers={
        'Content-Type'=>'application/json',
        'Accept'=>'application/json',
        'Authorization'=>"Bearer #{api_key}"
      }

      info 'Getting rooms'
      rooms_uri   = 'https://api.gitter.im/v1/rooms/'
      rooms = HTTParty.get(rooms_uri,:headers=>headers)

      if rooms.response.code == '401'
        fail 'API key invalid'
      elsif rooms.response.code != '200'
        fail 'HTTP request failed for some reason. Check for typos and try again.'
      end

      begin
        room    = rooms.select{ |r| r['name'] == room_name}.first
        room_id = room['id']
      rescue
        fail 'Problem finding room. Check your API Key and/or room name for errors'
      end

      info "Posting message to `#{room_name}` room"
      message_uri = "https://api.gitter.im/v1/rooms/#{room_id}/chatMessages"
      begin
        http_response=HTTParty.post(message_uri,body:body.to_json,:headers=>headers)
      rescue
        fail "Couldn't post message"
      end

      if http_response.response.code == '200'
        action_callback status:'sent'
      else
        action_callback status:'failed'
      end

    end
  end
end
