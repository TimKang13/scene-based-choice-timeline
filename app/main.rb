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
      s.frozen_t_ms = now_ms(args) - s.scene_started_at
      args.gtk.log "Frozen at #{s.frozen_t_ms}ms"
    else
      # resume timeline continuity from where it was frozen
      s.scene_started_at = now_ms(args) - s.frozen_t_ms
      args.gtk.log "Unfrozen"
    end
  end

  if args.inputs.keyboard.key_down.s
    args.state.show_probability = !args.state.show_probability
    args.gtk.log "Show probability: #{args.state.show_probability}"
  end
end

def render_pause_screen args
  w, h = 1280, 720
  args.outputs.solids << [0, 0, w, h, 0, 0, 0, 180]  # translucent overlay
  args.outputs.labels << [w/2, h/2, "⏸ 게임 일시정지 (P 키로 재개)", 5, 1, 255, 255, 255]
end

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
  s.player ||= Player.new("플레이어", 20, "남자", "인간", Stats.new(10, 10, 10), 
                          [Trait.new("기습", "선빵필승을 가슴에 새기며 살아간다", :weak), 
                           Trait.new("욕망", "목표를 달성하기 위해 얼마든지 희생할 수 있다", :strong)], 
                          [Item.new("칼", "전설로 내려온 칼이다. 평범한 칼처럼 보이지만, 조건을 충족한다면..."), 
                           Item.new("천갑옷", "천으로 된 가벼운 갑옷이다."), 
                           Item.new("돈주머니", "꽤 값이 비싼 금화가 들어있다"), 
                           Item.new("치유포션", "가벼운 상처를 치유할 수 있다")], 
                          starting_player_memory())
  
  s.npc ||= NPC.new("문지기", 33, "남자", "인간", guard_npc_description(), starting_guard_npc_memory())
  
  # Initialize game flow state
  s.current_situation ||= initial_situation_prompt()
  s.current_scene ||= nil
  s.available_choices ||= []
  s.scene_generation_requested ||= false
  s.success_criteria_requested ||= false
  s.outcome_generation_requested ||= false
  s.new_situation_requested ||= false
  
  # Initialize scene timing
  s.scene_started_at ||= nil
  s.choice_made_at ||= nil
  s.dice_result_started_at ||= nil
  
  # Initialize dice system state
  s.success_criteria ||= nil
  s.dice_result ||= nil
  s.last_outcome ||= nil
end

def now_ms(args) = (args.tick_count * (1000.0 / 60)).to_i

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
      s.scene_generation_requested = true
      push_log args, "장면 생성 요청 (스페이스 키)"
      return
      
    when :golden_dice
      # Spacebar from golden dice result to next situation
      s.new_situation_requested = true
      push_log args, "새로운 상황 생성 요청 (스페이스 키)"
      return
    end
  end
  
  # Handle choice selection during choice phase
  return unless s.render_state == :choice_phase
  return unless s.available_choices && !s.available_choices.empty?
  
  # Map keys 1/2/3 to first three choices
  keys = args.inputs.keyboard
  index =
    if keys.key_down.one   then 0
    elsif keys.key_down.two then 1
    elsif keys.key_down.three then 2
    else nil
    end
  
  return if index.nil?
  return if index >= s.available_choices.length
  
  # Apply the selected choice
  selected_choice = s.available_choices[index]
  apply_choice args, selected_choice
end

def apply_choice args, choice
  s = args.state
  
  # Store the choice for success criteria determination
  s.last_choice = choice["text"]
  s.choice_made_at = now_ms(args)
  
  # Request success criteria from LLM
  s.success_criteria_requested = true
  
  push_log args, "선택: #{choice["text"]} - 성공 기준 결정 중..."
end

def handle_success_criteria(args)
  s = args.state
  s.success_criteria_requested = false
  
  # Generate success criteria using LLM
  prompt = success_criteria_prompt(s.last_choice, s.current_situation, s.player, s.npc)
  s.llm_client.send_request(args, prompt)
end

def handle_success_criteria_response(args, response)
  s = args.state
  
  begin
    criteria_data = JSON.parse(response)
    
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
    
    push_log(args, "주사위 결과: #{dice_roll}/#{s.success_criteria[:threshold]} → #{is_success ? '성공' : '실패'}")
    
    # Request outcome generation based on success/failure
    s.outcome_generation_requested = true
    
  rescue JSON::ParserError => e
    push_log(args, "성공 기준 응답 파싱 실패: #{e.message}")
    s.success_criteria_requested = true  # Retry
  end
end

def roll_d20()
  # Roll a 20-sided die (1-20)
  rand(1..20)
end

def handle_outcome_generation(args)
  s = args.state
  s.outcome_generation_requested = false
  
  # Generate outcome based on dice result using LLM
  prompt = outcome_prompt(s.dice_result, s.current_situation, s.player, s.npc)
  s.llm_client.send_request(args, prompt)
end

