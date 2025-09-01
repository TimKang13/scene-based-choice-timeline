# app/main.rb
# Scene Tree + Time-Gated Choices + Golden Dice (DragonRuby)
# run: dragonruby mygame

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
      s.frozen_t_ms = now_ms(args) - s.situation_started_at
      args.gtk.log "Frozen at #{s.frozen_t_ms}ms"
    else
      # resume timeline continuity from where it was frozen
      s.situation_started_at = now_ms(args) - s.frozen_t_ms
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
# Model (Tree)
# ------------------------------------------------------------------------------

def build_tree
  # --- Scene nodes (even heights) -------------------------------------------
  t_order_to_leave = 0
  t_final_warning = 3
  t_attack = 7
  t_end = 9

  t_first_response = 5

  s_start = {
    kind: :scene, id: :S_START, height: 0, time_limit: t_first_response,
    situations: [
      { at: 0, text: "문지기: \"허락 없는 자는 단 한 발자국도 들일 수 없다. 너는 누구이며, 무슨 까닭으로 성안에 들어오려 하는가?\"" },
    ],
    choices: [:C_MAKE_EXCUSE, :C_BRIBE, :C_HONEST, :C_NO_CHOICE]
  }

  s0 = {
    kind: :scene, id: :S0, height: 0, time_limit: t_end,
    situations: [
      { at: 0, text: "문지기가 창을 겨누며 말한다: \"돌아가라.\"" },
      { at: 3, text: "문지기: \"마지막 경고다! 지금 당장 물러나라!\"" },
      { at: 6, text: "문지기가 창으로 찌르며 공격을 개시한다! (대응 6~7s)" }
    ],
    choices: [:C_RETREAT, :C_PERSUADE, :C_SURPRISE_ATTACK, :C_DODGE, :C_COUNTER, :C_NO_CHOICE]
  }

  s1 = {
    kind: :scene, id: :S1, height: 2, time_limit: 7,
    situations: [
      { at: 0, text: "문지기는 여전히 적대적이다. 창끝이 더 가까워진다." },
      { at: 3, text: "문지기: \"말은 끝났다. 네가 정해라.\"" },
      { at: 6, text: "창이 돌진한다! (대응 6~7s)" }
    ],
    choices: [:C_SURPRISE_ATTACK, :C_ESCAPE, :C_NO_CHOICE]
  }

  s_success = {
    kind: :scene, id: :S_SUCCESS, height: 4, time_limit: 3,
    situations: [
      { at: 0, text: "성공! 길이 열렸다. 다음 장면으로 진행한다." }
    ],
    choices: [:C_END_OK]
  }

  s_fail = {
    kind: :scene, id: :S_FAIL, height: 4, time_limit: 3,
    situations: [
      { at: 0, text: "문지기의 창을 맞은 당신은 치명상을 입었다" }
    ],
    choices: [:C_END_BAD]
  }

  s_retreat = {
    kind: :scene, id: :S_RETREAT, height: 4, time_limit: 3,
    situations: [
      { at: 0, text: "당신은 물러난다. 안전하지만 잠입 난이도가 상승한다." }
    ],
    choices: [:C_END_OK]
  }

  s_excuse_success = {
    kind: :scene, id: :S_EXCUSE_SUCCESS, height: 4, time_limit: 3,
    situations: [
      { at: 0, text: "문지기: 흠… 요즘 식량이 부족하긴 하지… 들여보내주지" }
    ],
    choices: [:C_END_OK]
  }

  s_excuse_fail = {
    kind: :scene, id: :S_EXCUSE_FAIL, height: 4, time_limit: 3,
    situations: [
      { at: 0, text: "왜 바로 대답하지 못하는가? 상인? 이 시각에?" }
    ],
    choices: [:C_END_OK]
  }

  # --- Choice nodes (odd heights) -------------------------------------------
  c_make_excuse = {
    kind: :choice, id: :C_MAKE_EXCUSE, height: 1,
    choice: "상인이라고 대충 둘러댄다", birth: 0, death: t_first_response, 
    base_probability: 0.5,
    rt_factor: 1,
    success: :S_EXCUSE_SUCCESS, failure: :S0
  }

  c_bribe = {
    kind: :choice, id: :C_BRIBE, height: 1,
    choice: "이유는 상관없고, 뇌물을 준다", birth: 0, death: t_first_response, 
    base_probability: 0.7,
    rt_factor: 0.0,
    success: :S0, failure: :S0
  }

  c_honest = {
    kind: :choice, id: :C_HONEST, height: 1,
    choice: "솔직하게 털어놓는다. 설득해본다", birth: 0, death: t_first_response, 
    base_probability: 0.2,
    rt_factor: 0.0,
    success: :S0, failure: :S0
  }

  c_retreat = {
    kind: :choice, id: :C_RETREAT, height: 1,
    choice: "물러난다", birth: t_order_to_leave, death: t_attack-1, 
    base_probability: 1.0,
    rt_factor: 0.0,
    success: :S_RETREAT, failure: :S_RETREAT
  }

  c_persuade = {
    kind: :choice, id: :C_PERSUADE, height: 1,
    choice: "다시 설득 시도한다", birth: t_order_to_leave, death: t_final_warning, base_probability: 0.3, rt_factor: 0.2,
    success: :S_SUCCESS, failure: :S1
  }


  c_surprise_attack = {
    kind: :choice, id: :C_SURPRISE_ATTACK, height: 1,
    choice: "가지고 있는 칼을 뽑아 기습공격한다", birth: t_final_warning, death: t_attack, base_probability: 0.7, rt_factor: 0.1,
    success: :S_SUCCESS, failure: :S_FAIL
  }

  c_dodge = {
    kind: :choice, id: :C_DODGE, height: 1,
    choice: "물러나서 회피한다", birth: t_attack, death: t_end, base_probability: 0.9, rt_factor: 0.5,
    success: :S_SUCCESS, failure: :S_FAIL
  }

  c_counter = {
    kind: :choice, id: :C_COUNTER, height: 1,
    choice: "창을 막아 반격한다", birth: t_attack, death: t_end, base_probability: 0.6, rt_factor: 0.5,
    success: :S_SUCCESS, failure: :S_FAIL
  }

  c_no_choice = {
    kind: :choice, id: :C_NO_CHOICE, height: 1,
    choice: "(침묵) 선택하지 못했다", birth: t_end, death: t_end, base_probability: 0.0, rt_factor: 0.0,
    success: :S_FAIL, failure: :S_FAIL
  }




  c_escape = {
    kind: :choice, id: :C_ESCAPE, height: 3,
    choice: "돌아서는 척하며 도주 (3~7s)", birth: 3, death: 7, base_probability: 0.8, rt_factor: 1.0,
    success: :S_SUCCESS, failure: :S_FAIL
  }

  c_end_ok = {
    kind: :choice, id: :C_END_OK, height: 5,
    choice: "성공!", birth: 0, death: 3, base_probability: 1.0, rt_factor: 1.0,
    success: :S_START, failure: :S_START
  }

  c_end_bad = {
    kind: :choice, id: :C_END_BAD, height: 5,
    choice: "실패!", birth: 0, death: 3, base_probability: 1.0, rt_factor: 1.0,
    success: :S_START, failure: :S_START
  }

  # --- Pack into a hash for O(1) lookup -------------------------------------
  nodes = {}
  [s_start, s0, s1, s_success, s_fail, s_retreat, s_excuse_success, s_excuse_fail,
   c_make_excuse, c_bribe, c_honest, c_retreat, c_persuade, c_surprise_attack, c_dodge, c_counter, c_no_choice, c_escape, c_end_ok, c_end_bad].each do |n|
    nodes[n[:id]] = n
  end
  nodes
