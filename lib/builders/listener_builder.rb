# encoding: UTF-8

# DSL for building listeners
class ListenerBuilder
  def initialize(id, &block)
    @id = id.to_s
    instance_eval(&block) if block
  end

  def start(&code)
    @start = code
  end

  def stop(&code)
    @stop = code
  end

  def build
    ld = ListenerDefinition.new
    ld.id = @id
    ld.start = @start
    ld.stop = @stop
    ld
  end
end
