# encoding: UTF-8

require 'spec_helper'
require 'faye/websocket'
require 'json'
require "socket"
require 'wrong'

describe 'Connector' do
  # include WebSocketSteps

  def app
    Sinatra::Application
  end

  before do
    Factor::Connector.service 'basic' do
      action 'test' do |params|
        info "this is info"
        warn "this is a warning"
        error "this is an error"
        info "echo: #{params['echo']}"
        action_callback some_var:'has contents'
      end
      action 'fail-test-method' do |params|
        fail "this is a fail"
      end
      listener 'listen-test' do
        start do |params|
          info "this is info"
          warn "this is a warning"
          error "this is an error"
          info "echo: #{params['echo']}"
          start_workflow some_var:'has contents'
        end
        stop do |params|

        end
      end
    end
    start_server
  end

  after do
    stop_server
  end

  describe "Action" do
    before do 
      url = "ws://0.0.0.0:4180/v0.4/basic/actions/test"
      settings = { ping: 10, retry: 5 }
      @logs = []
      EM.run do
        @ws = Faye::WebSocket::Client.new(url, nil, settings)
        @ws.on :message do |message|
          @logs << JSON.parse(message.data)
        end
      end
      @ws.send({echo:'foo'}.to_json)
    end

    after do
      @ws.close
    end

    it "can send info" do
      check_eventually @logs do |log|
        log['status'] == 'info' && log['message']=='this is info'
      end
    end

    it "can send a warning" do
      check_eventually @logs do |log|
        log['status'] == 'warn' && log['message']=='this is a warning'
      end
    end

    it "can send an error" do
      check_eventually @logs do |log|
        log['status'] == 'error' && log['message']=='this is an error'
      end
    end

    it "can receive information from a parameter" do
      check_eventually @logs do |log|
        log['status'] == 'info' && log['message']=="echo: foo"
      end
    end

    it "can send payloads in a response" do 
      check_eventually @logs do |log|
        log['type'] == 'return' && log['payload']== {"some_var"=>"has contents"}
      end
    end
  end

  describe "Listener" do
    before do
      url = "ws://0.0.0.0:4180/v0.4/basic/listeners/listen-test"
      settings = { ping: 10, retry: 5 }
      @logs = []
      EM.run do
        @ws = Faye::WebSocket::Client.new(url, nil, settings)
        @ws.on :message do |message|
          @logs << JSON.parse(message.data)
        end
      end
      @ws.send({echo:'foo'}.to_json)
    end

    after do
      @ws.close
    end

    it "can send info" do
      check_eventually @logs do |log|
        log['status'] == 'info' && log['message']=='this is info'
      end
    end

    it "can send a warning" do
      check_eventually @logs do |log|
        log['status'] == 'warn' && log['message']=='this is a warning'
      end
    end

    it "can send an error" do
      check_eventually @logs do |log|
        log['status'] == 'error' && log['message']=='this is an error'
      end
    end

    it "can receive information from a parameter" do
      check_eventually @logs do |log|
        log['status'] == 'info' && log['message']=="echo: foo"
      end
    end

    it "can start workflows with parameters" do 
      check_eventually @logs do |log|
        log['type'] == 'start_workflow' && log['payload']== {"some_var"=>"has contents"}
      end
    end

  end


  def check_eventually(logs, &block)
    Wrong::eventually do
      logs.any? do |log|
        block.call(log)
      end
    end
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
