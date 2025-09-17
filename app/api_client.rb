# -*- coding: utf-8 -*-
# app/api_client.rb
require "app/scene"

class APIClient
  def initialize(game_state)
    @game_state = game_state
    @base_url = "http://localhost:8000"
    @llm_client = LLMClient.new
  end

  def send_scene_request(args,prompt)
    puts "Sending scene generation request..."
    puts prompt
    prompt = prompt + "\n 무조건 무조건 한국어로 생성하시오"
    @llm_client.send_request(args, "/scene", prompt)
  end

  def send_success_criteria_request(args,prompt)
    puts "Sending success criteria request..."
    puts prompt
    @llm_client.send_request(args, "/success_criteria", prompt)
  end

  def send_outcome_request(args,prompt)
    puts "Sending outcome request..."
    prompt = prompt + "\n 무조건 무조건 한국어로 생성하시오"
    @llm_client.send_request(args, "/outcome", prompt)
  end

  def handle_response(args)
    response = @llm_client.handle_response(args)
    return nil unless response
    
    puts "API Response received: #{response[0..100]}..."
    
    # Parse JSON response
    parsed_response = parse_json_response(response)
    return nil unless parsed_response
    
    # Route response based on current state
    case @game_state.get_current_state
    when :scene_generation
      handle_scene_response(parsed_response, args)
    when :dice_result
      handle_success_criteria_response(parsed_response, args)
    when :outcome
      handle_outcome_response(parsed_response, args)
    end
    
    parsed_response
  end

  private

  def parse_json_response(response)
    # Simple JSON parsing for DragonRuby
    # This is a basic implementation - you might want to enhance it
    begin
      # Remove any leading/trailing whitespace
      response = response.strip
      
      # Basic JSON parsing - this is simplified and might need enhancement
      if response.start_with?('{') && response.end_with?('}')
        # For now, store the raw response and let the handlers parse specific fields
        { raw_response: response }
      else
        puts "Invalid JSON response: #{response}"
        nil
      end
    rescue => e
      puts "Error parsing JSON: #{e.message}"
      nil
    end
  end

  def handle_scene_response(response, args)
    puts "Handling scene response..."
    
    # Parse scene data from response
    scene = extract_scene_data(response[:raw_response], args)
    
    if scene
      @game_state.start_new_scene(scene, args)
      @game_state.transition_to(:choice_phase)
      # Orchestrate typing and focus for situation and choices
      active_state = @game_state.get_active_state
      if active_state
        situation_text = active_state.text
        choice_texts = active_state.choices.map { |c| c.text }
        # Freeze scene time until initial typing completes; resume handled by Sequencer when typing done
        @game_state.time.pause
        args.state.sequencer.start_scene(situation_text, choice_texts)
        @game_state.last_handled_state_id = active_state.id
      end
    else
      puts "here 1"
      puts "Failed to parse scene data"
      @game_state.transition_to(:situation_explanation)
    end
  end

  def handle_success_criteria_response(response, args)
    puts "Handling success criteria response..."
    
    # Parse success criteria from response
    success_data = extract_success_criteria(response[:raw_response], args)
    
    if success_data
      @game_state.dice_result = {
        big_success_threshold: success_data[:big_success_threshold],
        success_threshold: success_data[:success_threshold],
        small_failure_threshold: success_data[:small_failure_threshold],
        reasoning: success_data[:reasoning],
        choice: (@game_state.selected_choice_text || "Unknown choice")
      }
      puts "Success data: #{success_data}"
      
      # Show thresholds first; user will press SPACE to roll
      @game_state.transition_to(:dice_result)
    else
      puts "here 2"
      puts "Failed to parse success criteria"
      @game_state.transition_to(:situation_explanation)
    end
  end

  def handle_outcome_response(response, args)
    puts "Handling outcome response..."
    
    # Parse outcome data from response
    outcome_data = extract_outcome_data(response[:raw_response], args)
    
    if outcome_data
      @game_state.api_response = outcome_data
      @game_state.current_outcome = outcome_data[:outcome_description] if outcome_data[:outcome_description]
      
      # Update player and NPC memories
      update_memories(outcome_data)
      
      # Update current situation
      @game_state.current_situation = outcome_data[:updated_situation] || outcome_data[:new_situation] || outcome_data[:outcome_description] || "The situation has changed."
      # Stay in OUTCOME; user continues with SPACE which triggers reset/transition
    else
      puts "here 3"
      puts "Failed to parse outcome data"
      @game_state.transition_to(:situation_explanation)
    end
  end

  def extract_scene_data(raw_response, args)
    # Parse the JSON response from the API
    begin
      # The response is double-encoded JSON, so we need to parse it twice
      # First, extract the inner JSON string
      inner_json = raw_response
      
      # Parse the inner JSON to get the scene data using DragonRuby's built-in parser
      unescaped_json = parse_inner_json(inner_json)
      scene_data = args.gtk.parse_json(unescaped_json)
      return nil unless scene_data
      
      # Create State objects
      states = scene_data["states"].map do |state_data|
        # Find choices that belong to this state
        state_choices = scene_data["choices"].select do |choice_data|
          choice_data["state_ids"] && choice_data["state_ids"].include?(state_data["id"])
        end.map do |choice_data|
          Choice.new(choice_data["id"], choice_data["text"], choice_data["time_to_read"] || 0)
        end
        
        State.new(
          state_data["id"],
          state_data["at"],
          state_data["duration"],
          state_data["text"],
          state_data["time_to_read"] || 0,
          state_choices
        )
      end
      
      # Create Scene object
      scene = Scene.new(
        scene_data["id"] || "scene",
        scene_data["duration"],
        states,
        scene_data["reading_time_estimate"],
      )
      puts "Created scene: duration=#{scene.duration}, states=#{scene.states.length}"
      puts "State 1: #{scene.states[0].id} (#{scene.states[0].choices.length} choices)" if scene.states[0]
      scene
      
    rescue => e
      puts "Error parsing scene data: #{e.message}"
      puts "Raw response: #{raw_response}"
      nil
    end
  end

  def extract_success_criteria(raw_response, args)
    begin
      inner_json = raw_response
      unescaped_json = parse_inner_json(inner_json)
      data = args.gtk.parse_json(unescaped_json)
      return nil unless data

      {
        big_success_threshold: data["big_success_threshold"],
        success_threshold: data["success_threshold"],
        small_failure_threshold: data["small_failure_threshold"],
        reasoning: data["reasoning"]
      }
    rescue => e
      puts "Error parsing success criteria: #{e.message}"
      puts "Raw response: #{raw_response}"
      nil
    end
  end

  def extract_outcome_data(raw_response, args)
    begin
      inner_json = raw_response
      unescaped_json = parse_inner_json(inner_json)
      data = args.gtk.parse_json(unescaped_json)
      return nil unless data

      {
        outcome_description: data["outcome_description"],
        updated_situation: data["updated_situation"],
        player_memory_update: data["updated_player_memory"],
        npc_memory_update: data["updated_npc_memory"]
      }
    rescue => e
      puts "Error parsing outcome data: #{e.message}"
      puts "Raw response: #{raw_response}"
      nil
    end
  end

  def roll_d20
    Numeric.rand(1..20)
  end

  # Roll dice and update game_state.dice_result with roll and category
  def roll_and_update_dice_result(args)
    return unless @game_state.dice_result

    dice_roll = roll_d20
    big_success_threshold = @game_state.dice_result[:big_success_threshold]
    success_threshold = @game_state.dice_result[:success_threshold]
    small_failure_threshold = @game_state.dice_result[:small_failure_threshold]

    category = :failure
    if big_success_threshold && dice_roll >= big_success_threshold
      category = :huge_success
    elsif success_threshold && dice_roll >= success_threshold
      category = :success
    elsif small_failure_threshold && dice_roll < small_failure_threshold
      category = :big_failure
    else
      category = :failure
    end

    @game_state.dice_result[:roll] = dice_roll
    @game_state.dice_result[:category] = category
  end

  def update_memories(outcome_data)
    # Update player memory
    if @game_state.player && outcome_data[:player_memory_update]
      @game_state.player.memory = outcome_data[:player_memory_update]
    end
    
    # Update NPC memory
    if @game_state.npc && outcome_data[:npc_memory_update]
      @game_state.npc.memory = outcome_data[:npc_memory_update]
    end
  end

  def parse_inner_json(json_string)
    # Use DragonRuby's built-in JSON parser
    # Remove outer quotes and unescape
    json_string = json_string.strip
    if json_string.start_with?('"') && json_string.end_with?('"')
      json_string = json_string[1...-1]
    end
    
    # Unescape JSON string
    json_string = json_string.gsub('\\"', '"')
    json_string = json_string.gsub('\\n', "\n")
    json_string = json_string.gsub('\\t', "\t")
    json_string = json_string.gsub('\\\\', '\\')
    
    # Use DragonRuby's built-in JSON parser
    # We need to pass args to access gtk, so we'll need to modify the calling method
    # For now, return the unescaped string and parse it in the calling method
    json_string
  end

end
