class FactorConnectorError < StandardError
  attr_accessor :state, :exception

  def initialize(params={})
    @state = params[:state] || 'stopped'
    @exception = params[:exception]
    @state='started' if params[:started]
    @state='stopped' if params[:stopped]
    super(params[:message] || '')
  end

  def started?
    @state=='started'
  end

  def stopped?
    @state=='stopped'
  end

  def started
    @state='started'
  end

  def stopped
    @state='stopped'
  end
end