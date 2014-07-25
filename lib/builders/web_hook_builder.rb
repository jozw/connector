class WebHookBuilder
  def initialize(vals={},&block)
    @id=vals[:id]
    @method=vals[:method] || 'POST'
    self.instance_eval(&block) if block
  end

  def id(val)
    @id=val
  end

  def method(val)
    @method=val
  end

  def start(&code)
    @start=code
  end

  def build
    wd=WebHookDefinition.new
    wd.id=@id
    wd.method=@method
    wd.start=@start
    wd
  end
end