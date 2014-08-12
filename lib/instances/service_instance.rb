require 'celluloid'

Dir.glob('./lib/definitions/*.rb') { |p| require p }
Dir.glob('./lib/builders/*.rb') { |p| require p }
Dir.glob('./lib/instances/*.rb') { |p| require p }

module Factor
  class ServiceInstance < Instance
    attr_accessor :definition, :step_data, :callback, :listener_instances

    def initialize(options={})
      @listener_instances={}
      @instance_id=SecureRandom.hex
      super(options)
    end

    def call_hook(listener_id,hook_id,data,request,response)
      listener_instance = @listener_instances[listener_id]
      listener_instance.async.call_web_hook(hook_id,data,request,response)
    end

    def call_action(action_id,params)
      action_instance = ActionInstance.new
      action_instance.service_id  = self.id
      action_instance.instance_id = @instance_id
      action_instance.definition  = @definition.actions[action_id]
      action_instance.callback    = @callback
      action_instance.async.start(params)
    end

    def start_listener(listener_id,params)
      listener_instance = ListenerInstance.new
      listener_instance.service_id  = self.id
      listener_instance.instance_id = @instance_id
      listener_instance.definition  = @definition.listeners[listener_id]
      listener_instance.callback    = @callback
      @listener_instances[listener_id]=listener_instance
      listener_instance.async.start(params)
    end

    def stop_listener(listener_id)
      if !@listener_instances[listener_id]
        warn "Listener isn't running, no need to stop"
        respond type:'stopped'
      else
        @listener_instances[listener_id].async.stop 
        @listener_instances.delete listener_id
      end
    end

    def has_action?(action_id)
      @definition.actions.include?(action_id)
    end

    def has_listener?(listener_id)
      @definition.listeners.include?(listener_id)
    end
  end
end