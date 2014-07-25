
Dir.glob('./lib/definitions/*.rb') { |p| require p }
Dir.glob('./lib/builders/*.rb') { |p| require p }
require_relative './instances/service_instance.rb'

module Factor
  
  class ServiceManager
    attr_accessor :definition

    def service(vals={},&block)
      @definition = ServiceBuilder.new(vals,&block).build
    end

    def instance
      instance = ServiceInstance.new(definition:@definition)
      instance
    end

    def load(filename)
      self.instance_eval(File.read(filename))
    end

  end
end