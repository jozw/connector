# encoding: UTF-8

# Definition of service as defined by DSL
class ServiceDefinition
  attr_accessor :id, :listeners, :actions

  def initialize
    @listeners = {}
    @actions = {}
  end

  def to_hash
    {
      id: @id,
      listeners: @listeners.map { |k, v| v.to_hash },
      actions: @actions.map { |k, v| v.to_hash },
    }
  end
end
