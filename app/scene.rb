class Scene
  attr_accessor :id, :duration, :states, :reading_time_estimate

  def initialize(id, duration, states, reading_time_estimate = nil)
    @id = id
    @duration = duration
    @states = states
    @reading_time_estimate = reading_time_estimate
  end
end

class State
  attr_accessor :id, :at, :duration, :text, :time_to_read, :choices

  def initialize(id, at, duration, text, time_to_read, choices)
    @id = id
    @at = at
    @duration = duration
    @text = text
    @time_to_read = time_to_read
    @choices = choices
  end
end

class Choice
  attr_accessor :id, :text, :time_to_read

  def initialize(id, text, time_to_read)
    @id = id
    @text = text
    @time_to_read = time_to_read
  end
end
