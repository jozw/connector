# encoding: UTF-8

require 'codeclimate-test-reporter'
require 'rspec'
require 'rack/test'

CodeClimate::TestReporter.start

require './app'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end
