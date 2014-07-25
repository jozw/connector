require 'sinatra'
require './lib/service_app.rb'

app=ServiceApp.new

Dir.glob("./lib/channels/*.rb") do |path|
  app.load path
end

run app.sinatra_app