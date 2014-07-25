# encoding: UTF-8

# DSL for building actions
class ActionBuilder
  def initialize(id, &block)
    @id = id.to_s
    # instance_eval(&block) if block
    @start = block
  end

  # def start(&code)
  #   @start = code
  # end

  def build
    ad = ActionDefinition.new
    ad.id = @id
    ad.start = @start
    ad
  end
end