def handle_outcome_generation_response(args, response)
  s = args.state
  
  begin
    outcome_data = JSON.parse(response)
    
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
    s.new_situation_requested = true
    
    push_log(args, "결과 생성 완료: #{outcome_data["outcome_description"]}")
    
  rescue JSON::ParserError => e
    push_log(args, "결과 생성 응답 파싱 실패: #{e.message}")
    s.outcome_generation_requested = true  # Retry
  end
end

# ------------------------------------------------------------------------------
# LLM Workflow Management
# ------------------------------------------------------------------------------

def update args
  s = args.state
  
  # Handle LLM workflow requests
  handle_scene_generation(args) if s.scene_generation_requested
  handle_success_criteria(args) if s.success_criteria_requested
  handle_outcome_generation(args) if s.outcome_generation_requested
  handle_new_situation_generation(args) if s.new_situation_requested
  
  # Update scene timing
  if s.scene_started_at && s.render_state == :choice_phase
    current_time = now_ms(args) - s.scene_started_at
    # Handle time-based choice expiration if needed
  end
end

def handle_scene_generation(args)
  s = args.state
  s.scene_generation_requested = false
  
  # Generate scene using LLM
  scene_prompt_text = scene_generation_prompt()
  situation_prompt_text = situation_prompt(s.current_situation, s.player, s.npc)
  prompt = situation_prompt_text + "\n" + scene_prompt_text
  s.llm_client.send_request(args, prompt)
end

def handle_result_evaluation(args)
  s = args.state
  s.result_evaluation_requested = false
  
  # Evaluate choice result using LLM
  prompt = result_evaluation_prompt(s.last_choice, s.current_situation, s.player, s.npc)
  s.llm_client.send_request(args, prompt)
end

def handle_new_situation_generation(args)
  s = args.state
  s.new_situation_requested = false
  
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
    scene_data = JSON.parse(response)
    
    # Update current scene
    s.current_scene = {
      description: scene_data["scene_description"],
      duration: scene_data["duration"],
      states: scene_data["states"]
    }
    
    # Extract available choices from first state
    first_state = scene_data["states"].first
    s.available_choices = first_state["choices"]
    
    # Move to choice phase
    s.render_state = :choice_phase
    s.scene_started_at = now_ms(args)
    s.scene_generation_requested = false
    
    push_log(args, "장면 생성 완료: #{scene_data["scene_description"]}")
    
  rescue JSON::ParserError => e
    push_log(args, "장면 생성 응답 파싱 실패: #{e.message}")
    s.scene_generation_requested = true  # Retry
  end
end

def handle_result_evaluation_response(args, response)
  s = args.state
  
  begin
    result_data = JSON.parse(response)
    
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
    s.new_situation_requested = true
    
    push_log(args, "결과 평가 완료: #{result_data["result_description"]}")
    
  rescue JSON::ParserError => e
    push_log(args, "결과 평가 응답 파싱 실패: #{e.message}")
    s.result_evaluation_requested = true  # Retry
  end
end

def handle_new_situation_response(args, response)
  s = args.state
  
  begin
    situation_data = JSON.parse(response)
    
    # Update current situation
    s.current_situation = situation_data["narration"] || situation_data["description"] || response
    
    # Move to situation explanation phase
    s.render_state = :situation_explanation
    s.situation_explanation_started_at = now_ms(args)
    s.new_situation_requested = false
    
    push_log(args, "새로운 상황 생성 완료")
    
  rescue JSON::ParserError => e
    push_log(args, "새로운 상황 생성 응답 파싱 실패: #{e.message}")
    s.new_situation_requested = true  # Retry
  end
end

# ------------------------------------------------------------------------------
# Rendering Functions
# ------------------------------------------------------------------------------

def render args
  s = args.state
  
  if s.frozen
    render_pause_screen args
    return
  end
  
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
  
  # Situation text
  situation_text = s.current_situation || "상황을 불러오는 중..."
  args.outputs.labels << { x: box_x + box_w/2, y: box_y + box_h/2, text: situation_text,
                           size_enum: 4, alignment_enum: 1, r: 230, g: 240, b: 255, font: KFONT }
  
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
  
  # Scene description
  box_x = 100; box_y = 400; box_w = 1080; box_h = 120
  args.outputs.solids << [box_x, box_y, box_w, box_h, 25, 35, 55]
  args.outputs.borders << [box_x, box_y, box_w, box_h, 120, 140, 180]
  
  scene_text = s.current_scene[:description] || "장면 설명"
  args.outputs.labels << { x: box_x + box_w/2, y: box_y + box_h/2, text: scene_text,
                           size_enum: 3, alignment_enum: 1, r: 230, g: 240, b: 255, font: KFONT }
  
  # Choices
  choice_y = 350
  s.available_choices.each_with_index do |choice, index|
    next if index >= 3  # Show only first 3 choices
    
    choice_text = "#{index + 1}. #{choice['text']}"
    args.outputs.labels << { x: 120, y: choice_y, text: choice_text,
                             size_enum: 2, alignment_enum: 0, r: 255, g: 255, b: 200, font: KFONT }
    choice_y -= 40
  end
  
  # Footer
  args.outputs.labels << { x: 40, y: 50, text: "1, 2, 3 키로 선택",
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
