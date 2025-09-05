# app/main.rb
# LLM-Driven Dynamic Story Generation (DragonRuby)
# run: dragonruby mygame
require_relative 'prompts'
require_relative 'client'

KFONT = "NotoSerifKR-VariableFont_wght.ttf"

def tick args
  init args

  check_frozen args

  unless args.state.frozen
    handle_input args
    update args
  end
  render args
end

def check_frozen args
  # toggle freeze with P key (freeze time but keep rendering current frame)
  if args.inputs.keyboard.key_down.p
    s = args.state
    s.frozen = !s.frozen
    if s.frozen
      # Calculate frozen timestamp based on current render state
      case s.render_state
      when :choice_phase
        s.frozen_t_ms = s.scene_started_at ? ((args.tick_count * (1000.0 / 60)).to_i - s.scene_started_at) : 0
      when :situation_explanation
        s.frozen_t_ms = s.situation_explanation_started_at ? ((args.tick_count * (1000.0 / 60)).to_i - s.situation_explanation_started_at) : 0
      when :dice_result
        s.frozen_t_ms = s.dice_result_started_at ? ((args.tick_count * (1000.0 / 60)).to_i - s.dice_result_started_at) : 0
      when :golden_dice
        s.frozen_t_ms = s.golden_dice_started_at ? ((args.tick_count * (1000.0 / 60)).to_i - s.golden_dice_started_at) : 0
      else
        s.frozen_t_ms = 0
      end
      args.gtk.log "Frozen at #{s.frozen_t_ms}ms"
    else
      # resume timeline continuity from where it was frozen
      case s.render_state
      when :choice_phase
        s.scene_started_at = (args.tick_count * (1000.0 / 60)).to_i - s.frozen_t_ms if s.scene_started_at
      when :situation_explanation
        s.situation_explanation_started_at = (args.tick_count * (1000.0 / 60)).to_i - s.frozen_t_ms if s.situation_explanation_started_at
      when :dice_result
        s.dice_result_started_at = (args.tick_count * (1000.0 / 60)).to_i - s.frozen_t_ms if s.dice_result_started_at
      when :golden_dice
        s.golden_dice_started_at = (args.tick_count * (1000.0 / 60)).to_i - s.frozen_t_ms if s.golden_dice_started_at
      end
      args.gtk.log "Unfrozen"
    end
  end

  if args.inputs.keyboard.key_down.s
    args.state.show_probability = !args.state.show_probability
    args.gtk.log "Show probability: #{args.state.show_probability}"
  end
  
  # Reset failed states with R key
  if args.inputs.keyboard.key_down.r
    s = args.state
    s.scene_generation_state = :not_started
    s.success_criteria_state = :not_started
    s.outcome_generation_state = :not_started
    s.new_situation_state = :not_started
    s.result_evaluation_state = :not_started
    push_log(args, "실패한 상태들을 리셋했습니다 (R 키)")
  end
end

# render_pause_screen function removed - no longer needed

# ------------------------------------------------------------------------------
# Initialization
# ------------------------------------------------------------------------------

def init args
  s = args.state
  
  # Initialize game state
  s.frozen ||= false
  s.frozen_t_ms ||= 0
  s.show_probability ||= false
  s.logs ||= []
  s.render_state ||= :situation_explanation # Default state
  s.situation_explanation_started_at ||= nil
  s.golden_dice_started_at ||= nil
  s.llm_client ||= LLMClient.new
  
  # Initialize player and NPC with starting memories
  s.player ||= Player.new("Player", 20, "Male", "Human", Stats.new(11, 12, 13), 
                          [Trait.new("Surprise Attack", "Lives by the principle of first strike wins", :weak), 
                           Trait.new("Ambition", "Can sacrifice anything to achieve their goals", :strong)], 
                          [Item.new("Sword", "A legendary sword. It looks ordinary but under certain conditions..."), 
                           Item.new("Cloth Armor", "Light armor made of cloth."), 
                           Item.new("Money Pouch", "Contains quite valuable gold coins"), 
                           Item.new("Healing Potion", "Can heal minor wounds")], 
                          starting_player_memory())
  
  s.npc ||= NPC.new("Guard", 33, "Male", "Human", guard_npc_description(), starting_guard_npc_memory())
  
  # Initialize game flow state
  s.current_situation ||= initial_situation_prompt()
  s.current_scene ||= nil
  s.available_choices ||= []
  s.scene_generation_state ||= :not_started
  s.success_criteria_state ||= :not_started
  s.outcome_generation_state ||= :not_started
  s.new_situation_state ||= :not_started
  s.result_evaluation_state ||= :not_started
  
  # Initialize scene timing
  s.scene_started_at ||= nil
  s.choice_made_at ||= nil
  s.dice_result_started_at ||= nil
  
  # Initialize choice timing system
  s.visible_choice_ids ||= []
  s.last_visible_choice_ids ||= []
  
  # Initialize dice system state
  s.success_criteria ||= nil
  s.dice_result ||= nil
  s.last_outcome ||= nil
