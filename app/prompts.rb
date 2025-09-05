# -*- coding: utf-8 -*-
# app/prompts.rb

class Stats
  attr_accessor :physical, :intelligence, :speech
  
  def initialize(physical, intelligence, speech)
    @physical = physical      # 신체
    @intelligence = intelligence  # 지능
    @speech = speech        # 언변 
  end

  #mutators
  def increment_physical(physical)
    @physical += physical
  end

  def increment_intelligence(intelligence)
    @intelligence += intelligence
  end

  def increment_speech(speech)
    @speech += speech
  end
end

class Trait
  attr_accessor :name, :description, :intensity
  
  def initialize(name, description, intensity)
    @name = name
    @description = description
    @intensity = intensity
  end
  
  def change_intensity(intensity)
    @intensity = intensity
  end
  
  # 예시: 같은 성향이라도 강도에 따라 다르게 나타날 수 있음
  # 탐욕: 약함 (가끔 욕심부림) vs 강함 (극도로 탐욕스러움)
  # 혁명적: 보통 (개혁을 원함) vs 강함 (급진적 혁명을 추구함)
end

class Item
  attr_accessor :name, :description
  
  def initialize(name, description)
    @name = name
    @description = description
  end
end

class Player
  attr_accessor :name, :age, :sex, :species, :stats, :traits, :items, :memory
  
  def initialize(name, age, sex, species, stats, traits, items, memory)
    @name = name
    @age = age
    @sex = sex
    @species = species
    @stats = stats # Stats object
    @traits = traits  # List of Trait objects
    @items = items  # List of Item objects
    @memory = memory 
  end
  
  def add_trait(trait)
    @traits << trait
  end
  
  def remove_trait(trait_name)
    @traits.reject! { |trait| trait.name == trait_name }
  end
  
  def get_trait(trait_name)
    @traits.find { |trait| trait.name == trait_name }
  end
end

class NPC
  attr_accessor :name, :age, :sex, :species, :descriptions, :memory
  
  def initialize(name, age, sex, species, descriptions, memory)
    @name = name
    @age = age
    @sex = sex
    @species = species
    @descriptions = descriptions  # abilities, strength, intelligence, looks, speech, etc.
    @memory = memory
  end
end


def situation_prompt(situation, player, npc)
  # Build comprehensive context for the LLM
  context = {
    current_situation: situation,
    player_context: build_player_context(player),
    npc_context: build_npc_context(npc),
    player_memory: player.memory
  }
  
  # Format the prompt for the LLM
  <<~PROMPT
    You are the Game Master (GM) for a text-based RPG. Based on the following context, generate an engaging narrative description of the current scene.

    ## CURRENT SITUATION
    #{context[:current_situation]}

    ## PLAYER CONTEXT
    #{context[:player_context]}

    ## NPC CONTEXT  
    #{context[:npc_context]}

    ## PLAYER MEMORY
    #{context[:player_memory].empty? ? "No recent memories" : context[:player_memory]}

    ## YOUR TASK
    1. Describe the current scene vividly and atmospherically
    2. Consider the player's traits and stats when describing their capabilities and feelings
    3. Consider the NPC's descriptions and current state
    4. Make the narrative engaging and immersive
    5. Set the mood and atmosphere for the scene

    ## OUTPUT FORMAT
    Please respond with a vivid narrative description of the current scene, considering the character's perspective and the overall atmosphere.
  PROMPT
end

def build_player_context(player)
  <<~CONTEXT
    Name: #{player.name}
    Age: #{player.age}
    Sex: #{player.sex}
    Species: #{player.species}
    
    Stats:
    - Body/Physical: #{player.stats.physical}/20
    - Intelligence: #{player.stats.intelligence}/20  
    - Speech/Charisma: #{player.stats.speech}/20
    
    Traits: #{player.traits.map { |t| "#{t.name} (#{t.intensity})" }.join(", ")}
  CONTEXT
end

def build_npc_context(npc)
  <<~CONTEXT
    Name: #{npc.name}
    Age: #{npc.age}
    Sex: #{npc.sex}
    Species: #{npc.species}
    
    Description: #{npc.descriptions.empty? ? "No detailed description available" : npc.descriptions}
  CONTEXT
end

