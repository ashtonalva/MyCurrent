import numpy as np
import pandas as pd


def to_hour(time_str):
    h, m = map(int, str(time_str).split(":"))
    return h + (m / 60)


def compute_features(df):
    df = df.copy()
    bedtime_hours = pd.to_numeric(df["bed_time"], errors="coerce")
    wake_hours = pd.to_numeric(df["wake_time"], errors="coerce")
    sleep_hours = pd.to_numeric(df["sleep_duration_hours"], errors="coerce")
    caffeine_intake = pd.to_numeric(df["caffeine_intake"], errors="coerce")
    steps = pd.to_numeric(df["steps"], errors="coerce")
    activity_minutes = pd.to_numeric(df["activity_minutes"], errors="coerce")
    screen_time = pd.to_numeric(df["screen_time"], errors="coerce")

    df["sleep_index_rate"] = pd.to_numeric(df["sleep_quality"], errors="coerce") / 10.0
    df["sleep_debt"] = np.maximum(0, 8 - sleep_hours)
    df["recovery_index"] = sleep_hours / 8.0

    consistency_std = sleep_hours.groupby(df["person_id"]).transform("std").fillna(0.0)
    df["sleep_consistency_score"] = 1 / (1 + consistency_std)

    df["time_before_bed_hours"] = (bedtime_hours - df["caffeine_hour"]) % 24
    df["caffeine_x_time_before_sleep"] = caffeine_intake * df["time_before_bed_hours"]

    df["screen_impact"] = (screen_time / 6).clip(0, 1)

    optimal_steps = 8000
    step_balance = 1 - (abs(steps - optimal_steps) / optimal_steps)
    minute_balance = 1 - (abs(activity_minutes - 60) / 60)
    df["activity_balance"] = ((step_balance + minute_balance) / 2).clip(0, 1)

    mid_sleep = (bedtime_hours + ((wake_hours + 24) % 24)) / 2
    df["circadian_alignment"] = (1 - (abs(mid_sleep - 3) / 12)).clip(0, 1)

    return df