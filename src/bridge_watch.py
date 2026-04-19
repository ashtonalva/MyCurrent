import argparse
import time
from pathlib import Path

from bridge_predict import run, DEFAULT_INPUT, DEFAULT_OUTPUT


def watch(input_path: Path, output_path: Path, poll_seconds: float, copy_to_app: bool) -> None:
    print(f"Watching ML input: {input_path}")
    last_mtime = None

    while True:
        try:
            if input_path.exists():
                current_mtime = input_path.stat().st_mtime
                if last_mtime is None or current_mtime > last_mtime:
                    run(input_path=input_path, output_path=output_path, copy_to_app=copy_to_app)
                    last_mtime = current_mtime
            time.sleep(poll_seconds)
        except KeyboardInterrupt:
            print("Stopped ML bridge watcher.")
            break
        except Exception as exc:
            print(f"Watcher error: {exc}")
            time.sleep(poll_seconds)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Watch ML input JSON and auto-run prediction.")
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--poll-seconds", type=float, default=1.0)
    parser.add_argument("--copy-to-app", action="store_true")
    args = parser.parse_args()
    watch(
        input_path=args.input,
        output_path=args.output,
        poll_seconds=args.poll_seconds,
        copy_to_app=args.copy_to_app,
    )