end

def now_ms(args)
  # Always return the current time based on tick count
  (args.tick_count * (1000.0 / 60)).to_i
end

def get_current_time(args)
  s = args.state
  if s.frozen && s.frozen_t_ms
    # When frozen, return the frozen timestamp
    s.frozen_t_ms
  else
    # Normal time calculation - use raw tick count to avoid recursion
    (args.tick_count * (1000.0 / 60)).to_i
  end
end

def push_log args, msg
  args.state.logs.unshift msg
  args.state.logs = args.state.logs.take(8)
end

# ------------------------------------------------------------------------------
# Input Handling
# ------------------------------------------------------------------------------

def handle_input args
  s = args.state
  
  # Handle spacebar for state transitions
  if args.inputs.keyboard.key_down.space
    case s.render_state
    when :situation_explanation
      # Spacebar from situation explanation to scene generation
      s.scene_generation_state = :requested
      push_log args, "장면 생성 요청 (스페이스 키)"
      return
      
    when :golden_dice
      # Spacebar from golden dice result to next situation
      s.new_situation_state = :requested
      push_log args, "새로운 상황 생성 요청 (스페이스 키)"
      return
    end
  end
  
  # Handle choice selection during choice phase
  return unless s.render_state == :choice_phase
  return unless s.visible_choice_ids && !s.visible_choice_ids.empty?
  
  # Map keys 1/2/3 to first three visible choices
  keys = args.inputs.keyboard
  index =
    if keys.key_down.one   then 0
    elsif keys.key_down.two then 1
    elsif keys.key_down.three then 2
    else nil
    end
  
  return if index.nil?
  return if index >= s.visible_choice_ids.length
  
  # Apply the selected choice from visible choices
  choice_index = s.visible_choice_ids[index]
  first_state = s.current_scene[:states].first
  selected_choice = first_state["choices"][choice_index]
  apply_choice args, selected_choice
end

def apply_choice args, choice
  s = args.state
  
  # Store the choice for success criteria determination
  s.last_choice = choice["text"]
  s.choice_made_at = now_ms(args)
  
  # Request success criteria from LLM
  s.success_criteria_state = :requested
  
  push_log args, "선택: #{choice["text"]} - 성공 기준 결정 중..."
end

def handle_success_criteria(args)
  s = args.state
  s.success_criteria_state = :in_progress  # Mark as in progress
  
  # Generate success criteria using LLM
  prompt = success_criteria_prompt(s.last_choice, s.current_situation, s.player, s.npc)
  s.llm_client.send_request(args, prompt)
end

def handle_success_criteria_response(args, response)
  s = args.state
  
  begin
    criteria_data = args.gtk.parse_json(response)
    
    # Store success criteria
    s.success_criteria = {
      threshold: criteria_data["success_threshold"],
      difficulty: criteria_data["difficulty_level"],
      reasoning: criteria_data["reasoning"],
      factors: criteria_data["factors_considered"]
    }
    
    # Roll the 20-sided die
    dice_roll = roll_d20()
    is_success = dice_roll >= s.success_criteria[:threshold]
    
    # Store dice result
    s.dice_result = {
      roll: dice_roll,
      threshold: s.success_criteria[:threshold],
      success: is_success,
      choice: s.last_choice
    }
    
    # Move to dice result phase
    s.render_state = :dice_result
    s.dice_result_started_at = now_ms(args)
    s.success_criteria_state = :completed  # Mark as completed
    
    push_log(args, "주사위 결과: #{dice_roll}/#{s.success_criteria[:threshold]} → #{is_success ? '성공' : '실패'}")
    
    # Request outcome generation based on success/failure
    s.outcome_generation_state = :requested
    
    rescue => e
    push_log(args, "성공 기준 결정 실패: #{e.message}")
    s.success_criteria_state = :failed
  end
