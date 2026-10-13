import json
from pathlib import Path

from app.pipeline.runner import compare, summarize

FIXTURES = Path(__file__).resolve().parent.parent / "app" / "fixtures"


def _flags(name: str) -> list[dict]:
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))["flags"]


def test_summary_excludes_supported_claims():
    summary = summarize(_flags("report_v1.json"))
    assert summary["total"] == 4
    assert sum(summary["byCategory"].values()) == 4


def test_rerun_resolves_three_of_four():
    parent = {"flags": _flags("report_v1.json")}
    result = compare(parent, "job_a", _flags("report_v2.json"))
    assert result == {"previousJobId": "job_a", "resolved": 3, "remaining": 1, "newCount": 0}


def test_title_cuts_at_a_word():
    from app.main import _title

    assert _title("\n  Morning routine \n#ad") == "Morning routine"
    long = "The three supplements I take every single morning and why I stopped the fourth"
    assert _title(long) == "The three supplements I take every single morning and why I…"
