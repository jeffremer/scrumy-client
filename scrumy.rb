require 'json'
require 'rest_client'
require 'active_support/inflector'

module Scrumy
  class Client
    attr_reader :url
    def initialize(project, password)
      @project, @password = project, password
    end
    
    def sprint
      method_missing(:sprint, :current)
    end
    
    def method_missing(id, *args, &block)
      if args.first == :current
        @url = "https://scrumy.com/api/scrumies/#{@project}/sprints/#{args.first.to_s}.json"
      else
        parent = Scrumy.const_get(id.to_s.capitalize.singularize).parent.to_s.pluralize
        @url = "https://scrumy.com/api/#{parent}/#{args.first || @project}/#{id}.json"
      end
      response = get(@url, id.to_s.singularize)
      if response.kind_of? Array
        response.collect do |obj|
          cls = Scrumy.const_get(id.to_s.capitalize.singularize)
          cls.new(obj, self)
        end
      else
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