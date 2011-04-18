# **Scrumy Client** is a Ruby REST client wrapper for [Scrumy](http://apidoc.scrumy.com).
#
# Scrumy Client provides a simple client interface for retrieving Sprints, Stories,
# Tasks, and Scrumers, as well as some tools for generating useful information with
# those objects.

# The [source code](https://github.com/jeffremer/scrumy-client) is available on Github.

# Dependencies
# ============

# We need JSON

# JSON responses are parsed and turned into the core Scrumy objects, key value
# pairs in the JSON hashes become instance variables in the objects.
require 'json'

# Scrumy Client uses [rest-client](https://github.com/archiloque/rest-client)
# for conveniently retrieving REST resources and handling some of the HTTP at a
# higher level.
require 'rest_client'

# We use [ActiveSupport::Inflector](http://as.rubyonrails.org/classes/Inflector.html) to do
# some of the metaprogramming magic and instantiate classes and create methods dynamically.
# `Inflector` helps to pluralize, singularize, (de)modularize symbols.
require 'active_support/inflector'

module Scrumy
  class Client
    # Every client request sets the `@url` instance variable for easy debugging
    # Just call client.url to see that last requested URL.
    attr_reader :url
    
    # `Scrumy::Clients` are initialized with a project name and password.
    def initialize(project, password)
      @project, @password = project, password
    end
    
    # This is the heart of the `Scrumy::Client` object.  It provides Ghost Methods via the Ruby
    # chainsaw, `method_missing`.
    
    def method_missing(id, *args, &block)
      # Figure out what kind of resource we're trying to get.
      klass = Scrumy::Models.const_get(id.to_s.capitalize.singularize)
      # Special case for handling id=:current - this really only applies to Sprint resources
      # but if other resources specified the `current` sub-resources then it should still work.
      if klass.current_url and args.first==:current
        @url = format(klass.current_url, :current)
      else
        # Otherwise figure out if we're requesting a pluralize or singular resource
        # A singular that is singularized will be the same as if it wasn't singularized
        # so that's our tenuous singularity check - this could be more robust.
        #
        # The only argument that resources ever take is an ID, so pass the first arg as the ID.
        @url = format(id.singularize == id ? klass.show_url : klass.list_url, args.first)
      end

      # Here we request the resource using the singular of the resource name as the root
      # to extract from the returned JSON hash.
      response = get(@url, id.to_s.singularize)
      
      # Responses are of two types, either arrays of hashes or a single hash
      if response.kind_of? Array
        # If it's array collect a new array by constructing objects based on the resource
        # name capitalized and singularized.
        response.collect do |obj|          
          klass.new(obj, self)
        end
      else
        # Otherwise create a single new object of the correct type.
        klass.new(response, self)
      end
    end

    # TODO This grammar should be better
    # Currently subresources specify special sybmols in their name,
    # either :project to get @project off the client, or :id to get
    # the argument passed to the client.
    def format(url, id=nil)
      url = url.gsub(':project', @project)
      url = url.gsub(':id', id.to_s) if id
      url
    end

    # Early implementation to get snapshots, no model for this yet - 
    # it just returns a `Hash` from the `JSON Array`.
    # def snapshots(id=:current)
    #   sprint_id = sprint(id.to_s)['id']
    #   @url = "https://scrumy.com/api/sprints/#{sprint_id}/snapshots.json"
    #   get(@url, nil)
    # end 
    
    protected
      
      # `#get` provides the nuts and bolts for retrieving resources.  Give it a
      # resource URL and a root key and it will return either an array of hashes
      # at that root key or a single hash with values found at that key.
      # 
      # For example if the resource returns `{"foo"=>{"id"=>1, "bar"=>"baz"}}`
      # then `#get(some_url, "foo")` will return the value of `"foo"` from the hash:
      # `{"id"=>1, "bar"=>"baz"}`.  This is important because later on in the models
      # we assign all the values in the latter hash as instance variables on the
      # model objects.
      def get(url, root)
        begin
          # Start by creating a new `RestCLient::Resource` authenticated with
          # the `@project` name and `@password`.
          resource = RestClient::Resource.new(url, @project, @password)
          
          # `GET` the resource
          resource.get {|response, request, result, &block|
            case response.code
            when 200
              # and on success parse the response
              json = JSON.parse(response.body)
              # If it's `Array` then collect the hashes and flatten them on the `root` key.
              if json.kind_of?(Array) && root
                json.collect{|item| 
                  item[root]
                }
              else
                # Otherwise just return the `Hash` at the root or the JSON itself directly.
                root ? json[root] : json
              end
            else
              response.return!(request, result, &block)
            end
          }
        rescue => e
          # Rescue and reraise with the current `@url` for debugging purposes          
          raise "Problem fetching #{@url} because #{e.message}"
        end
      end
  
  end
  
  # This is the abstract `Scrumy::Model` class that all resource models inherit from.  
  module Models
    class Model
      attr_reader :id

      # When passed a hash the constructor will initialize the object with instance variables
      # named after the keys in the hash.
      def initialize(args, client)
        @client = client
        args.each do |k,v|
          instance_variable_set("@#{k}", v) unless v.nil?
        end
      end

      # This method missing provides a Ghost Method proxy to access or mutate any instance variable.
      def method_missing(id, *args, &block)
        if id.to_s =~ /=$/
          id = id.to_s.gsub(/=$/,'')        
          instance_variable_set("@#{id}", args.first)
        else
          instance_variable_get("@#{id}")
        end
      end
    
      # Adapter methods for the resource DSL, this provides the
      # show, list, and current sub-resource defition methods.
      class << self
        # For each :show, :list, :current
        [:show, :list, :current].each{|method|
          # Create a method that sets a class instance variable to the URL argument
          send :define_method, method do |url|
            instance_variable_set "@#{method.to_s}_url", url
          end
          # And create an accessor for that URL.
          send :define_method, "#{method.to_s}_url".to_sym do
            instance_variable_get "@#{method.to_s}_url"
          end
        }
      end
        
      # Only current Sprints are complete, so other models need to know how ot lazily load their
      # children.
    
      # Specifying a lazy_load key in a subclass defines a new instance method on that class
      # that uses the client to fetch the right resource and set the appropriate instance variable
      # correctly.
      def self.lazy_load(method)
        define_method(method) {
          client = instance_variable_get("@client")
          ivar = instance_variable_get("@#{method}")
          clss = Models.send :const_get, method.to_s.singularize.classify
          root = method.to_s.singularize
        
          # First check if the instance variable is already set, but perhaps incorrectly as a Hash
          # If so, then instantiate the instance variable as the correct type.
          if ivar.kind_of? Array
            ivar.collect!{|single| clss.new(single[root], client)} if ivar and ivar.first.kind_of?Hash
          elsif ivar 
            ivar = clss.new(ivar, client)
          end
        
          # Return if already set, sort of minimal caching.
          return ivar if ivar

          # Last resort, fetch from the rest client.
          ivar = client.send(method, instance_variable_get("@id"))
        }
      end
    
      def self.helper(name, &block)
        self.send :define_method, name do
          instance_eval(&block)
        end
      end
    end
  end
end
 
# This is entry point for the DSL that specifies resources
def resource(name, &block)
  # It creates a new class based on the resource name scoped tot he Scrumy module
  klass = Scrumy::Models.const_set(name.to_s.classify, Class.new(Scrumy::Models::Model))
  # Then executes the block on the class.  The class provides several class
  # methods for making instances behave correctly.
  klass.class_exec &block
end

# Loads in the default resources, see `resources.rb`
load('resources.rb')