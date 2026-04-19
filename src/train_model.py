import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
import joblib
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATASET_PATH = ROOT / "data" / "processed" / "final_dataset.csv"
MODELS_DIR = ROOT / "models"
MODEL_PATH = MODELS_DIR / "random_forest.pkl"

FEATURES = [
    "sleep_index_rate",
    "sleep_duration_hours",
    "caffeine_intake",
    "time_before_bed_hours",
    "screen_time",
    "physical_activity_minutes",
    "steps",
    "activity_minutes",
    "bed_time",
    "wake_time",
    "sleep_consistency_score",
    "sleep_debt",
    "recovery_index",
    "caffeine_x_time_before_sleep",
    "activity_balance",
    "circadian_alignment",
    "age",
]

def train():
    df = pd.read_csv(DATASET_PATH)
    X = df[FEATURES]
    y = df["health_score"]

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)

    model = RandomForestRegressor(n_estimators=300, max_depth=12, random_state=42)
    model.fit(X_train, y_train)

    print("Model trained")
    print("Train score:", model.score(X_train, y_train))
    print("Test score:", model.score(X_test, y_test))

    os.makedirs(MODELS_DIR, exist_ok=True)
    joblib.dump(model, MODEL_PATH)
    print(f"Saved model -> {MODEL_PATH}")

if __name__ == "__main__":
    train()