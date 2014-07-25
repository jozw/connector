require 'restclient'

service 'pushover' do

  action 'notify' do
    start do |params|
      
      contents = {message: params['message'], title: params['title'], user: params['username'], token: params['api_key']}
      info 'Sending message'
      begin
        response = JSON.parse(RestClient.post('https://api.pushover.net/1/messages.json',contents))
      rescue
        fail 'Failed to send message'
      end
      action_callback response
    end
  end
end