def initial_situation_prompt
  <<~SITUATION
    There is a tense standoff at the castle gate.
    
    A traveler (player) wants to enter the castle, but a guard is blocking them.
    The guard demands identification or entry permit, but the traveler doesn't have them.
    
    The traveler emphasizes they are harmless, but gives vague answers to the guard's questions.
    Particularly, their answers about "where they came from" and "what they want to do in the castle" were unclear.
    
    The guard becomes more suspicious of this vague behavior and raises their spear in defense.
    The traveler looks surprised but still doesn't back down.
    
    The current situation is very tense, and the guard is ready to attack.
    The traveler cannot back down because they have urgent business inside the castle.
    
    This standoff could lead to violence at any moment.
  SITUATION
end

def initial_player_prompt
  
end

def initial_npc_prompt
  "The guard is suspicious of the player.
  If the player doesn't back down, the guard is ready to use force.
  "
end

def dm_character_prompt
  "You are the DM for a TRPG game. You are responsible for immersive game progression within the world and vividly describing situations.
  You have witty sarcastic humor and are a great storyteller.
  You will be the player's closest ally and their deepest nightmare at the same time.
  The player depends on YOU to make creative and entertaining stories.
  "
end

# Prompt with parameters
def dm_instruction_prompt
  ""
end

def scene_generation_prompt 
  <<~PROMPT
    Given the current situation and narrative, generate a new SCENE with meaningful choices for the player.


    ## SCENE STRUCTURE
    - SCENE: A single decision point with duration 5-20 seconds
    - STATE: A micro situation within the scene (usually 1 state for simple scenes)
    - CHOICE: Player actions with timing windows


    SCENE is like one turn of the game.
    SCENE should be a single decision point for the player.
    SCENE has a duration, usually 5-20 seconds.
    SCENE consists of list of STATE, each having their own lifespans.

    STATE is a micro current situation of the SCENE.
    STATE represents a single window of action within a SCENE.
    STATE changes every few seconds, depending on the SCENE to be generated.
    a SCENE can consist of a single STATE, if the SCENE can be explained in a single window of action.

    a STATE can have multiple CHOICEs, each having their own lifespans.
    CHOICE can span multiple STATEs, if the CHOICE is valid for multiple STATEs.
    CHOICE is a possible action the player can take, in response to the STATE and the overall situation


    ## REQUIREMENTS
    1. Create 3-5 creative, intuitive choices
    2. **CRITICAL**: Player has only 5 seconds to read state text, understand choices, and decide
    3. State text must be extremely concise - maximum 10-15 words
    4. Choice text must be under 5 words - direct action verbs preferred
    5. Consider player stats (Physical, Intelligence, Speech) and traits
    6. Make choices advance the story and build tension
    7. Ensure timing makes sense for the situation
    8. Make several states, for example, a scene might have states at 0s (initial situation), 3s (escalation), and 6s (climax) to show how the situation changes over time
    

    ## OUTPUT FORMAT
    Respond with this EXACT JSON structure:
    {
      "id": "unique_scene_id",
      "duration": 15,
      "states": [
        {
          "id": "state_1",
          "at": 0,
          "duration": 5,
          "text": "Guard blocks your path. Spear raised. Demands ID."
        },
        {
          "id": "state_2",
          "at": 5,
          "duration": 5,
          "text": "Guard steps closer. Final warning. Spear tip glints."
        },
        {
          "id": "state_3",
          "at": 10,
          "duration": 5,
          "text": "Guard lunges! Spear thrusts toward you. NOW!"
        }
      ],
      "choices": [
        {
          "id": "choice_1",
          "text": "Try to talk your way past",
          "state_ids": ["state_1", "state_2"]
        },
        {
          "id": "choice_2",
          "text": "Run away quickly",
          "state_ids": ["state_2", "state_3"]
        },
        {
          "id": "choice_3",
          "text": "Fight back",
          "state_ids": ["state_1", "state_2", "state_3"]
        },
        {
          "id": "choice_4",
          "text": "Dodge the spear",
          "state_ids": ["state_3"]
        }
      ],
      "reading_time_estimate": 6,
      "decision_deadline": 15
    }
    
    ## STATE GUIDELINES
    - Each state should represent a distinct phase of the scene
    - States should build tension or change the situation meaningfully
    - Use "at" field to specify when each state begins (in seconds)
    - **CRITICAL**: State text must be extremely brief - 10-15 words maximum
    - Use short, punchy sentences. No flowery descriptions.
    - Focus on immediate threats, actions, and consequences
    - States no longer contain choices directly - choices are assigned via state_ids
    - Example state progression:
      state 1 (0s): "Guard blocks path. Spear raised. Demands ID."
      state 2 (5s): "Guard steps closer. Final warning. Spear tip glints."
      state 3 (10s): "Guard lunges! Spear thrusts toward you. NOW!"

    ## CHOICE GUIDELINES
    - **CRITICAL**: Choice text must be under 5 words - direct action verbs preferred
    - Make each choice distinct and meaningful
    - Consider player's traits and stats
    - Each choice should have clear risk/reward dynamics
    - **CRITICAL**: Choices are defined at the scene level and assigned to states via state_ids
    - Choices can span multiple states for better persistence and player agency
    - Each choice should be contextually appropriate for ALL states it's assigned to
    - Some choices may only be available in specific states (single state_ids)
    - Other choices may persist across multiple states for ongoing actions
    - With choice, you can use items as well.
    - Examples: "Fight back", "Run away", "Try to talk", "Use item", "Dodge attack"
    Create creative and engaging choices that make sense across their assigned states.
  PROMPT
