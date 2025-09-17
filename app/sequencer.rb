# -*- coding: utf-8 -*-
# app/sequencer.rb

class Sequencer
  def initialize(game_state, typewriter)
    @game_state = game_state
    @typewriter = typewriter
    @script = nil
    @current_scene_id = nil
    @pending_step = nil
    @rewrite_queue = [] # queue of [type, ...payload]
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
    # Drive pending rewrites one item at a time
    if !@pending_step && !@typewriter.busy? && !@rewrite_queue.empty?
      item = @rewrite_queue.shift
      case item[0]
      when :situation
        _, old_text, new_text = item
        rewrite_situation(old_text, new_text)
      when :choice
        _, index, old_text, new_text = item
        rewrite_choice(index, old_text, new_text)
      end
    end

    # When all typing is complete and no rewrites left, resume scene time if it is paused
    if !@pending_step && @rewrite_queue.empty? && !@typewriter.busy? && @game_state.time && @game_state.time.paused?
      @game_state.time.resume
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

  def begin_state_transition(old_situation, new_situation, old_choices, new_choices)
    @rewrite_queue ||= []
    @rewrite_queue.clear

    old_situation ||= ""
    new_situation ||= ""
    if old_situation != new_situation
      @rewrite_queue << [:situation, old_situation, new_situation]
    end

    old_choices ||= []
    new_choices ||= []

    # Build multiset of new choices to detect persistence by text (with counts)
    new_counts = Hash.new(0)
    new_choices.each { |t| new_counts[t || ""] += 1 }

    # Determine which old indices are persistent (text still exists in new choices)
    persistent_used = Hash.new(0)
    persistent_index = Array.new(old_choices.length, false)
    old_choices.each_with_index do |old_text, idx|
      key = old_text || ""
      if new_counts[key] - persistent_used[key] > 0 && key != ""
        persistent_index[idx] = true
        persistent_used[key] += 1
      end
    end

    max_len = [old_choices.length, new_choices.length].max
    (0...max_len).each do |i|
      old_text = old_choices[i] || ""
      next if persistent_index[i] # keep persistent text in place; no rewrite

      # Desired target is the new text at the same index, if any.
      candidate = new_choices[i] || ""

      # If candidate is actually already kept persistently somewhere else, don't move it here.
      if candidate != "" && new_counts[candidate] > 0
        # Count how many times this candidate is already occupying persistent slots
        already_kept = 0
        old_choices.each_with_index do |t, j|
          if persistent_index[j] && (t || "") == candidate
            already_kept += 1
          end
        end
        # If all occurrences are already kept, we shouldn't place it here.
        candidate = "" if already_kept >= new_counts[candidate]
      end

      # Only enqueue if the target differs from current
      target = candidate
      target ||= ""
      next if old_text == target
      @rewrite_queue << [:choice, i, old_text, target]
    end
  end
end