end


# ------------------------------------------------------------------------------
# Golden Dice (time-only factor)
# ------------------------------------------------------------------------------

# t_s: when the situation started (ms)
# pick_ms: ms since situation start when player picked
# birth/death: seconds (inclusive) window for choice
# rt_factor: 0..1 (1: fully time-sensitive)
def golden_dice_success_new?(pick_ms, scene_time_limit_sec, choice)
  rt_sec   = pick_ms / 1000.0
  tl_sec   = scene_time_limit_sec.to_f
  base_p   = (choice[:base_probability] || 0.0).to_f
  factor   = (choice[:rt_factor] || 0.0).to_f

  # p = base_probability * (1 - (response_time * factor) / time_limit)
  p = base_p * (1.0 - (rt_sec * factor) / tl_sec)
  p = p.clamp(0.0, 1.0)
  rand < p
end

def current_choice_probability_percent(scene, choice, t_ms)
  rt_sec = t_ms / 1000.0
  tl_sec = scene[:time_limit].to_f
  base   = (choice[:base_probability] || 0.0).to_f
  factor = (choice[:rt_factor] || 0.0).to_f
  p = base * (1.0 - (rt_sec * factor) / tl_sec)
  (p.clamp(0.0, 1.0) * 100).round
end


# ------------------------------------------------------------------------------
# State & Loops
# ------------------------------------------------------------------------------

