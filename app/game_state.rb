# -*- coding: utf-8 -*-
# app/game_state.rb

class GameState
  attr_accessor :game_state, :scene, :current_state, :player, :npc, :choices, :timing, :current_situation, :current_outcome, :dice_result, :api_response, :selected_choice_text, :reading_pause, :show_reasoning

  def initialize
    @game_state ||= :situation_explanation  # Game flow state (situation_explanation, scene_generation, etc.)
    @scene ||= nil  # Current scene object
    @current_state ||= nil  # Current state within the scene (for getting situation and choices)
    @player ||= nil
    @npc ||= nil
    @choices ||= []
    @timing ||= {
      scene_start_time: 0,
      current_time: 0,
      scene_duration: 0
    }
    @current_situation ||= ""
    @current_outcome ||= ""
    @dice_result ||= nil
    @api_response ||= nil
    @selected_choice_text ||= nil
    @reading_pause ||= { active: false, time_left: 0.0, state_id: nil, started_tick: nil }
    @show_reasoning ||= false
  end

  # State machine transitions
  def transition_to(new_state)
    puts "State transition: #{@game_state} -> #{new_state}"
    @game_state = new_state
  end

  def get_current_state
    @game_state
  end

  def update_timing(args)
    # Handle reading pause countdown and freeze scene time
    if @reading_pause[:active]
      @reading_pause[:time_left] -= 1.0 / 60.0
      if @reading_pause[:time_left] <= 0.0
        paused_ticks = (args.state.tick_count - (@reading_pause[:started_tick] || args.state.tick_count))
        @timing[:scene_start_time] += paused_ticks
        @reading_pause[:active] = false
        @reading_pause[:time_left] = 0.0
        @reading_pause[:started_tick] = nil
      else
        return
      end
    end

    @timing[:current_time] = args.state.tick_count - @timing[:scene_start_time]
  end

  def start_new_scene(scene, args)
    @scene = scene
    @timing[:scene_start_time] = args.state.tick_count
    @timing[:current_time] = 0
    # Convert seconds to ticks (assuming 60 FPS)
    duration_seconds = scene.duration || 15
    @timing[:scene_duration] = duration_seconds * 60
    
    puts "Scene started with #{scene.states.length} states"
    puts "Scene duration: #{duration_seconds} seconds"

    # Initialize first state's reading pause window
    if @scene && @scene.states && @scene.states.first
      first_state = @scene.states.first
      total_read = (first_state.time_to_read || 0).to_f + visible_choices_read_time(first_state)
      if total_read > 0.0
        @reading_pause[:active] = true
        @reading_pause[:time_left] = total_read
        @reading_pause[:state_id] = first_state.id
        @reading_pause[:started_tick] = args.state.tick_count
      else
        @reading_pause[:active] = false
        @reading_pause[:time_left] = 0.0
        @reading_pause[:state_id] = nil
        @reading_pause[:started_tick] = nil
      end
    end
  end

  def get_active_state
    return nil unless @scene && @scene.states

    current_time = @timing[:current_time]
    current_time_seconds = current_time / 60.0  # Convert frames to seconds

    active_state = @scene.states.find do |state|
      state.at <= current_time_seconds && current_time_seconds <= (state.at + state.duration)
    end

    prev_state_id = @current_state && @current_state.id
    @current_state = active_state

    # If entering a new state, start that state's reading pause
    if @current_state && @current_state.id != prev_state_id
      total_read = (@current_state.time_to_read || 0).to_f + visible_choices_read_time(@current_state)
      if total_read > 0.0
        @reading_pause[:active] = true
        @reading_pause[:time_left] = total_read
        @reading_pause[:state_id] = @current_state.id
        # mark when pause starts to compensate scene_start_time later
        @reading_pause[:started_tick] = @timing[:scene_start_time] + @timing[:current_time]
      else
        @reading_pause[:active] = false
        @reading_pause[:time_left] = 0.0
        @reading_pause[:state_id] = @current_state.id
        @reading_pause[:started_tick] = nil
      end
    end

    active_state
  end

  def get_visible_choices
    active_state = get_active_state
    return [] unless active_state
    
    # Return choices that belong to the active state
    active_state.choices || []
  end

  def visible_choices_read_time(state)
    return 0.0 unless state && state.choices
    state.choices.reduce(0.0) { |sum, c| sum + (c.time_to_read || 0).to_f }
  end

  def scene_timeout
    @timing[:current_time] >= @timing[:scene_duration]
  end

  # Get current situation string from current_state
  def get_current_situation
    return @current_situation if @current_state.nil?
    @current_state.text || @current_situation
  end

  # Get current choices from current_state
  def get_current_choices
    return [] if @current_state.nil?
    @current_state.choices || []
  end

  def reset_for_new_scene
    @scene = nil
    @current_state = nil
    @dice_result = nil
    @api_response = nil
    @selected_choice_text = nil
    @timing[:scene_start_time] = 0
    @timing[:current_time] = 0
    @timing[:scene_duration] = 0
  end
end
