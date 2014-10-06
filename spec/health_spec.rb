# encoding: UTF-8

require 'spec_helper'

describe 'Health' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  it "says 'healthy'" do
    get '/health'
    expect(last_response).to be_ok
    expect(last_response.body).to eq('healthy')
  end

  it "says 'hello world'" do
    get '/'
    expect(last_response).to be_ok
    expect(last_response.body).to eq('Hello world')
  end
end
