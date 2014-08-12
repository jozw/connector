# encoding: UTF-8

require 'addressable/uri'
require 'zip/zipfilesystem'
require 'rubygems/package'
require 'zlib'
require 'open-uri'
require 'fileutils'

require_relative '../errors.rb'

# Instance super class
class Instance
  attr_accessor :definition, :callback, :instance_id

  def initialize(options = {})
    @definition = options[:definition] if options[:definition]
  end

  def callback=(block)
    @callback = block if block
  end

  def respond(params)
    @callback.call(params) if @callback
  end

  def id
    @definition.id
  end

  def info(message)
    log 'info', message
  end

  def error(message)
    log 'error', message
  end

  def warn(message)
    log 'warn', message
  end

  def debug(message)
    log 'debug', message
  end

  def log(status, message)
    respond type: 'log', status: status, message: message
  end

  protected

  def exception(ex, parameters = {})
    debug "exception: #{ex.message}"
    debug 'backtrace:'
    ex.backtrace.each do |line|
      debug "  #{line}"
    end
    debug "parameters: #{parameters}"
  end

  private

  def targz_to_zip(file)
    stringio = Zip::ZipOutputStream.write_buffer do |zipio|
      Gem::Package::TarReader.new(Zlib::GzipReader.open(file.path)) do |tar|
        tar.each do |entry|
          zipio.put_next_entry entry.full_name
          zipio.write entry.read
        end
      end

    end
    stringio.rewind
    file = File.new(file.path.gsub(/.gz/, '.zip').gsub(/.tar/, ''), 'w+')
    file.write stringio.read
    file.rewind
    file
  end
end
