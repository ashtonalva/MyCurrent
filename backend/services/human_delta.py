"""
Human Delta layer: wrap feature-engineered trajectories with baseline, deviation,
trend, and confidence for downstream insight generation.

Input: lists of user records (typically last 14 days).
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Any, Iterable, Literal


TrendLabel = Literal["increasing", "decreasing", "stable", "insufficient_data"]

MAX_LOOKBACK_DAYS = 14


@dataclass
class UserRecord:
    """Single observation (feature-engineered row)."""

    sleep_hours: float | None = None
    stress_level: float | None = None
    activity_level: float | None = None
    timestamp: datetime | None = None


def _parse_record(raw: dict[str, Any] | UserRecord) -> UserRecord:
    if isinstance(raw, UserRecord):
        return raw
    ts = raw.get("timestamp")
    if isinstance(ts, str):
        ts = datetime.fromisoformat(ts.replace("Z", "+00:00"))
    return UserRecord(
        sleep_hours=raw.get("sleep_hours"),
        stress_level=raw.get("stress_level"),
        activity_level=raw.get("activity_level"),
        timestamp=ts,
    )


def _normalize_ts(ts: datetime) -> datetime:
    if ts.tzinfo is None:
        return ts.replace(tzinfo=UTC)
    return ts.astimezone(UTC)


def _within_window(ts: datetime, cutoff: datetime) -> bool:
    return _normalize_ts(ts) >= cutoff


def _daily_series(
    records: Iterable[UserRecord],
    *,
    field: Literal["sleep_hours", "stress_level", "activity_level"],
    cutoff: datetime,
) -> list[tuple[datetime.date, float]]:
    """Aggregate to one value per calendar day (mean if multiple rows that day)."""
    buckets: dict[datetime.date, list[float]] = {}
    for r in records:
        if r.timestamp is None:
            continue
        if not _within_window(r.timestamp, cutoff):
            continue
        val = getattr(r, field)
        if val is None:
            continue
        day = _normalize_ts(r.timestamp).date()
        buckets.setdefault(day, []).append(float(val))
    out: list[tuple[datetime.date, float]] = []
    for day, vals in sorted(buckets.items()):
        out.append((day, sum(vals) / len(vals)))
    return out


def _mean(xs: list[float]) -> float | None:
    if not xs:
        return None
    return sum(xs) / len(xs)


def _std(xs: list[float]) -> float:
    if len(xs) < 2:
        return 0.0
    m = sum(xs) / len(xs)
    var = sum((x - m) ** 2 for x in xs) / (len(xs) - 1)
    return var**0.5


def _coefficient_of_variation(xs: list[float]) -> float:
    m = _mean(xs)
    if m is None or abs(m) < 1e-9:
        return float("inf") if xs else 0.0
    return _std(xs) / abs(m)


def _metric_confidence(
    *,
    daily_values: list[float],
    expected_days: int,
) -> float:
    """
    Confidence in [0, 1]: higher when more days present and lower variance (less erratic).
    """
    n = len(daily_values)
    completeness = min(1.0, n / max(expected_days, 1))
    cv = _coefficient_of_variation(daily_values)
    if cv == float("inf") or cv > 2.0:
        consistency = 0.35
    else:
        consistency = 1.0 / (1.0 + cv)

    raw = 0.45 * completeness + 0.55 * consistency
    # Map into bands per spec hint: stable data → ~0.8+, patchy/erratic → ~0.4–0.7
    if raw >= 0.72:
        scaled = 0.78 + 0.22 * min(1.0, (raw - 0.72) / 0.28)
    elif raw >= 0.45:
        scaled = 0.42 + 0.36 * ((raw - 0.45) / 0.27)
    else:
        scaled = 0.25 + 0.17 * (raw / 0.45)
    return round(min(1.0, max(0.0, scaled)), 3)


def _segment_trend(daily_vals: list[float]) -> TrendLabel:
    """
    Compare average of last 3 days vs previous 3 days (requires at least 6 values).
    """
    if len(daily_vals) < 6:
        return "insufficient_data"
    recent = daily_vals[-3:]
    prior = daily_vals[-6:-3]
    a_recent = _mean(recent)
    a_prior = _mean(prior)
    if a_recent is None or a_prior is None:
        return "insufficient_data"
    delta = a_recent - a_prior
    threshold = max(0.05 * (abs(a_prior) + 1e-6), 0.15)
    if delta > threshold:
        return "increasing"
    if delta < -threshold:
        return "decreasing"
    return "stable"


def _metric_context(
    *,
    records: list[UserRecord],
    cutoff: datetime,
    expected_days: int,
    field: Literal["sleep_hours", "stress_level", "activity_level"],
) -> dict[str, Any]:
    series = _daily_series(records, field=field, cutoff=cutoff)
    daily_vals = [v for _, v in series]

    baseline = _mean(daily_vals) if daily_vals else None
    current = daily_vals[-1] if daily_vals else None

    deviation = None
    if current is not None and baseline is not None:
        deviation = round(current - baseline, 4)

    trend = _segment_trend(daily_vals) if daily_vals else "insufficient_data"

    confidence = (
        _metric_confidence(daily_values=daily_vals, expected_days=expected_days)
        if daily_vals
        else 0.25
    )

    return {
        "value": round(current, 4) if current is not None else None,
        "baseline": round(baseline, 4) if baseline is not None else None,
        "deviation": deviation,
        "trend": trend if isinstance(trend, str) else trend,
        "confidence": confidence,
    }


def build_context(
    records: list[dict[str, Any] | UserRecord],
    *,
    lookback_days: int = MAX_LOOKBACK_DAYS,
) -> dict[str, Any]:
    """
    Build structured Human Delta context from the last ``lookback_days`` (default 14).

    Baselines are rolling means over available daily aggregates in that window.
    Trends compare the last 3 daily averages vs the previous 3.
    """
    lookback_days = min(max(lookback_days, 1), MAX_LOOKBACK_DAYS)
    parsed = [_parse_record(r) for r in records]
    now = datetime.now(UTC)
    cutoff = now - timedelta(days=lookback_days)

    ctx_sleep = _metric_context(
        records=parsed,
        cutoff=cutoff,
        expected_days=lookback_days,
        field="sleep_hours",
    )
    ctx_stress = _metric_context(
        records=parsed,
        cutoff=cutoff,
        expected_days=lookback_days,
        field="stress_level",
    )
    ctx_activity = _metric_context(
        records=parsed,
        cutoff=cutoff,
        expected_days=lookback_days,
        field="activity_level",
    )

    return {
        "sleep": ctx_sleep,
        "stress": ctx_stress,
        "activity": ctx_activity,
        "meta": {
            "lookback_days": lookback_days,
            "records_in_window": len(
                [r for r in parsed if r.timestamp and _normalize_ts(r.timestamp) >= cutoff]
            ),
        },
    }
