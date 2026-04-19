import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

from predict import predict
from train_model import FEATURES


ROOT = Path(__file__).resolve().parents[1]
RUNTIME_DIR = ROOT / "data" / "runtime"
DEFAULT_INPUT = RUNTIME_DIR / "ml_input.json"
DEFAULT_OUTPUT = RUNTIME_DIR / "ml_output.json"
APP_FALLBACK_OUTPUT = ROOT / "MyCurrent" / "MyCurrent" / "ml_latest_prediction.json"


def load_input(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        payload = json.load(f)
    return {feature: payload.get(feature, 0) for feature in FEATURES}


def save_output(path: Path, score: float) -> None:
    payload = {
        "predicted_health_score": float(score),
        "model": "random_forest.pkl",
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)


def run(input_path: Path, output_path: Path, copy_to_app: bool) -> None:
    model_input = load_input(input_path)
    score = predict(model_input)
    save_output(output_path, score)
    print(f"Saved ML output -> {output_path}")
    if copy_to_app:
        save_output(APP_FALLBACK_OUTPUT, score)
        print(f"Copied app fallback output -> {APP_FALLBACK_OUTPUT}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run ML bridge prediction from JSON input.")
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--copy-to-app", action="store_true")
    args = parser.parse_args()
    run(args.input, args.output, args.copy_to_app)
