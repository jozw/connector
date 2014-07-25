# encoding: UTF-8

# DSL for creating web hooks
class WebHookBuilder
  def initialize(vals = {}, &block)
    @id = vals[:id].to_s
    @method = vals[:method] || 'POST'
    instance_eval(&block) if block
  end

  def id(val)
    @id = val.to_s
  end

  def method(val)
    @method = val
  end

  def start(&code)
    @start = code
  end

  def build
    wd = WebHookDefinition.new
    wd.id = @id
    wd.method = @method
    wd.start = @start
    wd
  end
end