end

def roll_d20()
  # Roll a 20-sided die (1-20)
  rand(1..20)
end

def handle_outcome_generation(args)
  s = args.state
  s.outcome_generation_state = :in_progress  # Mark as in progress
  
  # Generate outcome based on dice result using LLM
  prompt = outcome_prompt(s.dice_result, s.current_situation, s.player, s.npc)
  s.llm_client.send_request(args, prompt)
end

def handle_outcome_generation_response(args, response)
  s = args.state
  
  begin
    outcome_data = args.gtk.parse_json(response)
    
    # Store outcome for display
    s.last_outcome = {
      description: outcome_data["outcome_description"],
      consequences: outcome_data["consequences"],
      atmosphere_change: outcome_data["atmosphere_change"]
    }
    
    # Update player and NPC memories
    s.player.memory += "\n" + outcome_data["player_memory_update"] unless outcome_data["player_memory_update"].empty?
    s.npc.memory += "\n" + outcome_data["npc_memory_update"] unless outcome_data["npc_memory_update"].empty?
    
    # Request new situation generation
    s.new_situation_state = :requested
    
    push_log(args, "결과 생성 완료: #{outcome_data["outcome_description"]}")
    
  rescue => e
    push_log(args, "결과 생성 응답 파싱 실패: #{e.message}")
    s.outcome_generation_state = :failed
  end
end

# ------------------------------------------------------------------------------
# LLM Workflow Management
# ------------------------------------------------------------------------------

def update args
  s = args.state
  
  # Check for LLM responses first
  if s.llm_result && s.llm_result[:complete]
    response = s.llm_client.handle_response(args)
    puts "HELLO"
    puts "Scene state: #{s.scene_generation_state}"
    puts "Success criteria state: #{s.success_criteria_state}"
    puts "Outcome state: #{s.outcome_generation_state}"
    puts "New situation state: #{s.new_situation_state}"
    puts "Result evaluation state: #{s.result_evaluation_state}"
    if response
      # Route response based on what was requested
      if s.scene_generation_state == :in_progress
        puts "Scene parsing"
        handle_scene_generation_response(args, response)
      elsif s.success_criteria_state == :in_progress
        handle_success_criteria_response(args, response)
      elsif s.outcome_generation_state == :in_progress
        handle_outcome_generation_response(args, response)
      elsif s.new_situation_state == :in_progress
        handle_new_situation_response(args, response)
      elsif s.result_evaluation_state == :in_progress
        handle_result_evaluation_response(args, response)
      end
    end
  end
  
  # Handle LLM workflow requests
  handle_scene_generation(args) if s.scene_generation_state == :requested
  handle_success_criteria(args) if s.success_criteria_state == :requested
  handle_outcome_generation(args) if s.outcome_generation_state == :requested
  handle_new_situation_generation(args) if s.new_situation_state == :requested
  handle_result_evaluation(args) if s.result_evaluation_state == :requested
  
  # Handle failed states - just log and move on
  if s.scene_generation_state == :failed
    push_log(args, "장면 생성 실패 - 다음 시도로 넘어갑니다")
    s.scene_generation_state = :not_started
  end
  
  if s.success_criteria_state == :failed
    push_log(args, "성공 기준 결정 실패 - 다음 시도로 넘어갑니다")
    s.success_criteria_state = :not_started
  end
  
  if s.outcome_generation_state == :failed
    push_log(args, "결과 생성 실패 - 다음 시도로 넘어갑니다")
    s.outcome_generation_state = :not_started
  end
  
  if s.new_situation_state == :failed
    push_log(args, "새로운 상황 생성 실패 - 다음 시도로 넘어갑니다")
    s.new_situation_state = :not_started
  end
  
  if s.result_evaluation_state == :failed
    push_log(args, "결과 평가 실패 - 다음 시도로 넘어갑니다")
    s.result_evaluation_state = :not_started
  end
  
  # Update scene timing
  if s.scene_started_at && s.render_state == :choice_phase
    current_time = get_current_time(args) - s.scene_started_at
    
    # Time-based choice management - choices appear and disappear dynamically
    if s.current_scene && s.current_scene[:states]
      first_state = s.current_scene[:states].first
      if first_state && first_state["choices"]
        # Update visible choices based on current time
        s.visible_choice_ids = first_state["choices"].each_with_index.select do |choice, index|
          # Check if choice is within its time window
          choice_start = choice["start_time"] || 0
          choice_end = choice["end_time"] || s.current_scene[:duration]
          current_time_sec = current_time / 1000.0
          
          current_time_sec >= choice_start && current_time_sec <= choice_end
        end.map(&:last)  # Get the indices
        
        # Log when choices appear/disappear
        if s.visible_choice_ids != s.last_visible_choice_ids
          if s.visible_choice_ids.length > (s.last_visible_choice_ids || []).length
            # New choices appeared
            new_choices = s.visible_choice_ids - (s.last_visible_choice_ids || [])
            new_choices.each do |index|
              choice = first_state["choices"][index]
              push_log args, "새로운 선택지 등장: #{choice['text']}"
            end
          elsif s.visible_choice_ids.length < (s.last_visible_choice_ids || []).length
            # Choices disappeared
            disappeared_choices = (s.last_visible_choice_ids || []) - s.visible_choice_ids
            disappeared_choices.each do |index|
              choice = first_state["choices"][index]
              push_log args, "선택지 사라짐: #{choice['text']} (시간 만료)"
            end
          end
          s.last_visible_choice_ids = s.visible_choice_ids.dup
        end
        
        # Auto-advance if no choices are available and time limit reached
        if s.visible_choice_ids.empty? && current_time >= (s.current_scene[:duration] * 1000)
          push_log args, "시간 초과 - 자동으로 다음으로 진행합니다"
          # Handle timeout as a "no choice made" scenario
          s.render_state = :situation_explanation
          s.scene_started_at = nil
          s.current_scene = nil
          s.visible_choice_ids = []
          s.last_visible_choice_ids = []
          s.new_situation_state = :not_started  # Reset to prevent infinite loop
          s.success_criteria_state = :not_started  # Reset to prevent infinite loop
        end
      end
    end
  end
