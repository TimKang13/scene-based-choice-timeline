# -*- coding: utf-8 -*-
# app/game_state.rb

require "app/time_manager"

class GameState
  attr_accessor :game_state, :scene, :current_state, :player, :npc, :choices, :current_situation, :current_outcome, :dice_result, :api_response, :selected_choice_text, :show_reasoning, :typed_situation, :typed_choices, :focus_target, :focus_choice_index, :time, :last_handled_state_id

  def initialize
    @game_state ||= :situation_explanation  # Game flow state (situation_explanation, scene_generation, etc.)
    @scene ||= nil  # Current scene object
    @current_state ||= nil  # Current state within the scene (for getting situation and choices)
    @player ||= nil
    @npc ||= nil
    @choices ||= []
    @current_situation ||= ""
    @current_outcome ||= ""
    @dice_result ||= nil
    @api_response ||= nil
    @selected_choice_text ||= nil
    @show_reasoning ||= false
    @typed_situation ||= ""
    @typed_choices ||= []
    @focus_target ||= nil
    @focus_choice_index ||= nil
    @time ||= TimeManager.new
    @last_handled_state_id ||= nil
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
    @time.update(args)
  end

  def start_new_scene(scene, args)
    @scene = scene
    duration_seconds = scene.duration || 15
    @time.start_scene(duration_seconds)
    @current_state = nil
    @last_handled_state_id = nil
    
    puts "Scene started with #{scene.states.length} states"
    puts "Scene duration: #{duration_seconds} seconds"
  end

  def get_active_state
    return nil unless @scene && @scene.states

    current_time_seconds = @time.scene_time_seconds

    active_state = @scene.states.find do |state|
      state.at <= current_time_seconds && current_time_seconds <= (state.at + state.duration)
    end

    @current_state = active_state
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
    @time.progress_ratio >= 1.0
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
    @last_handled_state_id = nil
  end
end
