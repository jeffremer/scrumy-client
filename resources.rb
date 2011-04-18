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

resource :sprint do
  belongs_to :scrumy
  lazy_load :stories
end 

resource :story do
  belongs_to :sprint
  lazy_load :tasks
end

resource :task do
  belongs_to :story
  lazy_load :scrumer
  helper :time do
    return 3.0 if !(@title =~ /\((\d+.*)([hHmM].*)\)/)      
    time, unit = $~.captures
    # and converts it into hours or fractions thereof
    unit =~ /m/i ? time.to_f / 60.0 : time.to_f      
  end
end

resource :scrumer do
  belongs_to :scrumy
end