end

def handle_scene_generation(args)
  s = args.state
  s.scene_generation_state = :in_progress  # Mark as in progress
  
  # Generate scene using LLM
  scene_prompt_text = scene_generation_prompt()
  situation_prompt_text = situation_prompt(s.current_situation, s.player, s.npc)
  prompt = situation_prompt_text + "\n" + scene_prompt_text
  s.llm_client.send_request(args, prompt)
end

def handle_result_evaluation(args)
  s = args.state
  s.result_evaluation_state = :in_progress  # Mark as in progress
  
  # Evaluate choice result using LLM
  prompt = result_evaluation_prompt(s.last_choice, s.current_situation, s.player, s.npc)
  s.llm_client.send_request(args, prompt)
end

def handle_new_situation_generation(args)
  s = args.state
  s.new_situation_state = :in_progress  # Mark as in progress
  
  # Generate new situation using LLM
  prompt = situation_prompt(s.current_situation, s.player, s.npc)
  s.llm_client.send_request(args, prompt)
end

def handle_llm_response(args, response, response_type)
  s = args.state
  
  case response_type
  when :scene_generation
    handle_scene_generation_response(args, response)
  when :result_evaluation
    handle_result_evaluation_response(args, response)
  when :new_situation
    handle_new_situation_response(args, response)
  when :success_criteria
    handle_success_criteria_response(args, response)
  when :outcome_generation
    handle_outcome_generation_response(args, response)
  end
end

