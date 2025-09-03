from __future__ import annotations
from typing import List, Dict, Optional, Tuple
from pydantic import BaseModel, Field, model_validator


# ---------------------------------------------------------------------------
# Reusable choice definition (catalog)
# ---------------------------------------------------------------------------
class ChoiceDef(BaseModel):
    id: str
    text: str
    base_probability: float = Field(0.5, ge=0.0, le=1.0)
    rt_factor: float = Field(0.0, ge=0.0, le=1.0)  # time sensitivity


# ---------------------------------------------------------------------------
# A scheduled choice window INSIDE a State (relative to that state's time)
# ---------------------------------------------------------------------------
class StateChoice(BaseModel):
    choice_id: str                 # must exist in Scene.choices
    birth: float = Field(..., ge=0.0)     # seconds since state start (inclusive)
    death: float = Field(..., ge=0.0)     # seconds since state start (inclusive)

    # Optional per-state overrides (text/probability knobs)
    override_text: Optional[str] = None
    base_probability: Optional[float] = Field(None, ge=0.0, le=1.0)
    rt_factor: Optional[float] = Field(None, ge=0.0, le=1.0)

    @model_validator(mode="after")
    def _check_window(self):
        if self.death < self.birth:
            raise ValueError("StateChoice.death must be >= birth")
        return self


# ---------------------------------------------------------------------------
# State = a micro situation + local schedule of choices
# ---------------------------------------------------------------------------
class State(BaseModel):
    id: str
    at: float = Field(..., ge=0.0)         # scene-relative start (seconds)
    duration: float = Field(..., gt=0.0)
    text: str
    choices: List[StateChoice] = Field(default_factory=list)

    @property
    def end(self) -> float:
        return self.at + self.duration


# ---------------------------------------------------------------------------
# Scene = container; States schedule choices; catalog holds reusable defs
# ---------------------------------------------------------------------------
class Scene(BaseModel):
    id: str
    duration: float = Field(..., ge=0.5)          # typically 5–20s
    states: List[State]
    choices: Dict[str, ChoiceDef]                 # catalog: {choice_id: ChoiceDef}

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

            # each state choice window must lie within the state
            for sc in st.choices:
                if sc.birth < 0 or sc.death > st.duration + 1e-6:
                    raise ValueError(
                        f"StateChoice window for '{sc.choice_id}' must be inside state '{st.id}' duration"
                    )
                if sc.choice_id not in self.choices:
                    raise ValueError(f"Unknown choice_id in state '{st.id}': {sc.choice_id}")

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

    def visible_choices(self, t: float) -> List[Tuple[ChoiceDef, StateChoice]]:
        """
        Return list of (catalog_def, state_choice_window) visible at scene time t.
        Windows are state-relative; we convert t to state-local time.
        """
        st = self.active_state(t)
        local_t = t - st.at
        out: List[Tuple[ChoiceDef, StateChoice]] = []
        for sc in st.choices:
            if sc.birth <= local_t <= sc.death:
                out.append((self.choices[sc.choice_id], sc))
        return out

    def resolved_choice_text(self, cd: ChoiceDef, sc: StateChoice) -> str:
        return sc.override_text or cd.text

    def resolved_params(self, cd: ChoiceDef, sc: StateChoice) -> Tuple[float, float]:
        """(base_probability, rt_factor) with per-state overrides applied."""
        bp = cd.base_probability if sc.base_probability is None else sc.base_probability
        rf = cd.rt_factor        if sc.rt_factor is None        else sc.rt_factor
        return bp, rf


# ---------------- Golden dice utility (your formula) ----------------
def golden_probability(base_p: float, rt_factor: float, response_time: float, time_limit: float) -> float:
    # p = base_p * (1 - (response_time * rt_factor) / time_limit)
    p = base_p * (1.0 - (response_time * rt_factor) / max(time_limit, 1e-6))
    return max(0.0, min(1.0, p))
