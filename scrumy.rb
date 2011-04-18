# **Scrumy Client** is a Ruby REST client wrapper for [Scrumy](http://apidoc.scrumy.com).
#
# Scrumy Client provides a simple client interface for retrieving Sprints, Stories,
# Tasks, and Scrumers, as well as some tools for generating useful information with
# those objects.

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

# We use [ActiveSupport::Inflector](http://as.rubyonrails.org/classes/Inflector.html) to do some of the metaprogramming magic and
# instantiate classes and create methods dynamically.  Inflector helps to
# pluralize, singularize, (de)modularize symbols.
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
    
    # Convenience method for retreiving the current sprint, proxies to `method_missing`
    # and returns the `Scrumy::Sprint` object for the current sprint.  Current sprints
    # are complete - that is the have fully populated instance variables for stories,
    # tasks, and scrumers.
    def sprint
      method_missing(:sprint, :current)
    end
    
    
    # This is the heart of the `Scrumy::Client` object.  It provides Ghost Methods via the Ruby
    # chainsaw, `method_missing`.
    
    # The magic comes from the fact that the Scrumy REST API uses mostly deterministic URLS
    # based on relationships between models.  Scrums have Sprints, Sprints have Stories,
    # Stories have Tasks, Tasks have one Scrumer.
    def method_missing(id, *args, &block)
      # :current is a special case, ideally it shouldn't be here and we should probably remove it
      # for readability's sake, but it does illustrate that the rest of this method works even
      # though this REST resource URL can be different
      if args.first == :current
        @url = "https://scrumy.com/api/scrumies/#{@project}/sprints/#{args.first.to_s}.json"
      else
        # URLs are constructed from parent of the class corresponding the the desired
        # resource and the method as the resource itself.
        parent = Scrumy.const_get(id.to_s.capitalize.singularize).parent.to_s.pluralize
        @url = "https://scrumy.com/api/#{parent}/#{args.first || @project}/#{id}.json"
      end
      # Here we request the resource using the singular of the resource name as the root
      # to extract from the returned JSON hash.
      response = get(@url, id.to_s.singularize)
      
      # Responses are of two types, either arrays of hashes or a single hash
      if response.kind_of? Array
        # If it's array collect a new array by constructing objects based on the resource
        # name capitalized and singularized.
        response.collect do |obj|
          cls = Scrumy.const_get(id.to_s.capitalize.singularize)
          cls.new(obj, self)
        end
      else
        # Otherwise create a single new object of the correct type.
        Scrumy.const_get(id.to_s.capitalize.singularize).new(response, self)
      end
    end
    
    def scrumer(name)
      @url = "https://scrumy.com/api/scrumers/#{name}.json"
      Scrumer.new(get(@url, 'scrumer'), self)
    end

    def snapshots(id=:current)
      sprint_id = sprint(id.to_s)['id']
      @url = "https://scrumy.com/api/sprints/#{sprint_id}/snapshots.json"
      get(@url, nil)
    end
    
    protected
    
      def get(url, root)
        begin
          resource = RestClient::Resource.new(url, @project, @password)
          resource.get {|response, request, result, &block|
            case response.code
            when 200
              json = JSON.parse(response.body)
              if json.kind_of?(Array) && root
                json.collect{|item| 
                  item[root]
                }
              else
                root ? json[root] : json
              end
            else
              response.return!(request, result, &block)
            end
          }
        rescue => e
          puts "Problem fetching #{@url}"
          throw e
        end
      end
  
  end
  
  class Object
    attr_reader :id
    def initialize(args, client)
      @client = client
      args.each do |k,v|
        instance_variable_set("@#{k}", v) unless v.nil?
      end
    end
    def method_missing(id, *args, &block)
      if id.to_s =~ /=$/
        id = id.to_s.gsub(/=$/,'')        
        instance_variable_set("@#{id}", args.first)
      else
        instance_variable_get("@#{id}")
      end
    end
    
    def self.belongs_to(parent)
      @parent = parent
    end
    
    def self.parent
      @parent
    end
    
    def self.lazy_load(method)
      define_method(method) {
        client = instance_variable_get("@client")
        ivar = instance_variable_get("@#{method}")
        clss = Scrumy.const_get(method.to_s.capitalize.singularize)
        root = method.to_s.singularize
        
        if ivar.kind_of? Array
          ivar.collect!{|single| clss.new(single[root], client)} if ivar and ivar.first.kind_of?Hash
        elsif ivar
          ivar = clss.new(ivar, client)
        end
        
        return ivar if ivar
        
        ivar = client.send(method, instance_variable_get("@id"))
      }
    end
  end
  
  class Sprint < Scrumy::Object
    belongs_to :scrumy
    lazy_load :stories
  end
  
  class Story < Scrumy::Object
    belongs_to :sprint
    lazy_load :tasks
  end
  
  class Task < Scrumy::Object
    belongs_to :story
    lazy_load :scrumer
    
    def time
      return 3.0 if !(@title =~ /\((\d+.*)([hHmM].*)\)/)      
      time, unit = $~.captures
      unit =~ /m/i ? time.to_f / 60.0 : time.to_f      
    end
  end
  
  class Scrumer < Scrumy::Object
    belongs_to :scrumy
  end
end