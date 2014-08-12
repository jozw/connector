# encoding: UTF-8

require 'json'
require 'multi_json'
require 'sinatra/base'
require 'sinatra/namespace'
require 'sinatra-websocket'
require 'sinatra/json'
require 'restclient'
require 'uri'
require 'awesome_print'

require_relative 'errors.rb'
require_relative 'service_manager.rb'

%w(helpers definitions builders).each do |dir|
  Dir.glob("./lib/#{dir}/*.rb") do |path|
    require path
  end
end

# The main function for the Sinatra app
class ServiceApp
  attr_accessor :sinatra_app

  def load(filename)
    service_manager = Factor::ServiceManager.new
    service_manager.load(filename)
    service_id = service_manager.definition.id
    @sinatra_app.settings.service_managers[service_id] = service_manager
  end

  def initialize
    @sinatra_app = Sinatra.new do
      register Sinatra::Namespace

      configure :production do
        set :port, ENV['LISTENER_PROD_PORT']
      end

      configure :development do
        set :port, ENV['LISTENER_DEV_PORT']
      end

      configure do
        enable :logging
        enable :raise_errors
        set :service_managers, {}
        set :service_instances, {}
        set :sockets, []
      end

      helpers do
        def get_params
          body = {}
          body_payload = begin
            MultiJson.load(request.body.read)
          rescue
            {}
          end
          body.merge!(body_payload)

          if params['payload']
            body.merge!(MultiJson.load(params['payload']))
            params.delete('payload')
          end

          params.delete(:splat)
          params.delete('splat')
          params.delete(:captures)
          params.delete('captures')
          body.merge!(params)
          body
        end

        def not_found
          halt 404, json(message: 'No record found')
        end

        def get_service_instance(instance_id)
          service_instance = settings.service_instances[instance_id]
          not_found unless service_instance
          service_instance
        end

        def get_service_instances_by_hook_id(hook_id)
          service_instances = settings.service_instances.values.select do |service_instance|
            service_instance.listener_instances.each do |listener_id,listener_instance|
              listener_instance.web_hooks.keys.include?(hook_id)
            end
          end
          service_instances
        end

        def get_service_manager(service_id)
          service_manager = settings.service_managers[service_id]
          not_found unless service_manager
          service_manager
        end

        def get_service_definition(service_id)
          get_service_manager(service_id).definition
        end
      end

      get '/' do
        'Hello world'
      end

      get '/health' do
        'healthy'
      end

      namespace '/v0.4' do
        namespace '/:service_id' do
          namespace '/listeners' do
            post '/:listener_id/instances/:instance_id/hooks/:hook_id' do
              data             = get_params
              listener_id      = data['listener_id']
              instance_id      = data['instance_id']
              hook_id          = data['hook_id']
              service_instance = get_service_instance(instance_id)
              begin
                service_instance.call_hook(listener_id, hook_id, data, request, response)
              rescue
                not_found
              end
              {message: 'Call to hook completed'}.to_json
            end

            get '/:listener_id' do
              data = get_params
              listener_id = data['listener_id']
              service_id = data['service_id']

              if request.websocket?
                request.websocket do |ws|
                  settings.sockets << ws
                  service_manager = get_service_manager(service_id)
                  service_instance = service_manager.instance
                  settings.service_instances[service_instance.instance_id] = service_instance

                  trap "TERM" do
                    ws.close_connection
                  end

                  not_found unless service_instance.has_listener?(listener_id)

                  listener_data = {}

                  ws.onmessage do |msg|
                    logger.info "MESSAGE #{request.path_info}"
                    listener_data = MultiJson.load(msg)

                    service_instance.callback = proc do |listener_response|
                      if listener_response[:type] == 'log'
                        message = listener_response[:message]
                        case listener_response[:status]
                        when 'info' then logger.info message
                        when 'warn' then logger.warn message
                        when 'error' then logger.error message
                        when 'debug' then logger.error message
                        end
                      end
                      if listener_response[:type] == 'fail' && listener_response[:message]
                        logger.error listener_response[:message]
                      end
                      ws.send(MultiJson.dump(listener_response))
                    end

                    service_instance.start_listener(listener_id, listener_data)
                  end

                  ws.onopen do
                    logger.info "OPEN #{request.path_info}"
                  end

                  ws.onclose do
                    logger.info "CLOSE #{request.path_info}"
                    service_instance.stop_listener(listener_id)
                    settings.sockets.delete ws
                  end

                  ws.onerror do |error|
                    logger.error "ERROR #{error.class}"
                    logger.error error
                  end

                end
              else
                halt 400, json(message: 'No a websocket handshake')
              end
            end
          end

          namespace '/actions' do
            get '/:action_id' do
              data = get_params
              action_id = data['action_id']
              service_id = data['service_id']

              if request.websocket?
                request.websocket do |ws|
                  service_manager  = get_service_manager(service_id)
                  service_instance = service_manager.instance

                  not_found unless service_instance.has_action?(action_id)

                  ws.onopen do
                    logger.info "OPEN #{request.path_info}"
                  end
                  ws.onclose do
                    logger.info "CLOSE #{request.path_info}"
                    service_instance.stop_action(action_id)
                  end

                  ws.onerror do |error|
                    logger.error "ERROR #{error.class}"
                    logger.error error
                    # service_instance.stop_action(action_id)
                  end

                  ws.onmessage do |msg|
                    logger.info "MESSAGE #{request.path_info}"
                    action_data = MultiJson.load(msg)
                    service_instance.callback = proc do |action_response|
                      if action_response[:type] == 'log'
                        message = action_response[:message]
                        case action_response[:status]
                        when 'info' then logger.info message
                        when 'warn' then logger.warn message
                        when 'error' then logger.error message
                        when 'debug' then logger.error message
                        end
                      end
                      logger.error action_response[:message] if action_response[:type] == 'fail' && action_response[:message]
                      logger.info "RESPOND #{action_response[:payload]}" if action_response[:type] == 'return'
                      ws.send(MultiJson.dump(action_response))
                    end
                    service_instance.call_action(action_id, action_data)
                  end
                end
              else
                halt 400, json(message: 'No a websocket handshake')
              end
            end
          end
        end
      end
    end
  end
end
