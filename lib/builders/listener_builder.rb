class ListenerBuilder

  def initialize(id,&block)
    @id=id
    self.instance_eval(&block) if block
  end

  def start(&code)
    @start=code
  end

  def stop(&code)
    @stop=code
  end

  def build
    ld = ListenerDefinition.new
    ld.id=@id
    ld.name=@name
    ld.description=@description
    ld.start=@start
    ld.stop=@stop
    ld
  end
end