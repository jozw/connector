# encoding: UTF-8

# DSL for building services
class ServiceBuilder
  def initialize(id, &block)
    @listeners = {}
    @actions = {}
    @id = id.to_s
    instance_eval(&block) if block
  end

  def listener(id, &block)
    listener = ListenerBuilder.new(id, &block).build
    @listeners[listener.id] = listener
  end

  def action(id, &block)
    action = ActionBuilder.new(id, &block).build
    @actions[action.id] = action
  end

  def build
    sd = ServiceDefinition.new
    sd.listeners = @listeners
    sd.actions = @actions
    sd.id = @id
    sd
  end
end