def init args
  s = args.state
  # idempotent, survives hot-reload
  s.nodes ||= build_tree
  s.current_id ||= :S_START
  s.situation_started_at ||= now_ms(args)
  s.visible_choice_ids ||= []
  s.paused ||= false
  s.paused_t_ms ||= 0
  s.frozen ||= false
  s.frozen_t_ms ||= 0
  s.show_probability ||= false
  s.logs ||= []
  s.render_state ||= :situation_explanation # Default state
  s.situation_explanation_started_at ||= nil
  s.golden_dice_started_at ||= nil
end

def now_ms(args) = (args.tick_count * (1000.0 / 60)).to_i

def push_log args, msg
  args.state.logs.unshift msg
  args.state.logs = args.state.logs.take(8)
end

def current_node args
  return nil unless args.state.nodes && args.state.current_id
  puts "current_node: #{args.state.current_id}"
  args.state.nodes[args.state.current_id]
end

def in_window?(pick_ms, birth_sec, death_sec)
  pick_ms >= (birth_sec * 1000) && pick_ms <= (death_sec * 1000)
end

def handle_input args
  s = args.state
  node = current_node args
  
  # Handle spacebar for state transitions
  if args.inputs.keyboard.key_down.space
    case s.render_state
    when :situation_explanation
      # Spacebar from situation explanation to choice phase
      s.render_state = :choice_phase
      s.situation_started_at = now_ms(args)  # Start scene timer when choices appear
      s.situation_explanation_started_at = nil
      push_log args, "선택 단계로 이동 (스페이스 키)"
      return
      
    when :golden_dice
      # Spacebar from golden dice result to next scene
      s.render_state = :situation_explanation
      s.golden_dice_started_at = nil
      push_log args, "다음 장면으로 이동 (스페이스 키): #{s.current_id}"
      return
    end
  end
  
  return unless node && node[:kind] == :scene
  return unless s.render_state == :choice_phase  # Only handle choice input during choice phase

  # map keys 1/2/3 to first three VISIBLE choices (in their declared order)
  keys = args.inputs.keyboard
  index =
    if keys.key_down.one   then 0
    elsif keys.key_down.two then 1
    elsif keys.key_down.three then 2
    else nil
    end

  return if index.nil?

  vis = s.visible_choice_ids
  return if vis.empty? || index >= vis.length

  pick_choice_id = vis[index]
  apply_choice args, pick_choice_id
end

def apply_choice args, choice_id
  s = args.state
  scene = current_node args
  pick_ms = now_ms(args) - s.situation_started_at

  choice = s.nodes[choice_id]
  return unless scene && choice && in_window?(pick_ms, choice[:birth], choice[:death]) || choice_id == :C_NO_CHOICE

  puts "choice being applied"

  ok = golden_dice_success_new?(pick_ms, scene[:time_limit], choice)  # use new formula
  next_id = ok ? choice[:success] : choice[:failure]
  outcome = ok ? "성공" : "실패"

  # keep last pick info for render
  s.last_pick = {
    text: choice[:choice],
    at_s: (pick_ms/1000.0).round(2),
    outcome: outcome
  }

  push_log args, "선택: #{choice[:choice]} @#{s.last_pick[:at_s]}s → #{outcome}"

  s.current_id = next_id
  puts "next_id: #{next_id}"
  s.situation_started_at = now_ms(args)
  s.visible_choice_ids = []
  s.render_state = :golden_dice
end


def update args
  s = args.state

    
  if s.render_state == :choice_phase
    # Choice phase - normal scene logic
    node = current_node args
    if node && node[:kind] == :scene
      # enable/disable visible choices by birth/death
      t_ms = now_ms(args) - s.situation_started_at
      s.visible_choice_ids = node[:choices].select do |cid|
        c = s.nodes[cid]
        if c.nil?
          push_log args, "ERROR: Choice node not found for ID: #{cid}"
          false
        else
          in_window?(t_ms, c[:birth], c[:death])
        end
      end

      # hard timeout: auto-pick LAST choice (no-choice)
      if t_ms >= node[:time_limit] * 1000
        no_choice = node[:choices].last
        puts "시간 초과 → 자동 선택: #{s.nodes[no_choice][:choice]}"
        apply_choice args, no_choice
        puts "no_choice"
      end
    end
  end
end


# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