end

def result_evaluation_prompt(player_choice, current_situation, player, npc)
  <<~PROMPT
    You are the Game Master (GM) evaluating the result of a player's choice in a text-based RPG.
    
    ## PLAYER'S CHOICE
    #{player_choice}
    
    ## CURRENT SITUATION
    #{current_situation}
    
    ## PLAYER CONTEXT
    #{build_player_context(player)}
    
    ## NPC CONTEXT
    #{build_npc_context(npc)}
    
    ## YOUR TASK
    1. Evaluate the consequences of the player's choice
    2. Consider how this choice affects the current situation
    3. Update player and NPC memories based on the outcome
    4. Generate a new situation that will lead to the next scene
    5. Make the consequences meaningful and impactful
    
    ## OUTPUT FORMAT
    Please respond in the following JSON format:
    {
      "result_description": "Detailed description of what happened as a result of the choice",
      "player_memory_update": "How this experience affects the player's memory",
      "npc_memory_update": "How this experience affects the NPC's memory",
      "new_situation": "The new situation that emerges from this choice",
      "consequences": {
        "immediate": "What happens immediately",
        "long_term": "Potential long-term effects"
      },
      "atmosphere_change": "How the overall mood/tension has changed"
    }
  PROMPT
end

def success_criteria_prompt(player_choice, current_situation, player, npc)
  <<~PROMPT
    You are the Game Master (GM) determining the success criteria for a player's choice in a text-based RPG using a 20-sided dice system.
    
    ## PLAYER'S CHOICE
    #{player_choice}
    
    ## CURRENT SITUATION
    #{current_situation}
    
    ## PLAYER CONTEXT
    #{build_player_context(player)}
    
    ## NPC CONTEXT
    #{build_npc_context(npc)}
    
    ## YOUR TASK
    1. Analyze the difficulty of the player's choice based on the current situation
    2. Consider the player's stats, traits, and current circumstances
    3. Determine what number (or higher) on a 20-sided dice would represent success
    4. Make the difficulty realistic and meaningful to the story
    
    ## DIFFICULTY GUIDELINES
    - **Very Easy (1-5)**: Simple actions, favorable circumstances
    - **Easy (6-10)**: Basic actions, slight challenges
    - **Moderate (11-15)**: Standard actions, moderate challenges
    - **Hard (16-18)**: Difficult actions, significant challenges
    - **Very Hard (19-20)**: Extremely difficult actions, major obstacles
    
    ## FACTORS TO CONSIDER
    - Player's relevant stats (physical, intelligence, speech)
    - Player's traits and their intensity
    - Current situation and environment
    - NPC's current state and disposition
    - Time pressure and urgency
    - Previous actions and their consequences
    
    ## OUTPUT FORMAT
    Please respond in the following JSON format:
    {
      "success_threshold": 15,
      "difficulty_level": "Hard",
      "reasoning": "This action requires convincing a suspicious guard who is already on high alert. The player's speech skill and current tense atmosphere make this challenging.",
      "factors_considered": {
        "player_stats": "Speech 10/20 - moderate",
        "player_traits": "욕망 (강함) - may help with determination",
        "situation": "Guard is suspicious and armed",
        "environment": "High tension, time pressure"
      }
    }
    
    ## IMPORTANT
    - success_threshold must be between 1 and 20
    - Make the difficulty realistic and story-appropriate
    - Consider all relevant factors in your reasoning
  PROMPT
