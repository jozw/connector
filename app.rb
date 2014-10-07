# encoding: UTF-8

require 'json'
require 'multi_json'
require 'sinatra'
require 'sinatra/namespace'
require 'sinatra-websocket'
require 'sinatra/json'
require 'factor-connector-api'

require_relative './init.rb'

register Sinatra::Namespace

configure do
  enable :logging
  enable :raise_errors
  set :service_instances, {}
  set :sockets, []
end

helpers do
  def inputs
    body_payload = begin
      MultiJson.load(request.body.read)
    rescue
      {}
    end

    param_payload = begin
      param['payload'] ? MultiJson.load(params['payload']) : {}
    rescue
      {}
    end

    %w(splat captures payload).each do |param|
      params.delete param
      params.delete param.to_sym
    end

    {}.merge(param_payload).merge(body_payload).merge(params)
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
    service_instances = settings.service_instances.values
    select_service_instances = service_instances.select do |service_instance|
      listener_instances = service_instance.listener_instances
      listener_instances.each do |_listener_id, listener_instance|
        listener_instance.web_hooks.keys.include?(hook_id)
      end
    end
    select_service_instances
  end

  def get_service_manager(service_id)
    service_manager = Factor::Connector.get_service_manager(service_id)
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
  post '/hooks/:hook_id' do
    hook_id           = inputs['hook_id']
    service_instances = get_service_instances_by_hook_id(hook_id)

    status = []
    service_instances.each do |service_instance|
      service_instance_id = service_instance.instance_id
      listener_instances = service_instance.listener_instances
      listener_instances.each do |listener_id, listener_instance|
        next unless listener_instance.web_hooks.keys.include?(hook_id)
        begin
          service_instance.call_hook(
            listener_id,
            hook_id,
            inputs,
            request,
            response)
          status_message = 'succeeded'
        rescue
          status_message = 'failed'
        end
        message <<-EOM
        Call to service instance #{service_instance_id} #{status_message}
        EOM
        status << { message: message }
      end
    end
    status.to_json
  end

  namespace '/:service_id' do
    namespace '/listeners' do
      post '/:listener_id/instances/:instance_id/hooks/:hook_id' do
        listener_id      = inputs['listener_id']
        instance_id      = inputs['instance_id']
        hook_id          = inputs['hook_id']
        service_instance = get_service_instance(instance_id)
        begin
          service_instance.call_hook(
            listener_id,
            hook_id,
            inputs,
            request,
            response)
        rescue
          not_found
        end
        { message: 'Call to hook completed' }.to_json
      end

      get '/:listener_id' do
        listener_id = inputs['listener_id']
        service_id  = inputs['service_id']

        if request.websocket?
          request.websocket do |ws|
            settings.sockets << ws
            service_manager     = get_service_manager(service_id)
            service_instance    = service_manager.instance
            service_instance_id = service_instance.instance_id
            settings.service_instances[service_instance_id] = service_instance

            trap 'TERM' do
              ws.close_connection
            end

            not_found unless service_instance.has_listener?(listener_id)

            listener_inputs = {}

            ws.onmessage do |msg|
              logger.info "MESSAGE #{request.path_info}"
              listener_inputs = MultiJson.load(msg)

              service_instance.callback = proc do |listener_response|
                message = listener_response[:message]

                case listener_response[:type]
                when 'log'
                  case listener_response[:status]
                  when 'info' then logger.info message
                  when 'warn' then logger.warn message
                  when 'error' then logger.error message
                  when 'debug' then logger.error message
                  end
                when 'fail'
                  logger.error message if message
                end
                ws.send(MultiJson.dump(listener_response))
              end

              service_instance.start_listener(listener_id, listener_inputs)
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
        action_id = inputs['action_id']
        service_id = inputs['service_id']

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
              action_inputs = MultiJson.load(msg)
              service_instance.callback = proc do |action_response|
                message = action_response[:message]
                case action_response[:type]
                when 'log'
                  case action_response[:status]
                  when 'info' then logger.info message
                  when 'warn' then logger.warn message
                  when 'error' then logger.error message
                  when 'debug' then logger.error message
                  end
                when 'fail'
                  logger.error message if message
                when 'return'
                  logger.info "RESPOND #{action_response[:payload]}"
                end
                ws.send(MultiJson.dump(action_response))
              end
              service_instance.call_action(action_id, action_inputs)
            end
          end
        else
          halt 400, json(message: 'No a websocket handshake')
        end
      end
    end
  end
end
