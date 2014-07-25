class ActionBuilder
  def initialize(id,&block)
    @id=id
    self.instance_eval(&block) if block
  end

  def start(&code)
    @start=code
  end

  def build
    ad=ActionDefinition.new
    ad.id=@id
    ad.start=@start
    ad
  end
end