class WebHookDefinition
  attr_accessor :id, :method, :start

  def to_hash
    {
      :id=>@id,
      :method=>@method
    }
  end
end