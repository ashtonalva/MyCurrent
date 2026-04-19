import pandas as pd
import numpy as np
import os
from pathlib import Path
from data_loader import load_datasets
from feature_engineering import compute_features

ROOT = Path(__file__).resolve().parents[1]
PROCESSED_DIR = ROOT / "data" / "processed"
PROCESSED_PATH = PROCESSED_DIR / "final_dataset.csv"

def normalize_schema(student, lifestyle, fitbit_daily):
    np.random.seed(42)
    df = pd.DataFrame()

    df["person_id"] = student["Student_ID"]
    df["age"] = student["Age"]
    df["sleep_duration_hours"] = student["Sleep_Duration"]
    df["screen_time"] = student["Screen_Time"]
    df["caffeine_intake"] = student["Caffeine_Intake"]
    df["sleep_quality"] = student["Sleep_Quality"]
    df["physical_activity_minutes"] = student["Physical_Activity"]

    df["bed_time"] = student["Weekday_Sleep_Start"].apply(_parse_time_to_hour)
    df["wake_time"] = student["Weekday_Sleep_End"].apply(_parse_time_to_hour)

    steps_series = fitbit_daily["TotalSteps"].sample(
        n=len(df), replace=True, random_state=42
    ).reset_index(drop=True)
    active_minutes = (
        fitbit_daily["VeryActiveMinutes"]
        + fitbit_daily["FairlyActiveMinutes"]
        + fitbit_daily["LightlyActiveMinutes"]
    )
    activity_minutes_series = active_minutes.sample(
        n=len(df), replace=True, random_state=42
    ).reset_index(drop=True)

    df["steps"] = steps_series
    df["activity_minutes"] = activity_minutes_series

    df["caffeine_hour"] = np.clip(
        df["bed_time"] - np.random.uniform(1, 10, len(df)), 0, 23.99
    )

    return df


def _parse_time_to_hour(time_str):
    if isinstance(time_str, (int, float, np.number)):
        return float(time_str) % 24
    value = str(time_str)
    if ":" in value:
        hour, minute = map(int, value.split(":"))
        return (hour + (minute / 60)) % 24
    return float(value) % 24

def generate_health_score(df):
    score = (
        0.25 * df["recovery_index"] +
        0.20 * df["sleep_consistency_score"] +
        0.15 * (1 - df["sleep_debt"] / 8) +
        0.15 * df["activity_balance"] +
        0.10 * (1 - (df["caffeine_x_time_before_sleep"] / (df["caffeine_x_time_before_sleep"].max() + 1e-9))) +
        0.10 * (1 - df["screen_impact"]) +
        0.05 * df["circadian_alignment"]
    )
    return (score * 100).clip(0, 100)

def build_dataset():
    student, lifestyle, fitbit_daily = load_datasets()
    df = normalize_schema(student, lifestyle, fitbit_daily)

    # Feature engineering
    df = compute_features(df)

    # Target
    df["health_score"] = generate_health_score(df)

    processed_df = pd.concat([df] * 5, ignore_index=True)

    for col in processed_df.select_dtypes(include=[np.number]).columns:
        if col not in {"person_id"}:
            processed_df[col] = processed_df[col] + np.random.normal(
                0, 0.03, len(processed_df)
            )

    os.makedirs(PROCESSED_DIR, exist_ok=True)
    processed_df.to_csv(PROCESSED_PATH, index=False)
    print(f"Saved processed dataset -> {PROCESSED_PATH}")

if __name__ == "__main__":
    build_dataset()