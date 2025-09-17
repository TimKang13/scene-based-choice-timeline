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


def context_prompt(situation, player, npc)
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
  PROMPT
end

def build_player_context(player)
  <<~CONTEXT
    Name: #{player.name}
    Age: #{player.age}
    Sex: #{player.sex}
    Species: #{player.species}
    
    Stats:
    - 신체: #{player.stats.physical}/20
    - 지능: #{player.stats.intelligence}/20  
    - 언변: #{player.stats.speech}/20
    
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

def initial_outcome_prompt 
  <<~OUTCOME
    경비병과 플레이어가 성 밖에서 대치중이다.
  OUTCOME
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
    
    IMPORTANT SEPARATION:
    - STATES = NPC/environment timeline if the player stays frozen (no player actions).
    - CHOICES = Player actions that can interrupt or redirect that timeline.

    CHOICE can belong to multiple STATEs, if the CHOICE is valid for multiple STATEs.
    CHOICE is a possible action the player can take, in response to the STATE and the overall situation

    ## REQUIREMENTS
    1. Create 3-7 creative, intuitive choices
    2. **CRITICAL**: Player has only 5 seconds to read state text, understand choices, and decide
    3. State should be a sentence. must be concise but specific - maximum 10-15 words
    4. Choice text must be under 5 words - direct action verbs preferred, with specific objective and target subjects
    5. Consider player stats (Physical, Intelligence, Speech) and traits
    6. Make choices advance the story and build tension
    7. Ensure timing makes sense for the situation
    8. Make several states, for example, a scene might have states at 0s (initial situation), 3s (escalation), and 6s (climax) to show how the situation changes over time
    

    ## READING TIME RULES
    - At the start of EACH state, the scene timer PAUSES for a brief reading countdown.
    - total_time_to_read(state) = state.time_to_read + sum(choice.time_to_read for choices visible in that state)
    - During this countdown, choices are not selectable; after it ends, the scene resumes.

    ## OUTPUT FORMAT
    Respond with this EXACT JSON structure (include time_to_read fields):
    {
      "id": "unique_scene_id",
      "duration": time it takes for the scene to play out,
      "states": [
        {
          "id": "state_1",
          "at": 0,
          "duration": duration for this state,
          "text": "first state text",
          "time_to_read": 2.0
        },
        {
          "id": "state_2",
          "at": where this state starts,
          "duration": duration for this state,
          "text": "second state, as result of inaction of player. ex) getting impatient",
          "time_to_read": 1.8
        },
        {
          "id": "state_3",
          "at": where this state starts,
          "duration": duration for this state,
          "text": "third state, as result of inaction of player. ex) getting impatient",
          "time_to_read": 2.6
        }
      ],
      "choices": [
        {
          "id": "choice_1",
          "text": "(재밌는 선택)",
          "state_ids": ["state_1", "state_2"],
          "time_to_read": 0.6
        },
        {
          "id": "choice_2",
          "text": "(침착한 선택)",
          "state_ids": ["state_2", "state_3"],
          "time_to_read": 0.5
        },
        {
          "id": "choice_3",
          "text": "(정석 선택)",
          "state_ids": ["state_1", "state_2", "state_3"],
          "time_to_read": 0.4
        },
        {
          "id": "choice_4",
          "text": "(아이템 사용 선택)",
          "state_ids": ["state_3"],
          "time_to_read": 0.5
        }
      ],
      "reading_time_estimate": 6,
    }
    
    ## STATE GUIDELINES
    - Each state should represent a distinct phase of the scene
    - States should build tension or change the situation meaningfully
    - Use "at" field to specify when each state begins (in seconds)
    - **CRITICAL**: State text must be brief but action packed - 10-15 words maximum
    - **CRITICAL**: Following state assumes that the player did not act yet to the previous state
    - **ABSOLUTE RULE**: States describe ONLY NPC or environment actions. No player actions.
      - Prohibited in state text: "you", "your", "player", second-person imperatives (e.g., "Dodge", "Grab", "Speak"), or any verb implying player action.
      - Use third-person subjects like "Guard", "Crowd", "Gate", "Spear", "Wind", "Rain".
      - Think of states as the "background reel" that plays if the player does nothing.
      - Bad (NOT allowed): "You step back and ready your blade."
      - Good (Allowed): "Guard steps in and lifts their spear higher. Crowd hushes."

    - Use short, punchy sentences. No flowery descriptions.
    - Focus on immediate threats, actions, and consequences
    - States no longer contain choices directly - choices are assigned via state_ids
    - Example state progression:
      state 1: "Guard blocks path. Spear raised. Demands ID."
      state 2: "Guard steps closer. Final warning. Spear tip glints."
      state 3: "Guard lunges! Spear thrusts toward you. NOW!"

    ### SELF-CHECK BEFORE OUTPUT
    For each state.text, verify ALL are true; if any fail, rewrite before returning JSON:
    - Contains NO "you", "your", or "player".
    - Contains NO imperative phrasing targeting the player (e.g., "Dodge", "Run", "Speak").
    - Subjects are NPC/environmental; actions proceed even if the player is frozen.

    ## CHOICE GUIDELINES
    - **CRITICAL**: Choice text must be under 5 words - direct action verbs preferred. be specific, succint, packed with action
    - Make each choice distinct and memorable
    - Consider player's traits and stats...!
    - Item usage is fun! Good to include
    - Each choice should have clear risk/reward dynamics
    - **CRITICAL**: Choices are defined at the scene level and assigned to states via state_ids
    - Choices can span multiple states for better persistence and player agency
    - Each choice should be contextually appropriate for states it's assigned to
    - Certain specific choices may only be available in specific states (single state_ids)
    Create creative and engaging choices that make sense across their assigned states.
    You are the DM! Make absurd and unorthodox choices to blow people's minds.
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
    
    ## OUTPUT FORMAT (JSON)
    Respond with ONLY this JSON object (no prose):
    {
      "outcome_description": "Detailed description of what happened as a result of the choice",
      "updated_player_memory": "How this experience affects the player's memory",
      "updated_npc_memory": "How this experience affects the NPC's memory",
      "updated_situation": "The new situation that emerges from this choice"
    }
  PROMPT
