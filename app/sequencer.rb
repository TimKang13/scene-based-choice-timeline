# -*- coding: utf-8 -*-
# app/sequencer.rb

class Sequencer
  def initialize(game_state, typewriter)
    @game_state = game_state
    @typewriter = typewriter
    @script = nil
    @current_scene_id = nil
    @pending_step = nil
  end

  def start_scene(situation_text, choice_texts)
    # Step 1: focus situation and type
    @game_state.focus_target = :situation
    @typewriter.start_situation(situation_text)
    @pending_step = :choices
    @game_state.typed_choices = Array.new(choice_texts.length) { "" }
    @next_choices = choice_texts
  end

  def tick(args)
    # Only unfreeze clock when ALL typing is complete (no pending steps AND typewriter not busy)
    if !@pending_step && !@typewriter.busy? && @game_state.reading_pause && @game_state.reading_pause[:active]
      # Release reading pause (clock resumes) - let GameState handle the timing adjustment
      @game_state.reading_pause[:time_left] = 0.0  # This will trigger GameState to handle the adjustment
      @game_state.focus_target = nil
    end

    return unless @pending_step
    return if @typewriter.busy?

    case @pending_step
    when :choices
      @game_state.focus_target = :choices
      @typewriter.start_choices(@next_choices, line_delay: 0.0)
      @pending_step = :done
    when :done
      # Clear focus; timer will resume when typewriter finishes (handled above)
      @game_state.focus_target = nil
      @pending_step = nil
    end
  end

  def rewrite_situation(old_text, new_text)
    @game_state.focus_target = :situation
    @typewriter.rewrite_situation(old: old_text, new: new_text)
  end

  def rewrite_choice(index, old_text, new_text)
    @game_state.focus_target = :choice_index
    @game_state.focus_choice_index = index
    @typewriter.rewrite_choice(index: index, old: old_text, new: new_text)
  end
end


