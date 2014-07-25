class ActionDefinition
  attr_accessor :id, :name, :description, :start

  def initialize
  end

  def to_hash
    {
      :id=>@id,
      :name=>@name,
      :description=>@description
    }
  end
end