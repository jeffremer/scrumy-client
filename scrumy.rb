require 'json'
require 'rest_client'
require 'fastercsv'

module Scrumy
  class Client
    attr_reader :url
    def initialize(project, password)
      @project, @password = project, password
    end

    def sprint(id="current")
      if id == "current"
        @url = "https://#{@project}:#{@password}@scrumy.com/api/scrumies/#{@project}/sprints/#{id}.json"
      else
        @url = "https://#{@project}:#{@password}@scrumy.com/api/sprints/#{id}.json"
      end
      Sprint.new(get(@url, 'sprint'))
    end
  
    def sprints
      @url = "https://#{@project}:#{@password}@scrumy.com/api/scrumies/#{@project}/sprints.json"
      get(url, nil)
    end

    def snapshots(id="current")
      sprint_id = sprint(id)['id']
      @url = "https://#{@project}:#{@password}@scrumy.com/api/sprints/#{sprint_id}/snapshots.json"
      get(@url, nil)
    end
  
    def regression_steps(include_header=true)
        current_sprint = sprint
        rows = current_sprint['stories'].collect{|story|
          if !story['story']['tasks'].nil?
            [story['story']['title']].push(
              story['story']['tasks'].collect{|task|
                task['task']['scrumer']['name']
              }.uniq().reject{|n| n == 'info'}.join(', ')
            )
          else
            [story['story']['title']]
          end
        }
        rows.unshift(['Scrumy Item'.upcase, 'Worked On'.upcase]) if include_header && !rows.nil?
        rows
    end
  
    protected
    
      def get(url, root)
        RestClient.get(url){|response, request, result, &block|
          case response.code
          when 200
            json = JSON.parse(response.to_str)
            root ? json[root] : json
          else
            response.return!(request, result, &block)
          end
        }
      end
  
  end
  
  class Object
    attr_reader :id
    def initialize args
      args.each do |k,v|
        instance_variable_set("@#{k}", v) unless v.nil?
      end
    end
  end  
  class Sprint
    attr_reader :start_date
  end
  class Story
  end
  class Task
  end
  class Scrumer
  end
end  

class Array
  def to_csv
    str=''
    FasterCSV.generate(str, :col_sep => "\t") do |csv|
      self.each do |r|
        csv << r
      end
    end
    str
  end
end