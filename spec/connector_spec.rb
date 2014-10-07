# encoding: UTF-8

require 'spec_helper'
require 'faye/websocket'
require 'json'
require "socket"
require 'rspec/em'
require 'wrong'

describe 'Connector' do
  # include WebSocketSteps

  def app
    Sinatra::Application
  end

  before do
    Factor::Connector.service 'basic' do
      action 'test' do |params|
        puts "PARTY"
        info "this is info"
        warn "this is a warning"
        error "this is an error"
        info "echo: #{params['echo']}"
        action_callback {a_variable:'has contents'}
      end
      action 'fail-test-method' do |params|
        fail "this is a fail"
      end
    end
    start_server
  end

  after do
    stop_server
  end

  it "can open a connection" do
    url = "ws://0.0.0.0:4180/v0.4/basic/actions/test"
    puts "URL: #{url}"
    settings = { ping: 10, retry: 5 }
    @logs = []
    EM.run do
      @ws = Faye::WebSocket::Client.new(url, nil, settings)
      @ws.on :message do |message|
        puts "message: #{JSON.parse(message.data)}"
        @logs << JSON.parse(message.data)
      end
    end

    @ws.send({echo:'foo'}.to_json)

    Wrong::eventually do
      @logs.any? do |log|
        log[:status] == 'info' && log[:message]=='this is info'
      end
    end

    @ws.close
  end


  def start_server
    ::Thin::Logging.silent = true
    @server = Thin::Server.new('0.0.0.0',4180,{},app.new)
    @thread = Thread.new {@server.start}
    sleep 1 until @server.running?
  end

  def stop_server
    @server.stop
    sleep 0.1
    @thread.kill
    sleep 0.1
    raise "Reactor still running, wtf?" if EventMachine.reactor_running?
  end
end
