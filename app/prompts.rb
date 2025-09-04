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
    - Physical: #{player.stats.physical}/20
    - Intelligence: #{player.stats.intelligence}/20  
    - Speech: #{player.stats.speech}/20
    
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
    성문 앞에서 긴장된 대치 상황이 벌어지고 있다.
    
    한 명의 여행자(플레이어)가 성안으로 들어가려고 하지만, 문지기가 이를 막고 있다.
    문지기는 신분증이나 입성 허가서를 요구했지만, 여행자는 그런 것을 가지고 있지 않다.
    
    여행자는 자신이 무해하다고 강조했지만, 문지기의 질문들에 대해 모호하게 대답했다.
    특히 "어디서 왔는지", "성안에서 무엇을 하려는지"에 대한 답변이 불분명했다.
    
    문지기는 이런 모호한 행동에 더욱 의심을 품게 되었고, 창을 들어 방어 자세를 취했다.
    여행자는 놀란 표정을 지었지만, 여전히 물러서지 않았다.
    
    현재 상황은 매우 긴장되어 있으며, 문지기가 공격할 준비가 되어 있다.
    여행자도 성안에 들어가야 하는 이유가 있어서 물러설 수 없는 상황이다.
    
    이 대치 상황은 언제든지 폭력으로 이어질 수 있는 위험한 상태이다.
  SITUATION
end

def initial_player_prompt
  
end

def initial_npc_prompt
  "플레이어를 의심하고 있다.
  플레이어가 물러서지 않는다면 무력을 쓸 준비가 되어있다.
  "
end

def dm_character_prompt
  "당신은 TRPG 게임의 DM 입니다. 당신은 세계관 안에서 몰입감 있게 게임의 진행을 책임지고, 맛깔나게 상황을 설명합니다.
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

    ## 임무
    1. 플레이어를 위한 의미있는 선택지 3-5개를 생성하시오
    2. 각 선택지는 명확한 결과와 플레이어의 성격을 반영해야 합니다
    3. 플레이어의 스탯과 특성을 고려하여 선택지를 설계하시오
    4. 스토리를 진행시키고 긴장감을 조성하는 선택지를 만드시오
    5. 현재 상황에 적절한 선택지인지 확인하라
    6. 선택지는 꼭 한글로 작성하라

    ## OUTPUT FORMAT
    Please respond in the following JSON format:
    {
      "scene_description": "Brief description of the new scene",
      "duration": "Estimated duration in seconds",
      "states": [
        {
          "description": "State description",
          "lifespan": "Duration in seconds",
          "choices": [
            {
              "text": "Choice description",
              "consequence": "What this choice might lead to",
              "required_stats": {"physical": 5, "intelligence": 3},
              "trait_influence": "How player traits affect this choice"
            }
          ]
        }
      ]
    }
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
    플레이어는 성안에 들어가야 하는 긴급한 상황이다. 
    
    성 안의 한 장군을 감시하고 의심스러운 행동을 보고하라는 의뢰를 받았다. 
    이는 매우 중요한 임무이며, 성안에 들어가지 못하면 임무를 수행할 수 없다.
    
    약 30분 전, 성문 앞에 도착했을 때 문지기가 자신을 막아섰다. 
    문지기는 신분증이나 입성 허가서를 요구했지만, 플레이어는 그런 것을 가지고 있지 않다.
    
    플레이어는 자신이 무해하다고 강조했지만, 문지기의 질문들에 대해 솔직하게 답변할 수 없었다. 
    "어디서 왔는지", "성안에서 무엇을 하려는지"에 대한 질문에 대해서는 
    진실을 말할 수 없는 사정이 있어서 모호하게 대답할 수밖에 없었다.
    
    문지기는 이런 모호한 답변에 더욱 의심을 품는 것 같았다. 
    플레이어는 문지기가 규율을 중시하는 사람이라는 것을 느낄 수 있었다.
    
    계속해서 입성을 요구했지만, 문지기는 창을 들어 방어 자세를 취했다. 
    플레이어는 이 상황에 놀랐지만, 성안에 들어가야 하는 이유가 있어서 물러설 수 없다.
    
    현재 상황은 매우 긴장되어 있으며, 문지기가 공격할 준비가 되어 있는 것 같다. 
    플레이어는 어떻게든 성안에 들어가야 하는데, 문지기를 설득하거나 다른 방법을 찾아야 한다.
    
    이 임무는 성공해야 하며, 실패할 경우 큰 문제가 생길 수 있다.
  MEMORY
end

def starting_guard_npc_memory()
  <<~MEMORY
    문지기는 5시간동안 성안을 지키고 있다. 
    
    약 30분 전, 한 명의 여행자가 성문 앞에 나타났다. 그 여행자는 성안으로 들어가고 싶다고 했지만, 
    문지기가 신분증이나 입성 허가서를 요구하자 명확한 답변을 하지 못했다. 
    
    여행자는 자신이 무해하다고 강조했지만, 문지기의 질문에 대해 모호하게 대답하거나 
    회피하려는 모습을 보였다. 특히 "어디서 왔는지", "성안에서 무엇을 하려는지"에 대한 
    답변이 불분명했다.
    
    문지기는 이런 모호한 행동에 더욱 의심을 품게 되었다. 
    평소 규율을 중시하는 문지기로서, 명확하지 않은 신원의 사람을 성안에 들이는 것은 
    자신의 직무에 대한 배신이라고 생각한다.
    
    여행자가 계속해서 입성을 요구하자, 문지기는 창을 들어 방어 자세를 취했다. 
    여행자는 놀란 표정을 지었지만, 여전히 물러서지 않았다.
    
    현재 상황은 매우 긴장된 상태이며, 문지기는 여행자가 물러서지 않는다면 
    무력을 사용할 준비가 되어있다.
  MEMORY
end

def guard_npc_description()
  "과묵한 성격이다. 규율을 중시하고 쉽게 속지 않는다.
  창을 무기로 가지고 있고, 갑옷을 입고 있다.
  덩치가 크다.
  플레이어가 물러나지 않는다면 창으로 공격할 준비가 되어있다.
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