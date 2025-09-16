# -*- coding: utf-8 -*-
# app/focus_mask.rb

class FocusMask
  def initialize(game_state)
    @game_state = game_state
    @dim_alpha = 160
  end

  def configure(dim_alpha: nil)
    @dim_alpha = dim_alpha if dim_alpha
  end

  def draw(args)
    target = @game_state.focus_target
    return unless target

    rect = focus_rect(args)
    return unless rect

    x = rect[:x]
    y = rect[:y]
    w = rect[:w]
    h = rect[:h]

    # Draw 4 rectangles to dim everything except the focus rect
    dim = ->(rx, ry, rw, rh) do
      args.outputs.solids << { x: rx, y: ry, w: rw, h: rh, r: 0, g: 0, b: 0, a: @dim_alpha }
    end

    # Top
    dim.call(0, y + h, 1280, 720 - (y + h))
    # Bottom
    dim.call(0, 0, 1280, y)
    # Left
    dim.call(0, y, x, h)
    # Right
    dim.call(x + w, y, 1280 - (x + w), h)
  end

  private

  def focus_rect(args)
    case @game_state.focus_target
    when :situation
      # Center top area where situation text is drawn
      { x: 140, y: 540, w: 1000, h: 140 }
    when :choices
      choices_count = current_choices_length
      start_y = 340
      choice_h = 40
      spacing = 10
      total_h = choices_count * (choice_h + spacing)
      y_bottom = start_y - total_h
      { x: 240, y: [y_bottom - 10, 0].max, w: 800, h: total_h + 20 }
    when :choice_index
      index = (@game_state.focus_choice_index || 0).to_i
      start_y = 340
      choice_h = 40
      spacing = 10
      y = start_y - (index * (choice_h + spacing))
      { x: 240, y: y - 10, w: 800, h: choice_h + 20 }
    else
      nil
    end
  end

  def current_choices_length
    typed = @game_state.typed_choices || []
    return typed.length if typed && typed.length > 0
    choices = @game_state.get_current_choices || []
    choices.length
  end
end


