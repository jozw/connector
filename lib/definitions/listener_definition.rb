# encoding: UTF-8

# Listener definition as defined by DSL
class ListenerDefinition
  attr_accessor :id, :start, :stop, :web_hooks

  def initialize
    @web_hooks = {}
  end

  def to_hash
    {
      id: @id
    }
  end
end
