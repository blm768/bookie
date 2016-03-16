require 'active_record'
require 'json'
require 'logger'
require 'set'

module Bookie
  #Forward-declared for convenience
end

##
#May be included in a class to make it support a configuration DSL
#
#Loosely based on https://corcoran.io/2013/09/04/simple-pattern-ruby-dsl/
module Bookie::ConfigClass
  #TODO: accumulate validation errors and display them all at once?
  def validate!
    self.class.validators.each do |validator|
      self.instance_eval(&validator)
    end
  end

  def self.included(other_module)
    other_module.extend(ClassMethods)
  end

  module ClassMethods
    attr_reader :validators
    attr_writer :builder_class

    ##
    #Returns the builder class
    #
    #If a block is given, it is evaluated within the context of the builder class.
    def builder_class(&block)
      @builder_class.instance_eval(&block) if block_given?
      @builder_class
    end

    def self.extended(other_module)
      other_module.builder_class = Class.new do
        define_method(:initialize) do
          @config = other_module.new
        end

        attr_reader :config

        def self.property_writer(name)
          writer_name = "#{name}=".intern
          define_method(name) do |value|
            @config.send(writer_name, value)
          end
        end
      end
    end

    def build(&block)
      builder = builder_class.new
      builder.instance_eval(&block)
      builder.config
    end

    def build_from_string(text, filename = '')
      builder = builder_class.new
      builder.instance_eval(text, filename)
      builder.config
    end

    def load(file)
      build_from_string(file.read, file.path)
    end

    def validate_self(&block)
      @validators ||= []
      @validators.push(block)
    end

    ##
    #Creates a configuration property
    #
    #Options:
    # - type: the property's type
    # - allow_nil: allow nil values (default is <tt>false</tt> if type is specified, <tt>true</tt> otherwise)
    # - create_proxy: create a proxy setter method in the builder class (default is <tt>true</tt>)
    def property(name, options = nil)
      options ||= {}
      writer_name = "#{name}=".intern
      var_name = "@#{name}".intern

      attr_accessor(name)

      type = options[:type]
      allow_nil = options[:allow_nil]
      if type then
        allow_nil = false if allow_nil.nil?
        validate_self do
          value_class = self.send(name).class
          next if allow_nil && value_class <= NilClass
          raise TypeError.new("Invalid type #{value_class} for field '#{name}': #{type} expected") unless value_class <= type
        end
      else
        allow_nil = true if allow_nil.nil?
        if not allow_nil then
          validate_self do
            raise TypeError.new("Field '#{name}' must not be nil") if self.send(name).nil?
          end
        end
      end

      create_proxy = options[:create_proxy]
      create_proxy = true if create_proxy.nil?
      builder_class.property_writer(name) if create_proxy
    end
  end
end