end

def starting_player_memory()
  <<~MEMORY
    The player is in an urgent situation where they must enter the castle.
    
    They received a request to monitor a general inside the castle and report suspicious behavior.
    This is a very important mission, and they cannot complete it without entering the castle.
    
    About 30 minutes ago, when they arrived at the castle gate, a guard blocked them.
    The guard demanded identification or entry permit, but the player doesn't have them.
    
    The player emphasized they are harmless, but couldn't answer the guard's questions honestly.
    For questions about "where they came from" and "what they want to do in the castle",
    they had to give vague answers due to circumstances where they couldn't tell the truth.
    
    The guard seemed to become more suspicious of these vague answers.
    The player could sense that the guard values discipline and rules.
    
    They continued to request entry, but the guard raised their spear in defense.
    The player was surprised by this situation, but cannot back down because they have urgent business inside.
    
    The current situation is very tense, and the guard seems ready to attack.
    The player must somehow enter the castle, either by convincing the guard or finding another way.
    
    This mission must succeed, or there could be serious consequences.
  MEMORY
end

def starting_guard_npc_memory()
  <<~MEMORY
    The guard has been protecting the castle for 5 hours.
    
    About 30 minutes ago, a traveler appeared at the castle gate. The traveler said they wanted to enter the castle,
    but when the guard demanded identification or entry permit, they couldn't give clear answers.
    
    The traveler emphasized they are harmless, but gave vague answers or tried to avoid the guard's questions.
    Particularly, their answers about "where they came from" and "what they want to do in the castle" were unclear.
    
    The guard became more suspicious of this vague behavior.
    As a guard who values discipline, allowing someone with unclear identity into the castle
    would be a betrayal of their duty.
    
    When the traveler continued to request entry, the guard raised their spear in defense.
    The traveler looked surprised but still didn't back down.
    
    The current situation is very tense, and the guard is ready to use force
    if the traveler doesn't back down.
  MEMORY
end

def guard_npc_description()
  "The guard has a taciturn personality. They value discipline and are not easily fooled.
  They carry a spear as a weapon and wear armor.
  They are large in build.
  If the player doesn't back down, they are ready to attack with their spear.
  "
end

def outcome_prompt(dice_result, current_situation, player, npc)
  <<~PROMPT
    You are the Game Master (GM) generating the outcome of a player's action in a text-based RPG based on a D20 dice roll result.
    ## DICE RESULT
    - Player's choice: #{dice_result[:choice]}
    - Dice roll: #{dice_result[:roll]}/20
    - Success threshold: #{dice_result[:threshold]} or higher
    - Result: #{dice_result[:success] ? 'SUCCESS' : 'FAILURE'}
    
    ## CURRENT SITUATION
    #{current_situation}
    
    ## PLAYER CONTEXT
    #{build_player_context(player)}
    
    ## NPC CONTEXT
    #{build_npc_context(npc)}
    
    ## YOUR TASK
    1. Generate a detailed outcome description based on the dice result
    2. Consider how success/failure affects the current situation
    3. Update player and NPC memories based on the outcome
    4. Generate a new situation that emerges from this outcome
    5. Make the consequences meaningful and impactful to the story
    
    ## SUCCESS vs FAILURE GUIDELINES
    - **SUCCESS**: The player's action achieves its intended goal, but may have unexpected consequences
    - **FAILURE**: The player's action doesn't achieve its goal, but may open new opportunities or create interesting complications
    
    ## OUTPUT FORMAT
    Please respond in the following JSON format:
    {
      "outcome_description": "Detailed description of what happened as a result of the dice roll",
      "consequences": {
        "immediate": "What happens immediately",
        "long_term": "Potential long-term effects or implications"
      },
      "atmosphere_change": "How the overall mood/tension has changed",
      "player_memory_update": "How this experience affects the player's memory and understanding",
      "npc_memory_update": "How this experience affects the NPC's memory and disposition"
    }
    
    ## IMPORTANT
    - Make the outcome realistic and story-appropriate
    - Consider the player's traits and how they might react to success/failure
    - The new situation should naturally flow from the outcome
    - Keep the story engaging and maintain narrative tension
  PROMPT
end