def handle_scene_generation_response(args, response)
  s = args.state
  
  begin
    puts "Response: #{response}"
    puts "Response class: #{response.class}"
    puts "Response encoding: #{response.respond_to?(:encoding) ? response.encoding : 'unknown'}"
    
    # Try to clean the response if it has escape characters
    cleaned_response = response.gsub('\\n', "\n").gsub('\\"', '"')
    puts "Cleaned response: #{cleaned_response}"
    
    scene_data = args.gtk.parse_json(cleaned_response)
    puts "Scene data: #{scene_data}"
    puts "Scene data class: #{scene_data.class}"
    
    # If parse_json returns nil, try manual parsing
    if scene_data.nil?
      puts "parse_json returned nil, trying manual parsing..."
      # Simple manual JSON parsing for the key fields we need
      if cleaned_response.include?('"id"') && cleaned_response.include?('"states"')
        # Extract ID using string manipulation
        id_start = cleaned_response.index('"id"') + 5
        id_end = cleaned_response.index('"', id_start + 1)
        id = cleaned_response[id_start + 1...id_end]
        
        # Extract states array (simplified)
        states_start = cleaned_response.index('"states"') + 9
        states_end = cleaned_response.rindex(']') + 1
        states_text = cleaned_response[states_start...states_end]
        
        puts "Manually parsed ID: #{id}"
        puts "Manually parsed states: #{states_text}"
        
        # Create a basic scene structure
        scene_data = {
          "id" => id,
          "duration" => 12,
          "states" => [{"choices" => []}]
        }
      else
        puts "Response doesn't contain required fields"
        s.scene_generation_state = :failed
        return
      end
    end
    
    # Update current scene - match the actual LLM response structure
    s.current_scene = {
      id: scene_data["id"],
      duration: scene_data["duration"],
      states: scene_data["states"]
    }
    
    puts "Scene ID: #{scene_data["id"]}"
    puts "Duration: #{scene_data["duration"]}"
    puts "States: #{scene_data["states"].length} states"
    
    # Extract available choices from first state
    first_state = scene_data["states"].first
    s.available_choices = first_state["choices"]
    
    puts "Available choices: #{s.available_choices.length} choices"
    
    # Move to choice phase
    s.render_state = :choice_phase
    s.scene_started_at = now_ms(args)
    s.scene_generation_state = :completed  # Mark as completed
    
    push_log(args, "장면 생성 완료: #{scene_data["id"]}")
    
  rescue => e
    puts "장면 생성 응답 parsing error: #{e.message}"
    s.scene_generation_state = :failed
  end
end

def handle_result_evaluation_response(args, response)
  s = args.state
  
  begin
    result_data = args.gtk.parse_json(response)
    
    # Update player and NPC memories
    s.player.memory += "\n" + result_data["player_memory_update"] unless result_data["player_memory_update"].empty?
    s.npc.memory += "\n" + result_data["npc_memory_update"] unless result_data["npc_memory_update"].empty?
    
    # Store result for display
    s.last_result = {
      description: result_data["result_description"],
      consequences: result_data["consequences"],
      atmosphere_change: result_data["atmosphere_change"]
    }
    
    # Request new situation generation
    s.new_situation_state = :requested
    
    push_log(args, "결과 평가 완료: #{result_data["result_description"]}")
    
  rescue => e
    push_log(args, "결과 평가 응답 파싱 실패: #{e.message}")
    s.result_evaluation_state = :failed
  end
end

def handle_new_situation_response(args, response)
  s = args.state
  
  begin
    situation_data = args.gtk.parse_json(response)
    
    # Update current situation
    s.current_situation = situation_data["narration"] || situation_data["description"] || response
    
    # Move to situation explanation phase
    s.render_state = :situation_explanation
    s.situation_explanation_started_at = now_ms(args)
    s.new_situation_state = :completed  # Mark as completed
    
    push_log(args, "새로운 상황 생성 완료")
    
  rescue => e
    push_log(args, "새로운 상황 생성 응답 파싱 실패: #{e.message}")
    s.new_situation_state = :failed
  end
end

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

def wrap_text(text, max_width_chars = 80)
  # Simple text wrapping - break at word boundaries
  words = text.split(' ')
  lines = []
  current_line = ""
  
  words.each do |word|
    if (current_line + word).length <= max_width_chars
      current_line += (current_line.empty? ? "" : " ") + word
    else
      lines << current_line unless current_line.empty?
      current_line = word
    end
  end
  
  lines << current_line unless current_line.empty?
  lines
end

# ------------------------------------------------------------------------------
# Rendering Functions
# ------------------------------------------------------------------------------

def render args
  s = args.state
  
  # Always render the current state, even when frozen
  case s.render_state
  when :situation_explanation
    render_situation_explanation args
  when :choice_phase
    render_choice_phase args
  when :dice_result
    render_dice_result args
  when :golden_dice
    render_golden_dice_result args
  end
  
  # Render logs
  render_logs args
  
  # Add a subtle pause indicator when frozen (optional - can be removed if you don't want any visual cue)
  if s.frozen
    # Small pause indicator in top-right corner
    args.outputs.labels << { x: 1200, y: 690, text: "⏸ 일시정지",
                             size_enum: 2, alignment_enum: 2, r: 255, g: 255, b: 100, font: KFONT }
  end
end

