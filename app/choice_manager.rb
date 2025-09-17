# -*- coding: utf-8 -*-
# app/choice_manager.rb

class ChoiceManager
  def initialize(game_state, api_client)
    @game_state = game_state
    @api_client = api_client
    @selected_choice = nil
  end

  def handle_input(args)
    return unless @game_state.get_current_state == :choice_phase

    # Block choice input during reading pause
    # if @game_state.reading_pause && @game_state.reading_pause[:active]
    #   return
    # end

    
    
    if args.inputs.keyboard.key_down.one
      puts "KEYDOWN ONE"
      select_choice(0, args)
    elsif args.inputs.keyboard.key_down.two
      puts "KEYDOWN TWO"
      select_choice(1, args)
    elsif args.inputs.keyboard.key_down.three
      puts "KEYDOWN THREE"
      select_choice(2, args)
    elsif args.inputs.keyboard.key_down.four
      puts "KEYDOWN FOUR"
      select_choice(3, args)
    elsif args.inputs.keyboard.key_down.five
      puts "KEYDOWN FIVE"
      select_choice(4, args)
    end
  end

  def get_visible_choices(current_state, current_time)
    # Use the new method to get current choices from current_state
    @game_state.get_current_choices
  end

  def apply_choice(text, args)
    # Create a new Choice object with the provided text
    @selected_choice = text
    @game_state.selected_choice_text = text
    # Transition to dice result phase
    @game_state.transition_to(:dice_result)
    puts "Transitioning to dice result phase"
    
    # Request success criteria from API
    request_success_criteria(text, args)
  end

  def handle_timeout(args)
    return unless @game_state.get_current_state == :choice_phase
    
    puts "Scene timeout - no choice made"
    
    # Create a new timeout choice and apply it
    timeout_text = "Wait and see what happens"
    puts "Applying timeout choice: #{timeout_text}"
    apply_choice(timeout_text, args)
  end

  def get_selected_choice
    @selected_choice
  end

  def clear_selection
    @selected_choice = nil
  end

  private

  def select_choice(index, args)
    current_choices = @game_state.get_current_choices
    return if index >= current_choices.length
    
    choice = current_choices[index]
    puts "Selecting choice: #{choice.text}"
    apply_choice(choice.text, args)
  end

  def request_success_criteria(choice_text, args)
    decision_time_seconds = (@game_state.time && @game_state.time.scene_time_seconds) || 0.0
    prompt = success_criteria_prompt(
      choice_text,
      @game_state.get_current_situation,
      @game_state.player,
      @game_state.npc,
      decision_time_seconds
    )
    puts "Success criteria prompt: #{prompt}"
    @api_client.send_success_criteria_request(args, prompt)
  end
end