def get_situation_image_label scene, t_ms
  # Get current active situation index
  active_situation = scene[:situations].select { |s| t_ms >= (s[:at] * 1000) }.last || scene[:situations].first
  situation_index = scene[:situations].index(active_situation) || 0
  
  # Simple indexed labels: SceneID_SituationIndex
  "#{situation_index}"
end

def active_situation_text scene, t_ms
  seg = scene[:situations].select { |s| t_ms >= (s[:at] * 1000) }.last || scene[:situations].first
  seg[:text]
end

# ------------------------------------------------------------------------------
# Render Functions
# ------------------------------------------------------------------------------

def render_situation_explanation args
  s = args.state
  scene = current_node args
  w = 1280; h = 720
  
  # Background
  args.outputs.solids << [0, 0, w, h, 12, 16, 24]
  
  unless scene && scene[:kind] == :scene
    args.outputs.labels << { x: 40, y: 680, text: "(대기) 초기화 중… R 키로 재시작",
                             size_enum: 6, alignment_enum: 0, r: 230, g: 240, b: 255, font: KFONT }
    return
  end
  
  # Big situation text box
  box_x = 100; box_y = 200; box_w = 1080; box_h = 320
  args.outputs.solids << [box_x, box_y, box_w, box_h, 25, 35, 55]
  args.outputs.borders << [box_x, box_y, box_w, box_h, 120, 140, 180]
  
  # Situation text (first situation always)
  situation_text = scene[:situations].first[:text]
  args.outputs.labels << { x: box_x + box_w/2, y: box_y + box_h/2, text: situation_text,
                           size_enum: 4, alignment_enum: 1, r: 230, g: 240, b: 255, font: KFONT }
  
  # Footer
  args.outputs.labels << { x: 40, y: 50, text: "스페이스 키로 선택 단계로 이동",
                           size_enum: 2, alignment_enum: 0, r: 180, g: 190, b: 210, font: KFONT }
end

def render_golden_dice_result args
  s = args.state
  w = 1280; h = 720
  
  # Background
  args.outputs.solids << [0, 0, w, h, 12, 16, 24]
  
  # Big result box
  box_x = 100; box_y = 200; box_w = 1080; box_h = 320
  args.outputs.solids << [box_x, box_y, box_w, box_h, 25, 35, 55]
  args.outputs.borders << [box_x, box_y, box_w, box_h, 120, 140, 180]
  
  if s.last_pick
    # Choice result text
    result_text = "#{s.last_pick[:text]} → #{s.last_pick[:outcome]}"
    color = s.last_pick[:outcome] == "성공" ? [150, 255, 150] : [255, 150, 150]
    
    args.outputs.labels << { x: box_x + box_w/2, y: box_y + box_h/2 + 40, text: result_text,
                             size_enum: 4, alignment_enum: 1, r: color[0], g: color[1], b: color[2], font: KFONT }
    
    # Timing info
    timing_text = "응답 시간: #{s.last_pick[:at_s]}초"
    args.outputs.labels << { x: box_x + box_w/2, y: box_y + box_h/2 - 20, text: timing_text,
                             size_enum: 3, alignment_enum: 1, r: 200, g: 220, b: 240, font: KFONT }
    
  end
  
  # Footer
  args.outputs.labels << { x: 40, y: 50, text: "스페이스 키로 다음 장면으로 이동",
                           size_enum: 2, alignment_enum: 0, r: 180, g: 190, b: 210, font: KFONT }
end