def render_situation_explanation args
  s = args.state
  w = 1280; h = 720
  
  # Background
  args.outputs.solids << [0, 0, w, h, 12, 16, 24]
  
  # Big situation text box
  box_x = 100; box_y = 200; box_w = 1080; box_h = 320
  args.outputs.solids << [box_x, box_y, box_w, box_h, 25, 35, 55]
  args.outputs.borders << [box_x, box_y, box_w, box_h, 120, 140, 180]
  
  # Situation text - split into multiple lines
  situation_text = s.current_situation || "상황을 불러오는 중..."
  
  # Split text into lines and render each line
  # First split by explicit newlines, then wrap long lines
  explicit_lines = situation_text.split("\n")
  all_lines = []
  
  explicit_lines.each do |line|
    if line.strip.empty?
      all_lines << ""
    else
      # Wrap long lines to fit in the box (approximately 70 characters per line for larger box)
      wrapped_lines = wrap_text(line.strip, 70)
      all_lines.concat(wrapped_lines)
    end
  end
  
  line_height = 30
  start_y = box_y + box_h - 40  # Start from top of box
  
  all_lines.each_with_index do |line, index|
    y_pos = start_y - (index * line_height)
    break if y_pos < box_y + 40  # Stop if we run out of box space
    
    if line.empty?
      # Skip rendering empty lines but still count them for spacing
      next
    end
    
    args.outputs.labels << { x: box_x + 20, y: y_pos, text: line,
                             size_enum: 2, alignment_enum: 0, r: 230, g: 240, b: 255, font: KFONT }
  end
  
  # Footer
  args.outputs.labels << { x: 40, y: 50, text: "스페이스 키로 장면 생성",
                           size_enum: 2, alignment_enum: 0, r: 180, g: 190, b: 210, font: KFONT }
end

