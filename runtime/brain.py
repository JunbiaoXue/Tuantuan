"""Private, offline JSON-lines decision worker. No screen or document access."""
import contextlib
import json
import sys
import time
import math

ACTIONS = {
    "idle": "sit quietly, watch and blink",
    "explore": "take a short gentle stroll nearby",
    "chase": "playfully approach the pointer, keeping a little distance",
    "ball": "walk over to the toy ball and nudge it",
    "home": "return to the cozy bed and sleep",
}

def choose(model, state):
    start = time.perf_counter()
    options = dict(ACTIONS)
    energy = float(state.get("energy", 0.8))
    if energy > 0.65 and not state.get("quiet_requested"):
        options.pop("home")
    if state.get("last_activity") == "idle" and energy > 0.5 and not state.get("quiet_requested"):
        options.pop("idle", None)
    if float(state.get("pointer_distance", 1000)) > 350:
        options.pop("chase", None)
    if state.get("quiet_requested"):
        options = {key: ACTIONS[key] for key in ("idle", "home")}
    narrative = (f"A pet has {energy:.0%} energy and {float(state.get('trust', 0.35)):.0%} trust in its owner. "
                 f"Its last activity was {state.get('last_activity', 'idle')}. "
                 f"The pointer is {state.get('pointer_distance', 500)} pixels away. "
                 f"Quiet requested: {bool(state.get('quiet_requested'))}. It has a toy ball and a cozy bed.")
    result = model.predict(narrative, {"behavior": {
        "type": "choice",
        "instructions": "Choose one next activity for a curious, shy little pet. Low energy favors home; a close pointer and high trust favor chase. Alternate play and rest. When the user requests quiet, choose idle or home.",
        "criteria": options,
    }})
    answer = result["answers"]["behavior"]
    action = answer["choice"]
    if action not in ACTIONS:
        raise ValueError("unknown behavior")
    probs = answer["probabilities"]
    if any(not math.isfinite(float(probs.get(key, 0))) for key in ACTIONS):
        raise ValueError("nonfinite probability")
    return {"action": action, "probabilities": [{"action": key, "probability": float(probs.get(key, 0))} for key in ACTIONS], "milliseconds": (time.perf_counter() - start) * 1000}

def main():
    with contextlib.redirect_stdout(sys.stderr):
        import laya_mlx
        model = laya_mlx.load(sys.argv[1])
    for line in sys.stdin:
        try:
            with contextlib.redirect_stdout(sys.stderr):
                result = choose(model, json.loads(line))
            print(json.dumps(result), flush=True)
        except Exception as exc:
            print(json.dumps({"error": str(exc)}), flush=True)

if __name__ == "__main__":
    main()
