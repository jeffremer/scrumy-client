
require 'fastercsv'

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