def render_choice_phase args 
  s = args.state
  w = 1280; h = 720
  
  args.outputs.solids << [0, 0, w, h, 12, 16, 24]
  
  unless s.current_scene && s.available_choices
    args.outputs.labels << { x: 40, y: 680, text: "장면을 불러오는 중...",
                             size_enum: 6, alignment_enum: 0, r: 230, g: 240, b: 255, font: KFONT }
    return
  end
  
  # Calculate current time and remaining time
  current_time = s.scene_started_at ? (get_current_time(args) - s.scene_started_at) : 0
  scene_duration = s.current_scene[:duration] * 1000  # Convert to milliseconds
  remaining_time = [(scene_duration - current_time) / 1000.0, 0].max
  
  # --- Real-time countdown timer ---
  countdown_text = "남은 시간: #{remaining_time.round(1)}초"
  countdown_color = remaining_time < 3 ? [255, 150, 150] : [150, 255, 150]  # Red when < 3s, green otherwise
  
  # Add a pulsing indicator that time is running
  pulse_alpha = (Math.sin(now_ms(args) / 200.0) * 50 + 200).to_i
  args.outputs.labels << { x: 40, y: 690, text: countdown_text,
                           size_enum: 6, alignment_enum: 0, r: countdown_color[0], g: countdown_color[1], b: countdown_color[2], font: KFONT }
  
  # Show "시간 진행 중..." indicator
  args.outputs.labels << { x: 300, y: 690, text: "⏰ 시간 진행 중...",
                           size_enum: 4, alignment_enum: 0, r: pulse_alpha, g: 255, b: 255, font: KFONT }
  
  # --- Timeline bar ---
  bar_x = 40; bar_y = 540; bar_w = 1200; bar_h = 14
  fill_w = (current_time / scene_duration.to_f) * bar_w
  args.outputs.solids  << [bar_x, bar_y, bar_w, bar_h, 25, 35, 55]
  args.outputs.solids  << [bar_x, bar_y, fill_w, bar_h, 255, 140, 90]
  args.outputs.borders << [bar_x, bar_y, bar_w, bar_h, 120, 140, 180]
  
  # Add current time indicator (moving dot)
  current_time_x = bar_x + (current_time / scene_duration.to_f) * bar_w
  args.outputs.solids << [current_time_x-3, bar_y-5, 6, bar_h+10, 255, 255, 100]  # Yellow moving indicator
  
  # Scene description - split into multiple lines
  box_x = 100; box_y = 400; box_w = 1080; box_h = 120
  args.outputs.solids << [box_x, box_y, box_w, box_h, 25, 35, 55]
  args.outputs.borders << [box_x, box_y, box_w, box_h, 120, 140, 180]
  
  # Get scene text from the first state
  first_state = s.current_scene[:states].first
  scene_text = first_state["text"] || "장면 설명"
  
  # Split text into lines and render each line
  # First split by explicit newlines, then wrap long lines
  explicit_lines = scene_text.split("\n")
  all_lines = []
  
  explicit_lines.each do |line|
    if line.strip.empty?
      all_lines << ""
    else
      # Wrap long lines to fit in the box (approximately 60 characters per line)
      wrapped_lines = wrap_text(line.strip, 60)
      all_lines.concat(wrapped_lines)
    end
  end
  
  line_height = 25
  start_y = box_y + box_h - 20
  
  all_lines.each_with_index do |line, index|
    y_pos = start_y - (index * line_height)
    break if y_pos < box_y + 20  # Stop if we run out of box space
    
    if line.empty?
      # Skip rendering empty lines but still count them for spacing
      next
    end
    
    args.outputs.labels << { x: box_x + 20, y: y_pos, text: line,
                             size_enum: 2, alignment_enum: 0, r: 230, g: 240, b: 255, font: KFONT }
  end
  
  # Choices with timing information
  choice_y = 350
  visible_choices = s.visible_choice_ids || []
  
  if visible_choices.empty?
    args.outputs.labels << { x: 120, y: choice_y, text: "사용 가능한 선택지가 없습니다...",
                             size_enum: 2, alignment_enum: 0, r: 255, g: 150, b: 150, font: KFONT }
  else
    visible_choices.each_with_index do |choice_index, display_index|
      next if display_index >= 3  # Show only first 3 visible choices
      
      choice = first_state["choices"][choice_index]
      choice_text = "#{display_index + 1}. #{choice['text']}"
      
      # Calculate remaining time for this choice
      choice_start = choice["start_time"] || 0
      choice_end = choice["end_time"] || s.current_scene[:duration]
      choice_remaining = choice_end - (current_time / 1000.0)
      choice_remaining = [choice_remaining, 0].max
      
      # Choice text
      args.outputs.labels << { x: 120, y: choice_y, text: choice_text,
                               size_enum: 2, alignment_enum: 0, r: 255, g: 255, b: 200, font: KFONT }
      
      # Timing information
      timing_text = "#{choice_start}s ~ #{choice_end}s (남은 시간: #{choice_remaining.round(1)}초)"
      timing_color = choice_remaining < 2 ? [255, 200, 200] : [180, 200, 230]
      args.outputs.labels << { x: 120, y: choice_y - 20, text: timing_text,
                               size_enum: 1, alignment_enum: 0, r: timing_color[0], g: timing_color[1], b: timing_color[2], font: KFONT }
      
      # Warning indicator for expiring choices
      if choice_remaining < 2
        args.outputs.labels << { x: 120, y: choice_y - 35, text: "⚠️ 곧 사라집니다!",
                                 size_enum: 1, alignment_enum: 0, r: 255, g: 100, b: 100, font: KFONT }
      end
      
      choice_y -= 60  # More space for timing info
    end
  end
  
  # Time is running indicator
  args.outputs.labels << { x: 40, y: 320, text: "⏱️ 시간이 계속 진행되고 있습니다! 선택지를 놓치지 마세요!",
                           size_enum: 2, alignment_enum: 0, r: 255, g: 220, b: 150, font: KFONT }
  
  # Footer
  args.outputs.labels << { x: 40, y: 50, text: "1, 2, 3 키로 선택 | P로 일시정지 | R로 리셋",
                           size_enum: 2, alignment_enum: 0, r: 180, g: 190, b: 210, font: KFONT }
end

