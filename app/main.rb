# -*- coding: utf-8 -*-
# app/main.rb
require "app/game_state"
require "app/scene_renderer"
require "app/client"
require "app/api_client"
require "app/choice_manager"
require "app/prompts"

def tick(args)
  # Initialize game components on first tick
  init(args) if args.state.tick_count == 0
  
  # Update game state
  update(args)
  
  # Render current state
  render(args)
end

def init(args)
  puts "Initializing game..."
  
  # Initialize core components
  args.state.game_state ||= GameState.new
  args.state.scene_renderer ||= SceneRenderer.new
  args.state.api_client ||= APIClient.new(args.state.game_state)
  args.state.choice_manager ||= ChoiceManager.new(args.state.game_state, args.state.api_client)
  
  # Initialize player and NPC
  initialize_player_and_npc(args.state.game_state)
  
  # Start with situation explanation
  args.state.game_state.current_situation = initial_situation_prompt
  args.state.game_state.current_outcome = initial_outcome_prompt
  puts " current situation: #{args.state.game_state.current_situation}"
  args.state.game_state.transition_to(:situation_explanation)
  
  puts "Game initialized successfully"
end

def update(args)
  game_state = args.state.game_state
  
  # Global toggle for reasoning visibility
  if args.inputs.keyboard.key_down.r
    game_state.show_reasoning = !game_state.show_reasoning
    puts "Show reasoning: #{game_state.show_reasoning}"
  end

  # Update timing
  game_state.update_timing(args)
  
  # Handle API responses
  handle_api_responses(args)
  
  # Handle input based on current state
  case game_state.get_current_state
  when :situation_explanation
    handle_situation_explanation_input(args)
  when :scene_generation
    # Scene generation is handled by API response
  when :choice_phase
    handle_choice_phase_input(args)
  when :dice_result
    handle_dice_result_input(args)
  when :outcome
    handle_outcome_input(args)
  end
  
  # Handle timeouts
  handle_timeouts(args)
end

def render(args)
  game_state = args.state.game_state
  scene_renderer = args.state.scene_renderer
  
  scene_renderer.render(args, game_state)
end

private

def initialize_player_and_npc(game_state)
  # Initialize player
  stats = Stats.new(12, 14, 10)
  traits = [
    Trait.new("Desire", "Greedy tendency", "Strong"),
    Trait.new("Revolutionary", "Seeks change", "Moderate")
  ]
  items = [
    Item.new("Sword", "A sharp sword"),
    Item.new("Potion", "A potion that heals minor wounds"),
    Item.new("Bag of gold coins", "A bag of gold coins"),
    Item.new("Map", "A map of the area"),
  ]
  
  game_state.player = Player.new(
    "Player", 25, "Male", "Human", 
    stats, traits, items, starting_player_memory
  )
  
  # Initialize NPC
  game_state.npc = NPC.new(
    "Guard", 35, "Male", "Human",
    guard_npc_description, starting_guard_npc_memory
  )
end

def handle_api_responses(args)
  game_state = args.state.game_state
  api_client = args.state.api_client
  
  # Check for pending API responses
  if args.state.llm_result && args.state.llm_result[:complete]
    api_client.handle_response(args)
  end
end

def handle_situation_explanation_input(args)
  game_state = args.state.game_state
  
  if args.inputs.keyboard.key_down.space
    puts "Starting scene generation..."
    game_state.transition_to(:scene_generation)
    
    # Request scene generation from API
    context_str = context_prompt(
      game_state.get_current_situation,
      game_state.player,
      game_state.npc
    )
    prompt = "#{context_str}\n\n#{scene_generation_prompt}"
    puts "prompt: #{prompt}"
    args.state.api_client.send_scene_request(args, prompt)
  end
end

def handle_choice_phase_input(args)
  game_state = args.state.game_state
  choice_manager = args.state.choice_manager
  
  choice_manager.handle_input(args)
end

def handle_outcome_input(args)
  game_state = args.state.game_state
  
  if args.inputs.keyboard.key_down.space
    # Only allow continue after outcome has been received
    if game_state.api_response
      puts "Continuing to next scene..."
      # Prepare for next cycle
      game_state.reset_for_new_scene
      game_state.transition_to(:situation_explanation)
    end
  end
end

def handle_dice_result_input(args)
  game_state = args.state.game_state
  api_client = args.state.api_client

  if args.inputs.keyboard.key_down.space
    # Only act if success criteria have been received but roll has not happened yet
    if game_state.dice_result && !game_state.dice_result[:roll]
      # Roll immediately and request outcome in one press, then move to OUTCOME screen
      api_client.roll_and_update_dice_result(args)

      outcome_prompt_str = outcome_prompt(
        game_state.dice_result,
        game_state.get_current_situation,
        game_state.player,
        game_state.npc
      )
      api_client.send_outcome_request(args, outcome_prompt_str)
      game_state.transition_to(:outcome)
    end
  end
end

def handle_timeouts(args)
  game_state = args.state.game_state
  choice_manager = args.state.choice_manager
  
  # Handle scene timeout
  if game_state.get_current_state == :choice_phase && game_state.scene_timeout
    choice_manager.handle_timeout(args)
  end
end