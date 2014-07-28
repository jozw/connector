# encoding: UTF-8

# DSL for building actions
class ActionBuilder
  def initialize(id, &block)
    @id = id.to_s
    @start = block
  end

  def build
    ad = ActionDefinition.new
    ad.id = @id
    ad.start = @start
    ad
  end
end
