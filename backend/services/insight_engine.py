"""
Rule-based insight generator: Human Delta context → human-readable insights with causes.
"""

from __future__ import annotations

from typing import Any, TypedDict


class Insight(TypedDict):
    message: str
    confidence: float
    cause: str


def _clamp_confidence(x: float, base: float) -> float:
    return round(min(1.0, max(0.0, 0.5 * base + 0.5 * x)), 3)


def generate_insights(context: dict[str, Any]) -> list[Insight]:
    """
    Convert structured Human Delta context into ranked insights.
    """
    insights: list[Insight] = []

    sleep = context.get("sleep") or {}
    stress = context.get("stress") or {}
    activity = context.get("activity") or {}

    sleep_dev = sleep.get("deviation")
    sleep_trend = sleep.get("trend")
    sleep_conf = float(sleep.get("confidence") or 0.5)

    stress_dev = stress.get("deviation")
    stress_base = stress.get("baseline")
    stress_val = stress.get("value")
    stress_conf = float(stress.get("confidence") or 0.5)

    act_dev = activity.get("deviation")
    act_trend = activity.get("trend")
    act_conf = float(activity.get("confidence") or 0.5)

    # Sleep deficit (below baseline)
    if sleep_dev is not None and sleep_dev < -1.0:
        insights.append(
            Insight(
                message="Your sleep has dropped below your normal levels recently.",
                confidence=_clamp_confidence(sleep_conf, 0.88),
                cause="sleep.deviation",
            )
        )
    if sleep_trend == "decreasing" and sleep_dev is not None and sleep_dev < -0.3:
        insights.append(
            Insight(
                message="Sleep has been trending down compared to your prior few days.",
                confidence=_clamp_confidence(sleep_conf, 0.82),
                cause="sleep.trend_decreasing",
            )
        )

    # Stress spike
    if (
        stress_val is not None
        and stress_base is not None
        and stress_val > stress_base + 1.25
    ):
        insights.append(
            Insight(
                message="Stress is elevated versus your typical baseline.",
                confidence=_clamp_confidence(stress_conf, 0.84),
                cause="stress.above_baseline_threshold",
            )
        )
    if stress_dev is not None and stress_dev > 1.5:
        insights.append(
            Insight(
                message="Stress is meaningfully above your rolling average.",
                confidence=_clamp_confidence(stress_conf, 0.78),
                cause="stress.deviation",
            )
        )

    # Activity / recovery signal
    if act_dev is not None and act_dev < -2.0:
        insights.append(
            Insight(
                message="Physical activity has fallen well below your usual pattern—recovery may suffer.",
                confidence=_clamp_confidence(act_conf, 0.76),
                cause="activity.deviation_low",
            )
        )
    stress_trend = stress.get("trend")
    if act_trend == "increasing" and stress_trend == "increasing":
        insights.append(
            Insight(
                message="Rising activity paired with rising stress—watch total load this week.",
                confidence=_clamp_confidence((act_conf + stress_conf) / 2, 0.72),
                cause="activity_stress.joint_trend",
            )
        )

    # Compound: low sleep + high stress
    if (
        sleep_dev is not None
        and stress_dev is not None
        and sleep_dev < -0.75
        and stress_dev > 0.75
    ):
        insights.append(
            Insight(
                message="Less sleep plus higher stress is likely compounding fatigue.",
                confidence=_clamp_confidence((sleep_conf + stress_conf) / 2, 0.87),
                cause="sleep_stress.compound",
            )
        )

    # Dedupe by cause, keep strongest confidence
    seen: dict[str, Insight] = {}
    for ins in sorted(insights, key=lambda x: -x["confidence"]):
        c = ins["cause"]
        if c not in seen:
            seen[c] = ins

    ordered = sorted(seen.values(), key=lambda x: -x["confidence"])
    return ordered[:8]


def estimate_health_score(context: dict[str, Any]) -> int:
    """
    Lightweight 0–100 score from deviations (not clinical).
    """
    sleep = context.get("sleep") or {}
    stress = context.get("stress") or {}
    activity = context.get("activity") or {}

    score = 72.0
    sd = sleep.get("deviation")
    if sd is not None:
        if sd < -1.5:
            score -= 14
        elif sd < -0.75:
            score -= 8
        elif sd > 0.75:
            score += 4

    std = stress.get("deviation")
    if std is not None:
        if std > 1.5:
            score -= 12
        elif std > 0.75:
            score -= 6

    ad = activity.get("deviation")
    if ad is not None:
        if ad < -2.0:
            score -= 8
        elif ad > 1.0:
            score += 3

    meta = context.get("meta") or {}
    obs = meta.get("records_in_window") or 0
    if obs < 5:
        score -= 5

    return int(max(0, min(100, round(score))))
