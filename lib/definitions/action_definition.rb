# encoding: UTF-8

# action definition as defined by DSL
class ActionDefinition
  attr_accessor :id, :start

  def initialize
  end

  def to_hash
    {
      id: @id
    }
  end
end
