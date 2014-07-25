class ListenerDefinition
  attr_accessor :id, :name, :description, :start, :stop, :web_hooks

  def initialize
    @web_hooks={}
  end

  def to_hash
    {
      :id=>@id,
      :name=>@name,
      :description=>@description
    }
  end
end