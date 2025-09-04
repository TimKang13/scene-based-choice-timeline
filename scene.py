from __future__ import annotations
from typing import List, Dict, Optional, Tuple
from pydantic import BaseModel, Field, model_validator


# ---------------------------------------------------------------------------
# Choice = choice definition with timing window
# ---------------------------------------------------------------------------
class Choice(BaseModel):
    id: str
    text: str
    
    # State-specific timing window
    birth: float = Field(..., ge=0.0)     # seconds since state start (inclusive)
    death: float = Field(..., ge=0.0)     # seconds since state start (inclusive)
    
    # Optional per-state overrides
    override_text: Optional[str] = None
    
    @model_validator(mode="after")
    def _check_window(self):
        if self.death < self.birth:
            raise ValueError("Choice.death must be >= birth")
        return self


# ---------------------------------------------------------------------------
# State = a micro situation + local schedule of choices
# ---------------------------------------------------------------------------
class State(BaseModel):
    id: str
    at: float = Field(..., ge=0.0)         # scene-relative start (seconds)
    duration: float = Field(..., gt=0.0)
    text: str
    choices: List[Choice] = Field(default_factory=list)

    @property
    def end(self) -> float:
        return self.at + self.duration


# ---------------------------------------------------------------------------
# Scene = container; States contain choices directly
# ---------------------------------------------------------------------------
class Scene(BaseModel):
    id: str
    duration: float = Field(..., ge=0.5)          # typically 5–20s
    states: List[State]

    # optional UX
    reading_time_estimate: Optional[float] = None
    decision_deadline: Optional[float] = None

    @model_validator(mode="after")
    def _validate(self):
        dur = float(self.duration)

        if not self.states:
            raise ValueError("Scene.states cannot be empty")

        # states sorted and within scene bounds
        times = [st.at for st in self.states]
        if times != sorted(times):
            raise ValueError("States must be sorted by 'at'")
        for st in self.states:
            if st.at < 0 or st.end > dur + 1e-6:
                raise ValueError(f"State '{st.id}' exceeds scene duration")

            # each choice window must lie within the state
            for choice in st.choices:
                if choice.birth < 0 or choice.death > st.duration + 1e-6:
                    raise ValueError(
                        f"Choice window for '{choice.id}' must be inside state '{st.id}' duration"
                    )

        if self.decision_deadline is not None and self.decision_deadline > dur:
            raise ValueError("decision_deadline cannot exceed scene duration")

        return self

    # ---------------- Runtime helpers ----------------

    def active_state(self, t: float) -> State:
        """State whose window covers scene time t (seconds)."""
        candidates = [st for st in self.states if st.at <= t <= st.end]
        if not candidates:
            past = [st for st in self.states if st.at <= t]
            return (sorted(past, key=lambda s: s.at)[-1]
                    if past else sorted(self.states, key=lambda s: s.at)[0])
        return sorted(candidates, key=lambda s: s.at)[-1]

    def visible_choices(self, t: float) -> List[Choice]:
        """
        Return list of choices visible at scene time t.
        Windows are state-relative; we convert t to state-local time.
        """
        st = self.active_state(t)
        local_t = t - st.at
        out: List[Choice] = []
        for choice in st.choices:
            if choice.birth <= local_t <= choice.death:
                out.append(choice)
        return out

    def resolved_choice_text(self, choice: Choice) -> str:
        return choice.override_text or choice.text


# Note: Golden dice probability is now determined by LLM after choice is made
# based on: choice made, timing, and current situation
