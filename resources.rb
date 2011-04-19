# Models
# ======
#
# Scrumy defines several models, each of which have a corresponding REST resource.
#
# * Scrumy
# * Sprint
# * Story
# * Task
# * Scrumer
# * Snapshot
#
# For now the models are explicitly defined using a resource DSL.

resource :scrumy do
  show "https://scrumy.com/api/scrumies/:project.json"
  lazy_load :sprint
end  

resource :sprint do
  list      "https://scrumy.com/api/scrumies/:project/sprints.json"
  current   "https://scrumy.com/api/scrumies/:project/sprints/current.json"
  show      "https://scrumy.com/api/sprints/:id.json"
  
  lazy_load :stories
end 

resource :story do
  list "https://scrumy.com/api/sprints/:id/stories.json"
  show "https://scrumy.com/api/stories/:id.json"

  lazy_load :tasks
end

resource :task do
  list "https://scrumy.com/api/stories/:id/tasks.json"
  show "https://scrumy.com/api/tasks/:id.json"

  lazy_load :scrumer

  helper :time do
    # Gets the time out of the title instance variable
    # and converts it into hours or fractions thereof     
    return 3.0 if !(@title =~ /\((\d+.*)([hHmM].*)\)/)      
    time, unit = $~.captures
    unit =~ /m/i ? time.to_f / 60.0 : time.to_f      
  end
end

resource :scrumer do
  list "https://scrumy.com/api/scrumies/:project/scrumers.json"
  show "https://scrumy.com/api/scrumers/:id.json"
  
  helper :id do
    @name
  end
end

resource :snapshot do
  list "https://scrumy.com/api/sprints/:id/snapshots.json"
  show "https://scrumy.com/api/snapshots/:id.json"
end  