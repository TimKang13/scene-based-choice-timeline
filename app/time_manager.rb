# -*- coding: utf-8 -*-
# app/time_manager.rb

class TimeManager
  attr_reader :fps, :real_tick, :scene_duration_ticks

  def initialize(fps: 60)
    @fps = fps
    @real_tick = 0
    @scene_start_tick = 0
    @scene_duration_ticks = 0
    @total_paused_ticks = 0
    @paused = false
  end

  def update(args)
    next_tick = args.state.tick_count
    delta = [next_tick - @real_tick, 0].max
    @real_tick = next_tick
    if @paused
      @total_paused_ticks += delta
    end
  end

  def start_scene(duration_seconds)
    @scene_start_tick = @real_tick
    @scene_duration_ticks = (duration_seconds.to_f * @fps).to_i
    @total_paused_ticks = 0
    @paused = false
  end

  def pause
    @paused = true
  end

  def resume
    @paused = false
  end

  def paused?
    @paused
  end

  def scene_time_ticks
    t = @real_tick - @scene_start_tick - @total_paused_ticks
    t < 0 ? 0 : t
  end

  def scene_time_seconds
    scene_time_ticks.to_f / @fps
  end

  def progress_ratio
    return 0.0 if @scene_duration_ticks <= 0
    x = scene_time_ticks.to_f / @scene_duration_ticks
    x > 1.0 ? 1.0 : x
  end
end


