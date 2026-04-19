import pandas as pd
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "data" / "raw"

def load_datasets():
    student = pd.read_csv(RAW_DIR / "student_sleep_patterns.csv")
    lifestyle = pd.read_csv(RAW_DIR / "Sleep_health_and_lifestyle_dataset.csv")
    fitbit_daily = pd.read_csv(
        RAW_DIR / "mturkfitbit_export_4.12.16-5.12.16" /
        "Fitabase Data 4.12.16-5.12.16" / "dailyActivity_merged.csv"
    )

    return student, lifestyle, fitbit_daily