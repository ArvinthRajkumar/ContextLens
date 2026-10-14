"""Routes ledger items to the checkers that apply, in parallel (LangGraph),
and collects their candidate flags."""

import asyncio
import json
import logging
import operator
from typing import Annotated, TypedDict

from langgraph.graph import END, START, StateGraph

from ..base import CheckContext
from . import borrowed, claims, disclosure, factcheck
from .candidate import Candidate

STAGE = "checking"
log = logging.getLogger(__name__)


class CheckState(TypedDict):
    ctx: CheckContext
    candidates: Annotated[list[Candidate], operator.add]


def _ledger(state: CheckState) -> list[dict]:
    return state["ctx"].data["ledger"]


def routes(ctx: CheckContext) -> list[str]:
    """Which checkers have work: a pure function of the ledger and the
    declaration, so routing is testable without models."""
    ledger = ctx.data["ledger"]
    wanted: list[str] = []
    if ctx.declaration.get("isPaid") or any(i["type"] in {"material_connection", "promo_offer"} for i in ledger):
        wanted.append("disclosure")
    if any(claims.wants(i) for i in ledger):
        wanted.append("claims")
    if any(i["type"] in factcheck.FACT_TYPES and "startMs" in i for i in ledger):
        wanted.append("factcheck")
    if any(borrowed.has_source(c) for c in ctx.declaration.get("borrowedClips") or []):
        wanted.append("borrowed")
    return wanted or [END]


def _guarded(name: str, node):
    """One checker failing (model capacity, a bad page) must not sink the
    report: its flags are missing, and the job says which checker skipped."""

    async def run(state: CheckState) -> dict:
        try:
            return await node(state)
        except Exception as error:  # noqa: BLE001
            log.warning(json.dumps({"event": "checker_failed", "jobId": state["ctx"].job_id, "checker": name,
                                    "error": type(error).__name__}))
            state["ctx"].data.setdefault("skipped", []).append(name)
            return {"candidates": []}

    return run


async def _disclosure(state: CheckState) -> dict:
    ctx = state["ctx"]
    return {"candidates": disclosure.check(_ledger(state), ctx.duration_ms or 0, ctx.declaration)}


async def _claims(state: CheckState) -> dict:
    ctx = state["ctx"]
    return {"candidates": await asyncio.to_thread(claims.check, ctx, STAGE, _ledger(state), ctx.declaration)}


async def _factcheck(state: CheckState) -> dict:
    return {"candidates": await factcheck.check(state["ctx"], STAGE, _ledger(state))}


async def _borrowed(state: CheckState) -> dict:
    ctx = state["ctx"]
    clips = ctx.declaration.get("borrowedClips") or []
    return {"candidates": await borrowed.check(ctx, STAGE, _ledger(state), ctx.data["transcript"], clips)}


def _build():
    graph = StateGraph(CheckState)
    graph.add_node("disclosure", _guarded("disclosure", _disclosure))
    graph.add_node("claims", _guarded("claims", _claims))
    graph.add_node("factcheck", _guarded("factcheck", _factcheck))
    graph.add_node("borrowed", _guarded("borrowed", _borrowed))
    graph.add_conditional_edges(
        START,
        lambda state: routes(state["ctx"]),
        ["disclosure", "claims", "factcheck", "borrowed", END],
    )
    for node in ("disclosure", "claims", "factcheck", "borrowed"):
        graph.add_edge(node, END)
    return graph.compile()


GRAPH = _build()


async def run(ctx: CheckContext) -> list[Candidate]:
    result = await GRAPH.ainvoke({"ctx": ctx, "candidates": []})
    return result["candidates"]
