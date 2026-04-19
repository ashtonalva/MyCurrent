from build_dataset import build_dataset
from train_model import train
from predict import predict


def run():
    build_dataset()
    train()

    sample = {
        "sleep_index_rate": 0.7,
        "sleep_duration_hours": 6.5,
        "caffeine_intake": 150,
        "time_before_bed_hours": 4,
        "screen_time": 2.0,
        "physical_activity_minutes": 45,
        "steps": 9000,
        "activity_minutes": 70,
        "bed_time": 23,
        "wake_time": 7,
        "sleep_consistency_score": 0.8,
        "sleep_debt": 2,
        "recovery_index": 0.75,
        "caffeine_x_time_before_sleep": 600,
        "activity_balance": 0.8,
        "circadian_alignment": 0.7,
        "age": 22,
    }

    score = predict(sample)
    print(f"Pipeline complete. Sample predicted health score: {score:.2f}")


if __name__ == "__main__":
    run()
