# Models
# ======
#
# Scrumy defines several models, each of which have a corresponding REST resource.
#
# * Scrumy (not yet implemented here)
# * Sprint
# * Story
# * Task
# * Scrumer
# * Snapshot (implemented in client, but not as a model yet)
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
    return 3.0 if !(@title =~ /\((\d+.*)([hHmM].*)\)/)      
    time, unit = $~.captures
    # and converts it into hours or fractions thereof
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