def render_choice_phase args 
  s = args.state
  scene = current_node args
  w = 1280; h = 720
  args.outputs.solids << [0, 0, w, h, 12, 16, 24]

  unless scene && scene[:kind] == :scene
    args.outputs.labels << { x: 40, y: 680, text: "(대기) 초기화 중… R 키로 재시작",
                             size_enum: 6, alignment_enum: 0, r: 230, g: 240, b: 255, font: KFONT }
    return
  end

  t_ms = (now_ms(args) - s.situation_started_at).clamp(0, (scene[:time_limit] * 1000))
  if s.frozen
    t_ms = s.frozen_t_ms.clamp(0, (scene[:time_limit] * 1000))
  end

  # --- Situation string (현재 활성 라인) ---
  line = active_situation_text(scene, t_ms)
  args.outputs.labels << { x: 40, y: 690, text: "상황: #{line}",
                           size_enum: 6, alignment_enum: 0, r: 230, g: 240, b: 255, font: KFONT }

  # --- Situation Image Placeholder ---
  img_x = 40; img_y = 580; img_w = 400; img_h = 80
  args.outputs.solids << [img_x, img_y, img_w, img_h, 30, 40, 60]
  args.outputs.borders << [img_x, img_y, img_w, img_h, 120, 140, 180]
  
  # Get current image label based on scene and situation
  current_image_label = get_situation_image_label(scene, t_ms)
  args.outputs.labels << { x: img_x + img_w/2, y: img_y + img_h/2, text:  "생성된 이미지 -  " + current_image_label,
                           size_enum: 3, alignment_enum: 1, r: 180, g: 190, b: 210, font: KFONT }

  # 작은 메타(장면 ID/시간)
  args.outputs.labels << { x: 40, y: 560,
                           size_enum: 2, alignment_enum: 0, r: 180, g: 190, b: 210, font: KFONT }

  # --- Timeline bar ---
  bar_x = 40; bar_y = 540; bar_w = 1200; bar_h = 14
  limit_ms = (scene[:time_limit] * 1000).to_i
  fill_w = (t_ms / limit_ms.to_f) * bar_w
  args.outputs.solids  << [bar_x, bar_y, bar_w, bar_h, 25, 35, 55]
  args.outputs.solids  << [bar_x, bar_y, fill_w, bar_h, 255, 140, 90]
  args.outputs.borders << [bar_x, bar_y, bar_w, bar_h, 120, 140, 180]
  scene[:situations].each do |seg|
    x = bar_x + (seg[:at].to_f / scene[:time_limit]) * bar_w
    args.outputs.solids << [x-1, bar_y-3, 2, bar_h+6, 180, 190, 210]
  end

  # --- Choice boxes (문구 + 현재 성공확률) ---
  box_w = 380; box_h = 120
  base_x = 40; gap_x = 20; base_y = 420

  s.visible_choice_ids.take(3).each_with_index do |cid, i|
    c = s.nodes[cid]
    x = base_x + i * (box_w + gap_x)
    y = base_y
    args.outputs.solids  << [x, y, box_w, box_h, 22, 30, 50]
    args.outputs.borders << [x, y, box_w, box_h, 120, 180, 255]

    # choice string
    args.outputs.labels << { x: x+14, y: y+92, text: "#{c[:choice]}  (press #{i+1})",
                             size_enum: 3, alignment_enum: 0, r: 230, g: 240, b: 255, font: KFONT }

    # lifespan
    life = "#{c[:birth]}s ~ #{c[:death]}s"
    args.outputs.labels << { x: x+14, y: y+64,
                             size_enum: 2, alignment_enum: 0, r: 180, g: 200, b: 230, font: KFONT }

    # current probability
    if s.show_probability
      pct = current_choice_probability_percent(scene, c, t_ms)
      args.outputs.labels << { x: x+14, y: y+40, text: "Golden Dice 성공확률: #{pct}%",
                               size_enum: 2, alignment_enum: 0, r: 200, g: 220, b: 160, font: KFONT }
    end
  end

  # --- last picked choice string (최근 선택 표시) ---
  if s.last_pick
    args.outputs.labels << { x: 40, y: 390, text: "최근 선택: #{s.last_pick[:text]} @#{s.last_pick[:at_s]}s → #{s.last_pick[:outcome]}",
                             size_enum: 3, alignment_enum: 0, r: 255, g: 220, b: 150, font: KFONT }
  end

  # hint/footer
  args.outputs.labels << { x: 40, y: 370, text: "선택: [1][2][3] | restart: Ctrl+R | pause: P | show probability: S",
                           size_enum: 2, alignment_enum: 0, r: 210, g: 220, b: 240, font: KFONT }

  # logs
  lx = 40; ly = 320; lw = 1200; lh = 160
  args.outputs.solids  << [lx, ly-lh, lw, lh, 15, 18, 26]
  args.outputs.borders << [lx, ly-lh, lw, lh, 90, 110, 140]
  s.logs.each_with_index do |ln, idx|
    args.outputs.labels << { x: lx+12, y: ly-16 - idx*18, text: ln,
                             size_enum: 2, alignment_enum: 0, r: 190, g: 200, b: 220, font: KFONT }
  end

  # reset
  if args.inputs.keyboard.key_down.r
    args.state.schema_version = nil
  end
end

def render args
  s = args.state
  
  case s.render_state
  when :situation_explanation
    # puts "situation_explanation"
    render_situation_explanation args
  when :choice_phase
    # puts "choice_phase"
    render_choice_phase args
  when :golden_dice
    # puts "golden_dice"
    render_golden_dice_result args
  end
end
