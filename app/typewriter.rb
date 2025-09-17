# -*- coding: utf-8 -*-
# app/typewriter.rb

class Typewriter
  def initialize(game_state)
    @game_state = game_state
    @default_cps = 25.0  # Keep original typing speed
    @delete_cps = 55.0   # Much faster for erasing
    reset_job
  end

  def configure(cps: nil, delete_cps: nil)
    @default_cps = cps if cps
    @delete_cps = delete_cps if delete_cps
  end

  # Public API
  def start_situation(text, cps: nil)
    prepare_typing(target: :situation, text: text, cps: cps)
  end

  def start_choices(lines, cps: nil, line_delay: 0.0)
    @game_state.typed_choices = Array.new(lines.length) { "" }
    @job = {
      type: :choices,
      lines: lines,
      line_index: 0,
      char_index: 0,
      cps: (cps || @default_cps).to_f,
      line_delay: line_delay.to_f,
      next_tick: nil,
      delay_until: nil,
      done: false
    }
  end

  def rewrite_situation(old:, new:, cps: nil)
    common = common_prefix_length(old || "", new || "")
    @job = {
      type: :situation_rewrite,
      old_text: old || "",
      new_text: new || "",
      common_len: common,
      delete_remaining: (old || "").length - common,
      visible_text: (old || ""),
      cps: (cps || @default_cps).to_f,
      next_tick: nil,
      phase: :deleting,
      done: false
    }
    @game_state.typed_situation = @job[:visible_text]
  end

  def rewrite_choice(index:, old:, new:, cps: nil)
    ensure_choices_buffer(index)
    common = common_prefix_length(old || "", new || "")
    @job = {
      type: :choice_rewrite,
      index: index,
      old_text: old || "",
      new_text: new || "",
      common_len: common,
      delete_remaining: (old || "").length - common,
      visible_text: (old || ""),
      cps: (cps || @default_cps).to_f,
      next_tick: nil,
      phase: :deleting,
      done: false
    }
    @game_state.typed_choices[index] = @job[:visible_text]
  end

  def tick(args)
    return unless @job
    return if @job[:done]

    # Use different speeds for deleting vs typing
    current_cps = get_current_cps
    ticks_per_char = (60.0 / current_cps.to_f)
    @job[:next_tick] ||= args.state.tick_count

    # Handle line delay for choices
    if @job[:type] == :choices && @job[:delay_until]
      return if args.state.tick_count < @job[:delay_until]
      @job[:delay_until] = nil
    end

    return if args.state.tick_count < @job[:next_tick]
    @job[:next_tick] += ticks_per_char

    case @job[:type]
    when :situation
      advance_situation_typing
    when :choices
      advance_choices_typing(args, ticks_per_char)
    when :situation_rewrite
      advance_situation_rewrite
    when :choice_rewrite
      advance_choice_rewrite
    end
  end

  def busy?
    @job && !@job[:done]
  end

  def finish_now!
    return unless @job
    case @job[:type]
    when :situation
      @game_state.typed_situation = @job[:text]
    when :choices
      @game_state.typed_choices = @job[:lines].dup
    when :situation_rewrite
      @game_state.typed_situation = @job[:new_text]
    when :choice_rewrite
      @game_state.typed_choices[@job[:index]] = @job[:new_text]
    end
    @job[:done] = true
  end

  private

  def get_current_cps
    # Use faster speed for deleting phases
    if @job && (@job[:type] == :situation_rewrite || @job[:type] == :choice_rewrite)
      if @job[:phase] == :deleting
        return @delete_cps
      end
    end
    # Use normal speed for typing
    @job[:cps] || @default_cps
  end

  def reset_job
    @job = nil
  end

  def prepare_typing(target:, text:, cps: nil)
    case target
    when :situation
      @game_state.typed_situation = ""
      @job = {
        type: :situation,
        text: text || "",
        char_index: 0,
        cps: (cps || @default_cps).to_f,
        next_tick: nil,
        done: false
      }
    end
  end

  def advance_situation_typing
    text = @job[:text]
    i = @job[:char_index]
    if i < text.length
      @game_state.typed_situation = text[0..i]
      @job[:char_index] += 1
    else
      @job[:done] = true
    end
  end

  def advance_choices_typing(args, ticks_per_char)
    lines = @job[:lines]
    li = @job[:line_index]
    ci = @job[:char_index]
    return complete_choices_job if li >= lines.length

    current_line = lines[li] || ""
    ensure_choices_buffer(li)

    if ci < current_line.length
      @game_state.typed_choices[li] = current_line[0..ci]
      @job[:char_index] += 1
    else
      # Line complete; schedule delay then move to next line
      if @job[:line_delay] && @job[:line_delay] > 0
        delay_ticks = (@job[:line_delay] * 60.0)
        @job[:delay_until] = args.state.tick_count + delay_ticks
      end
      @job[:line_index] += 1
      @job[:char_index] = 0
    end
  end

  def complete_choices_job
    # Ensure all remaining lines are set exactly
    (0...@job[:lines].length).each do |i|
      ensure_choices_buffer(i)
      @game_state.typed_choices[i] = @job[:lines][i] || ""
    end
    @job[:done] = true
  end

  def advance_situation_rewrite
    if @job[:phase] == :deleting
      if @job[:delete_remaining] > 0
        @job[:visible_text] = @job[:visible_text][0...-1]
        @game_state.typed_situation = @job[:visible_text]
        @job[:delete_remaining] -= 1
      else
        @job[:phase] = :typing
      end
    else
      new_text = @job[:new_text]
      common_len = @job[:common_len]
      current_len = @game_state.typed_situation.length
      if current_len < new_text.length
        @game_state.typed_situation = new_text[0..current_len]
      else
        @job[:done] = true
      end
    end
  end

  def advance_choice_rewrite
    index = @job[:index]
    ensure_choices_buffer(index)

    if @job[:phase] == :deleting
      if @job[:delete_remaining] > 0
        @job[:visible_text] = @job[:visible_text][0...-1]
        @game_state.typed_choices[index] = @job[:visible_text]
        @job[:delete_remaining] -= 1
      else
        @job[:phase] = :typing
      end
    else
      new_text = @job[:new_text]
      current_len = (@game_state.typed_choices[index] || "").length
      if current_len < new_text.length
        @game_state.typed_choices[index] = new_text[0..current_len]
      else
        @job[:done] = true
      end
    end
  end

  def ensure_choices_buffer(index)
    @game_state.typed_choices ||= []
    while @game_state.typed_choices.length <= index
      @game_state.typed_choices << ""
    end
  end

  def common_prefix_length(a, b)
    max = [a.length, b.length].min
    i = 0
    while i < max && a[i] == b[i]
      i += 1
    end
    i
  end
end


