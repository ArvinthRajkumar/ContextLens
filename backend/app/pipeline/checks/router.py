"""Routes ledger items to the checkers that apply, in parallel (LangGraph),
and collects their candidate flags."""

import asyncio
import operator
from typing import Annotated, TypedDict

from langgraph.graph import END, START, StateGraph

from ..base import CheckContext
from . import borrowed, claims, disclosure, factcheck
from .candidate import Candidate

STAGE = "checking"


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
    if any(i["type"] in claims.CLAIM_TYPES and "claims" in i.get("checks", []) for i in ledger):
        wanted.append("claims")
    if any(i["type"] in factcheck.FACT_TYPES and "factcheck" in i.get("checks", []) for i in ledger):
        wanted.append("factcheck")
    if any(c.get("url") for c in ctx.declaration.get("borrowedClips") or []):
        wanted.append("borrowed")
    return wanted or [END]


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
    graph.add_node("disclosure", _disclosure)
    graph.add_node("claims", _claims)
    graph.add_node("factcheck", _factcheck)
    graph.add_node("borrowed", _borrowed)
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
