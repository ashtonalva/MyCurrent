"""
FastAPI entry: feature records → Human Delta context → insight engine.

Run locally:
    uvicorn backend.main:app --reload --app-dir .
"""

from __future__ import annotations

from datetime import datetime

from fastapi import FastAPI, Query
from pydantic import BaseModel, Field

from backend.services.human_delta import build_context
from backend.services.insight_engine import estimate_health_score, generate_insights

app = FastAPI(title="MyCurrent Human Delta API", version="1.0.0")


class UserRecordIn(BaseModel):
    sleep_hours: float | None = None
    stress_level: float | None = None
    activity_level: float | None = None
    timestamp: datetime


class InsightsRequest(BaseModel):
    records: list[UserRecordIn] = Field(..., description="Up to ~14 days of daily or intra-day samples")


class InsightOut(BaseModel):
    message: str
    confidence: float
    cause: str


class InsightsResponse(BaseModel):
    health_score: int
    insights: list[InsightOut]
    context: dict | None = None


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/insights", response_model=InsightsResponse)
def post_insights(
    body: InsightsRequest,
    include_context: bool = Query(False, description="Include Human Delta context object in response"),
) -> InsightsResponse:
    raw_records = [r.model_dump() for r in body.records]
    context = build_context(raw_records, lookback_days=14)
    insights = generate_insights(context)
    score = estimate_health_score(context)

    return InsightsResponse(
        health_score=score,
        insights=[
            InsightOut(message=i["message"], confidence=i["confidence"], cause=i["cause"])
            for i in insights
        ],
        context=context if include_context else None,
    )


@app.post("/human-delta/context")
def post_context_only(body: InsightsRequest) -> dict:
    raw_records = [r.model_dump() for r in body.records]
    return build_context(raw_records, lookback_days=14)
