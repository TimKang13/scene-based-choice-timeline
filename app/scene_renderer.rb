# -*- coding: utf-8 -*-
# app/scene_renderer.rb

class SceneRenderer
  def initialize
    @outputs = nil
    @game_state = nil
  end

  def render(args, game_state)
    @outputs = args.outputs
    @game_state = game_state
    
    case game_state.get_current_state
    when :situation_explanation
      render_situation_explanation
    when :scene_generation
      render_scene_generation
    when :choice_phase
      render_choice_phase
    when :dice_result
      render_dice_result
    when :outcome
      render_outcome
    else
      render_default
    end
  end

  private

  def render_situation_explanation
    @outputs.background_color = [20, 20, 40]
    @outputs.labels << {
      x: 640, y: 600, text: "SITUATION EXPLANATION", 
      size_enum: 4, alignment_enum: 1, r: 255, g: 255, b: 255
    }
    
    if @game_state.current_outcome && !@game_state.current_outcome.empty?
      wrap_text(@game_state.current_outcome, 640, 500, 600, 2)
    else
      @outputs.labels << {
        x: 640, y: 500, text: "Generating scene...", 
        size_enum: 2, alignment_enum: 1, r: 200, g: 200, b: 200
      }
    end
  end

  def render_scene_generation
    @outputs.background_color = [40, 20, 20]
    @outputs.labels << {
      x: 640, y: 600, text: "GENERATING SCENE", 
      size_enum: 4, alignment_enum: 1, r: 255, g: 255, b: 255
    }
    
    @outputs.labels << {
      x: 640, y: 500, text: "Creating new scene with states and choices...", 
      size_enum: 2, alignment_enum: 1, r: 200, g: 200, b: 200
    }
  end

  def render_choice_phase
    @outputs.background_color = [20, 40, 20]
    
    # Render current state text
    active_state = @game_state.get_active_state
    if active_state
      @outputs.labels << {
        x: 640, y: 600, text: active_state.text, 
        size_enum: 3, alignment_enum: 1, r: 255, g: 255, b: 255
      }
    end

    # Render reading pause countdown overlay if active
    if @game_state.reading_pause && @game_state.reading_pause[:active]
      render_reading_pause_overlay
    end

    # Render time bar
    render_time_bar

    # Render choices
    current_choices = @game_state.get_current_choices
    render_choices(current_choices)

    # Render scene progress
    render_scene_progress
  end

  def render_dice_result
    @outputs.background_color = [40, 40, 20]

    # Always show selected choice in top-left during golden dice phase
    render_selected_choice_overlay
    
    
    
    if @game_state.dice_result
      @outputs.labels << {
        x: 640, y: 600, text: "DICE RESULT", 
        size_enum: 4, alignment_enum: 1, r: 255, g: 255, b: 255
      }
      roll = @game_state.dice_result[:roll]
      big_s = @game_state.dice_result[:big_success_threshold] || "?"
      succ = @game_state.dice_result[:success_threshold] || "?"
      small_f = @game_state.dice_result[:small_failure_threshold] || "?"
      reasoning = @game_state.dice_result[:reasoning]

      # Show thresholds first if not rolled yet
      if roll.nil?
        @outputs.labels << { x: 640, y: 520, text: "Thresholds - Huge Success: #{big_s}  Success: #{succ}  Big Failure: <#{small_f}", size_enum: 2, alignment_enum: 1, r: 200, g: 200, b: 200 }
        if @game_state.show_reasoning && reasoning && !reasoning.empty?
          wrap_text("Reasoning: #{reasoning}", 640, 480, 800, 1)
        end
        @outputs.labels << { x: 640, y: 100, text: "Press SPACE to roll", size_enum: 2, alignment_enum: 1, r: 255, g: 255, b: 255 }
      else
        cat = (@game_state.dice_result[:category] || :failure).to_s.upcase
        color = case @game_state.dice_result[:category]
                when :huge_success then [0, 255, 128]
                when :success then [0, 200, 255]
                when :failure then [255, 200, 0]
                when :big_failure then [255, 0, 0]
                else [200, 200, 200]
                end
        @outputs.labels << { x: 640, y: 520, text: "Rolled: #{roll}/20", size_enum: 2, alignment_enum: 1, r: 255, g: 255, b: 255 }
        @outputs.labels << { x: 640, y: 480, text: "Category: #{cat}", size_enum: 3, alignment_enum: 1, r: color[0], g: color[1], b: color[2] }
        @outputs.labels << { x: 640, y: 340, text: "Press SPACE for outcome", size_enum: 2, alignment_enum: 1, r: 255, g: 255, b: 255 }
      end
    else 
      @outputs.labels << {
        x: 640, y: 600, text: "GOLDEN DICE", 
        size_enum: 4, alignment_enum: 1, r: 255, g: 255, b: 255
      }

      @outputs.labels << {
        x: 640, y: 500, text: "Generating dice probabilities...", size_enum: 2, alignment_enum: 1, r: 200, g: 200, b: 200
      }
    end
  end

  def render_outcome
    @outputs.background_color = [20, 20, 20]
    @outputs.labels << {
      x: 640, y: 600, text: "OUTCOME", 
      size_enum: 4, alignment_enum: 1, r: 255, g: 255, b: 255
    }

    # Keep the chosen action visible in top-left during outcome
    render_selected_choice_overlay


    if @game_state.api_response && @game_state.api_response[:outcome_description]
          # Show success/failure category if available
      if @game_state.dice_result && @game_state.dice_result[:category]
        cat = (@game_state.dice_result[:category] || :failure).to_s.upcase
        color = case @game_state.dice_result[:category]
                when :huge_success then [0, 255, 128]
                when :success then [0, 200, 255]
                when :failure then [255, 200, 0]
                when :big_failure then [255, 0, 0]
                else [200, 200, 200]
                end
        @outputs.labels << { x: 640, y: 540, text: cat, size_enum: 5, alignment_enum: 1, r: color[0], g: color[1], b: color[2] }
      end
      wrap_text(@game_state.api_response[:outcome_description], 640, 480, 800, 2)
      @outputs.labels << { x: 640, y: 100, text: "Press SPACE to continue", size_enum: 2, alignment_enum: 1, r: 255, g: 255, b: 255 }
    else
      @outputs.labels << {
        x: 640, y: 500, text: "Rolling Golden Dice...", 
        size_enum: 2, alignment_enum: 1, r: 200, g: 200, b: 200
      }
    end
  end

  def render_default
    @outputs.background_color = [40, 40, 40]
    @outputs.labels << {
      x: 640, y: 400, text: "Unknown state: #{@game_state.get_current_state}", 
      size_enum: 2, alignment_enum: 1, r: 255, g: 0, b: 0
    }
  end

  def render_time_bar
    return unless @game_state.scene
    
    bar_width = 600
    bar_height = 20
    bar_x = 640 - bar_width / 2
    bar_y = 100
    
    # Background bar
    @outputs.solids << {
      x: bar_x, y: bar_y, w: bar_width, h: bar_height, 
      r: 50, g: 50, b: 50
    }
    
    # Progress bar (frozen while reading pause is active since current_time is frozen)
    progress = [@game_state.timing[:current_time] / @game_state.timing[:scene_duration], 1.0].min
    progress_width = bar_width * progress
    
    @outputs.solids << {
      x: bar_x, y: bar_y, w: progress_width, h: bar_height, 
      r: 100, g: 200, b: 100
    }
    
    # State change markers
    if @game_state.scene && @game_state.scene.states && @game_state.scene.duration.to_f > 0
      duration_seconds = @game_state.scene.duration.to_f
      current_time_seconds = @game_state.timing[:current_time] / 60.0
      @game_state.scene.states.each do |state|
        marker_ratio = state.at.to_f / duration_seconds
        marker_x = bar_x + (bar_width * marker_ratio)
        # Clamp marker within bar bounds
        marker_x = [[marker_x, bar_x].max, bar_x + bar_width].min
        is_active = state.at <= current_time_seconds && current_time_seconds < (state.at + state.duration)
        color = is_active ? [255, 255, 0] : [200, 200, 255]
        @outputs.solids << { x: marker_x.to_i - 1, y: bar_y - 4, w: 2, h: bar_height + 8, r: color[0], g: color[1], b: color[2] }
      end
    end
    
    # Time text
    current_time_seconds = @game_state.timing[:current_time] / 60.0
    scene_duration_seconds = @game_state.timing[:scene_duration] / 60.0
    time_text = "#{current_time_seconds.to_i}s / #{scene_duration_seconds.to_i}s"
    @outputs.labels << {
      x: 640, y: bar_y + 30, text: time_text, 
      size_enum: 1, alignment_enum: 1, r: 255, g: 255, b: 255
    }
  end

  def render_reading_pause_overlay
    # Dim background
    @outputs.solids << { x: 0, y: 0, w: 1280, h: 720, r: 0, g: 0, b: 0, a: 128 }
    time_left = [@game_state.reading_pause[:time_left], 0.0].max
    seconds_left = time_left.ceil
    @outputs.labels << { x: 640, y: 450, text: "Get ready...", size_enum: 4, alignment_enum: 1, r: 255, g: 255, b: 0 }
    @outputs.labels << { x: 640, y: 420, text: "#{seconds_left}", size_enum: 7, alignment_enum: 1, r: 255, g: 255, b: 255 }
  end

  def render_choices(choices)
    return if choices.empty?
    
    start_y = 340
    choice_height = 40
    spacing = 10
    
    choices.each_with_index do |choice, index|
      y_pos = start_y - (index * (choice_height + spacing))
      
      # Choice background
      @outputs.solids << {
        x: 240, y: y_pos, w: 800, h: choice_height, 
        r: 60, g: 60, b: 80
      }
      
      # Choice text (prefixed with selection number)
      @outputs.labels << {
        x: 640, y: y_pos + choice_height / 2 + 5, text: "#{index + 1}. #{choice.text}", 
        size_enum: 2, alignment_enum: 1, r: 255, g: 255, b: 255
      }
    end
  end

  def render_scene_progress
    return unless @game_state.scene && @game_state.scene.states
    
    states = @game_state.scene.states
    current_time = @game_state.timing[:current_time]
    
    @outputs.labels << {
      x: 50, y: 700, text: "States:", 
      size_enum: 1, r: 255, g: 255, b: 255
    }
    
    states.each_with_index do |state, index|
      y_pos = 680 - (index * 20)
      state_text = "#{state.id}: #{state.at}s-#{state.at + state.duration}s"
      
      # Highlight active state
      current_time_seconds = current_time / 60.0  # Convert fr ames to seconds
      is_active = state.at <= current_time_seconds && current_time_seconds <= (state.at + state.duration)
      color = is_active ? [255, 255, 0] : [200, 200, 200]
      
      @outputs.labels << {
        x: 50, y: y_pos, text: state_text, 
        size_enum: 1, r: color[0], g: color[1], b: color[2]
      }
    end
  end

  def render_selected_choice_overlay
    text = @game_state.selected_choice_text
    return if text.nil? || text.empty?

    box_x = 20
    box_y = 660
    box_w = 500
    box_h = 50

    # Background box
    @outputs.solids << { x: box_x, y: box_y, w: box_w, h: box_h, r: 30, g: 30, b: 30, a: 180 }

    # Label
    @outputs.labels << {
      x: box_x + 10, y: box_y + 30, text: "Choice: #{text}",
      size_enum: 1, alignment_enum: 0, r: 255, g: 255, b: 255
    }
  end

  def wrap_text(text, x, y, max_width, size_enum)
    words = text.split(' ')
    lines = []
    current_line = []
    
    words.each do |word|
      test_line = current_line + [word]
      test_text = test_line.join(' ')
      
      # Rough character width estimation (adjust as needed)
      char_width = size_enum * 8
      if test_text.length * char_width > max_width && !current_line.empty?
        lines << current_line.join(' ')
        current_line = [word]
      else
        current_line << word
      end
    end
    
    lines << current_line.join(' ') unless current_line.empty?
    
    lines.each_with_index do |line, index|
      @outputs.labels << {
        x: x, y: y - (index * 30), text: line, 
        size_enum: size_enum, alignment_enum: 1, r: 255, g: 255, b: 255
      }
    end
  end
end
