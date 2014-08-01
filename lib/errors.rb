# encoding: UTF-8

# Erro thrown when fail is used
class FactorConnectorError < StandardError
  attr_accessor :state, :exception

  def initialize(params = {})
    @exception = params[:exception]
    super(params[:message] || '')
  end
end
