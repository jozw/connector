class ServiceDefinition
  attr_accessor :id,:name,:version,:description, :listeners, :actions

  def initialize
    @listeners={}
    @actions={}
  end

  def to_hash
    {
      :id=>@id,
      :name=>@name,
      :version=>@version,
      :description=>@description,
      :listeners=>@listeners.map {|k,v| v.to_hash},
      :actions=>@actions.map{|k,v|v.to_hash},
    }
  end
end