def render_golden_dice_result args
  s = args.state
  w = 1280; h = 720
  
  args.outputs.solids << [0, 0, w, h, 12, 16, 24]
  
  # Big result box
  box_x = 100; box_y = 200; box_w = 1080; box_h = 320
  args.outputs.solids << [box_x, box_y, box_w, box_h, 25, 35, 55]
  args.outputs.borders << [box_x, box_y, box_w, box_h, 120, 140, 180]
  
  if s.last_result
    # Result description
    result_text = s.last_result[:description] || "결과를 평가하는 중..."
    args.outputs.labels << { x: box_x + box_w/2, y: box_y + box_h/2 + 40, text: result_text,
                             size_enum: 3, alignment_enum: 1, r: 230, g: 240, b: 255, font: KFONT }
    
    # Consequences
    if s.last_result[:consequences]
      immediate = s.last_result[:consequences]["immediate"] || ""
      long_term = s.last_result[:consequences]["long_term"] || ""
      
      args.outputs.labels << { x: box_x + box_w/2, y: box_y + box_h/2 - 20, text: "즉시 결과: #{immediate}",
                               size_enum: 2, alignment_enum: 1, r: 200, g: 220, b: 240, font: KFONT }
      
      args.outputs.labels << { x: box_x + box_w/2, y: box_y + box_h/2 - 50, text: "장기적 영향: #{long_term}",
                               size_enum: 2, alignment_enum: 1, r: 200, g: 220, b: 240, font: KFONT }
    end
  else
    args.outputs.labels << { x: box_x + box_w/2, y: box_y + box_h/2, text: "결과를 평가하는 중...",
                             size_enum: 3, alignment_enum: 1, r: 200, g: 220, b: 240, font: KFONT }
  end
  
  # Footer
  args.outputs.labels << { x: 40, y: 50, text: "스페이스 키로 다음 상황으로 이동",
                           size_enum: 2, alignment_enum: 0, r: 180, g: 190, b: 210, font: KFONT }
end

def render_dice_result args
  s = args.state
  w = 1280; h = 720
  
  args.outputs.solids << [0, 0, w, h, 12, 16, 24]
  
  unless s.dice_result && s.success_criteria
    args.outputs.labels << { x: 40, y: 680, text: "주사위 결과를 불러오는 중...",
                             size_enum: 6, alignment_enum: 0, r: 230, g: 240, b: 255, font: KFONT }
    return
  end
  
  # Big dice result box
  box_x = 100; box_y = 200; box_w = 1080; box_h = 320
  args.outputs.solids << [box_x, box_y, box_w, box_h, 25, 35, 55]
  args.outputs.borders << [box_x, box_y, box_w, box_h, 120, 140, 180]
  
  # Dice roll result
  dice_text = "주사위: #{s.dice_result[:roll]}/20"
  threshold_text = "성공 기준: #{s.dice_result[:threshold]} 이상"
  result_text = s.dice_result[:success] ? "성공!" : "실패..."
  
  # Color based on success/failure
  result_color = s.dice_result[:success] ? [150, 255, 150] : [255, 150, 150]
  
  args.outputs.labels << { x: box_x + box_w/2, y: box_y + box_h/2 + 60, text: dice_text,
                           size_enum: 4, alignment_enum: 1, r: 230, g: 240, b: 255, font: KFONT }
  
  args.outputs.labels << { x: box_x + box_w/2, y: box_y + box_h/2 + 20, text: threshold_text,
                           size_enum: 3, alignment_enum: 1, r: 200, g: 220, b: 240, font: KFONT }
  
  args.outputs.labels << { x: box_x + box_w/2, y: box_y + box_h/2 - 20, text: result_text,
                           size_enum: 5, alignment_enum: 1, r: result_color[0], g: result_color[1], b: result_color[2], font: KFONT }
  
  # Difficulty and reasoning
  difficulty_text = "난이도: #{s.success_criteria[:difficulty]}"
  args.outputs.labels << { x: box_x + box_w/2, y: box_y + box_h/2 - 60, text: difficulty_text,
                           size_enum: 2, alignment_enum: 1, r: 180, g: 200, b: 220, font: KFONT }
  
  # Footer
  args.outputs.labels << { x: 40, y: 50, text: "결과 생성 중...",
                           size_enum: 2, alignment_enum: 0, r: 180, g: 190, b: 210, font: KFONT }
end

def render_logs args
  s = args.state
  return unless s.logs && !s.logs.empty?
  
  # Render logs at bottom
  lx = 40; ly = 120; lw = 1200; lh = 80
  args.outputs.solids << [lx, ly-lh, lw, lh, 15, 18, 26]
  args.outputs.borders << [lx, ly-lh, lw, lh, 90, 110, 140]
  
  s.logs.each_with_index do |ln, idx|
    args.outputs.labels << { x: lx+12, y: ly-16 - idx*18, text: ln,
                             size_enum: 2, alignment_enum: 0, r: 190, g: 200, b: 220, font: KFONT }
  end
end