end

def success_criteria_prompt(player_choice, current_situation, player, npc, decision_time_seconds)
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
    
    ## DECISION TIME (SECONDS)
    #{decision_time_seconds}
    
    ## YOUR TASK
    1. Analyze the difficulty of the player's choice based on the current situation
    2. Consider the player's stats, traits, current circumstances, and DECISION TIME as a factor
    3. Produce thresholds for the following outcomes: big success, success, small failure, big failure
    4. Make thresholds realistic and meaningful to the story
    
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
    - Time pressure and urgency, and player's decision time (slower decisions under urgency should tend to increase difficulty; split-second choices in reflex contexts may reduce difficulty for physical actions)
    - Previous actions and their consequences
    
    ## OUTPUT FORMAT (JSON)
    Respond with ONLY this JSON object (no prose):
    {
      "big_success_threshold": ,
      "success_threshold": ,
      "small_failure_threshold": ,
      "reasoning": "Brief rationale referencing decision time, stats/traits, and situation."
    }
    
    ## IMPORTANT
    - All thresholds are integers in [1, 20].
    - Interpret outcomes as:
      - roll >= big_success_threshold => huge success (very rare, lottery-like)
      - else if roll >= success_threshold => success
      - else if roll < small_failure_threshold => big failure (very rare, catastrophe)
      - else => failure
    - Enforce sensible ordering: 20 >= big_success_threshold >= success_threshold >= 1 and 1 <= small_failure_threshold <= success_threshold.
    - Weigh decision_time_seconds: under strong urgency, longer decision times should trend toward higher success_threshold and higher chance of big failure (by raising thresholds or lowering small_failure_threshold appropriately).
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
    - Category: #{dice_result[:category]}
    
    ## CURRENT SITUATION
    #{current_situation}
    
    ## PLAYER CONTEXT
    #{build_player_context(player)}
    
    ## PLAYER MEMORY (CURRENT)
    #{player.memory}
    
    ## NPC CONTEXT
    #{build_npc_context(npc)}
    
    ## NPC MEMORY (CURRENT)
    #{npc.memory}
    
    ## YOUR TASK
    1. Generate a succint outcome description based on the dice result
    2. Consider how success/failure affects the current situation
    3. Update player and NPC memories based on the outcome
    4. Generate a new situation that emerges from this outcome
    5. Make the consequences meaningful and impactful to the story
    
    ## SUCCESS vs FAILURE GUIDELINES
    - **SUCCESS**: The player's action achieves its intended goal, but may have unexpected consequences
    - **FAILURE**: The player's action doesn't achieve its goal, but may open new opportunities or create interesting complications
    
    ## OUTPUT FORMAT (JSON)
    Respond with ONLY this JSON object (no prose):
    {
      "outcome_description": "MAX 3 sentences.Vivid novel like description of what happened as a result of the dice roll. Succint but descriptive.",
      "updated_situation": "MAX 1 sentence.The new situation that emerges from this outcome. Focused on what could happen next.",
      "updated_player_memory": "How this experience affects the player's memory and understanding",
      "updated_npc_memory": "How this experience affects the NPC's memory and disposition"
    }
    
    ## IMPORTANT
    - Make the outcome realistic and story-appropriate
    - Consider the player's traits and how they might react to success/failure
    - The new situation should naturally flow from the outcome
    - Keep the story engaging and maintain narrative tension
  PROMPT
end


def dice_prompt(player_choice, current_situation, player, npc)
  <<~PROMPT
    You are the Game Master (GM) determining the dice threshold for a player's choice in a text-based RPG.
    4 outcomes: big success, success, small failure, big failure
    and you are to generate the threshold for each outcome.

    Out of dice of 20,
    roll of big_success_threshold or higher is big success.
    roll of success_threshold or higher is success.
    roll of small_failure_threshold or higher is small failure.
    roll below big_failure_threshold is big failure.
    
    ## PLAYER'S CHOICE
    #{player_choice}
    
    ## CURRENT SITUATION
    #{current_situation}
  PROMPT
end