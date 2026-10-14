from app.pipeline.checks import disclosure, gate
from app.pipeline.checks.alignment import align
from app.pipeline.checks.candidate import Candidate, Evidence
from app.pipeline.checks.clauses import best_sentence, clause_text, scheduled_conditions

PAID = {"caption": "", "isPaid": True, "brandName": "VitaBoost"}


def _ledger(*, caption_label=None, screen=()):
    items = [
        {"id": "L1", "type": "material_connection", "source": "speech", "text": "VitaBoost sent me these,",
         "startMs": 6_700, "endMs": 8_500, "subject": "VitaBoost"},
        {"id": "L2", "type": "promo_offer", "source": "speech", "text": "use code Priya 20 for Rs 200 off.",
         "startMs": 8_600, "endMs": 12_000},
    ]
    for start, end in screen:
        items.append({"type": "disclosure_label", "source": "screen", "text": "#ad", "startMs": start, "endMs": end})
    if caption_label:
        items.append({"type": "disclosure_label", "source": "caption", "text": "#ad", **caption_label})
    return items


# Disclosure rules


def test_required_duration_by_video_length():
    assert disclosure.required_ms(15_000, None) == (3_000, "asci-ig/1.2(d)(I)")
    assert disclosure.required_ms(40_400, None) == (13_467, "asci-ig/1.2(d)(II)")
    assert disclosure.required_ms(150_000, (20_000, 65_000)) == (45_000, "asci-ig/1.2(d)(III)")


def test_overlapping_label_intervals_count_once():
    assert disclosure.visible_ms([(0, 2_000), (1_000, 3_000), (5_000, 6_000)]) == 4_000
    assert disclosure.covered_ms([(0, 10_000), (30_000, 40_000)], (5_000, 35_000)) == 10_000


def test_supplements_case_flags_buried_caption_and_short_late_label():
    ledger = _ledger(caption_label={"upFront": False, "hashtagPosition": 4, "hashtagCount": 4}, screen=[(38_500, 40_000)])
    flags = [c.flag for c in disclosure.check(ledger, 40_400, PAID)]
    assert [f["citation"]["clauseId"] for f in flags] == ["asci-ig/1.2(c)", "asci-ig/1.2(d)(II)"]
    timing = flags[1]
    assert timing["title"] == "On-screen Ad label is too short and too late"
    assert "1.5 s" in timing["evidence"] and "13.5 s" in timing["evidence"]
    assert timing["severity"] == "high"
    assert "0:06" in timing["suggestedFix"]


def test_label_up_front_and_long_enough_passes():
    ledger = _ledger(caption_label={"upFront": True, "hashtagPosition": None, "hashtagCount": 0}, screen=[(6_000, 21_000)])
    assert disclosure.check(ledger, 40_400, PAID) == []


def test_no_labels_anywhere_is_high_severity():
    flags = [c.flag for c in disclosure.check(_ledger(), 12_000, PAID)]
    assert [f["citation"]["clauseId"] for f in flags] == ["asci-ig/1", "asci-ig/1.2(d)(I)"]
    assert {f["severity"] for f in flags} == {"high"}


def test_short_video_needs_three_seconds():
    ledger = _ledger(caption_label={"upFront": True}, screen=[(1_000, 3_500)])
    [flag] = [c.flag for c in disclosure.check(ledger, 12_000, PAID)]
    assert flag["title"] == "On-screen Ad label is too short"


def test_long_video_label_must_cover_the_promoted_part():
    ledger = _ledger(caption_label={"upFront": True}, screen=[(0, 9_000)])
    ledger[1]["endMs"] = 150_000
    [flag] = [c.flag for c in disclosure.check(ledger, 180_000, PAID)]
    assert flag["citation"]["clauseId"] == "asci-ig/1.2(d)(III)"


def test_no_connection_no_disclosure_check():
    assert disclosure.check([{"type": "health_claim", "text": "x", "startMs": 0, "endMs": 1}], 30_000, {"isPaid": False}) == []


# Evidence gate

SOURCES = gate.Sources(
    transcript="Hi everyone. Vita Boost sent me these, so use code Priya 20 for Rs 200 off.",
    screen="Code PRIYA20: ₹200 off | #ad",
    caption="3 supplements #wellness #ad",
    pages={"https://example.org/review": "Regular vitamin C did not reduce how often people caught colds."},
)


def _candidate(*evidence, facts=()):
    flag = {"category": "claims", "evidence": "You say it stops colds.", "sourceQuote": {"text": evidence[0].quote, "source": "x"}}
    return Candidate(flag, list(evidence), grounding_facts=list(facts))


def test_gate_passes_verbatim_spans_ignoring_case_and_punctuation():
    candidate = _candidate(Evidence("clause", "Disclosure should not be buried in a group of hashtags or links.", "asci-ig/1.2(c)"),
                           Evidence("transcript", "vita boost sent me these"), Evidence("screen", "#ad"))
    flag = gate.apply(candidate, SOURCES, grounding=lambda *_: None)
    assert "uncertain" not in flag and flag["sourceQuote"]


def test_gate_downgrades_a_paraphrased_clause_quote():
    candidate = _candidate(Evidence("clause", "Disclosures must not be hidden among hashtags.", "asci-ig/1.2(c)"))
    flag = gate.apply(candidate, SOURCES, grounding=lambda *_: None)
    assert flag["uncertain"] is True
    assert "sourceQuote" not in flag
    assert candidate.gate_notes == ["clause: quote not found"]


def test_gate_downgrades_words_never_said():
    flag = gate.apply(_candidate(Evidence("transcript", "this cures diabetes")), SOURCES, grounding=lambda *_: None)
    assert flag["uncertain"] is True


def test_gate_needs_the_page_to_have_been_fetched():
    ok = _candidate(Evidence("page", "did not reduce how often people caught colds", "https://example.org/review"))
    missing = _candidate(Evidence("page", "did not reduce how often people caught colds", ""))
    assert "uncertain" not in gate.apply(ok, SOURCES, grounding=lambda *_: None)
    assert gate.apply(missing, SOURCES, grounding=lambda *_: None)["uncertain"] is True


def test_gate_uses_grounding_as_a_second_signal():
    spans = (Evidence("page", "did not reduce how often people caught colds", "https://example.org/review"),)
    weak = gate.apply(_candidate(*spans, facts=["fact"]), SOURCES, grounding=lambda *_: 0.2)
    strong = gate.apply(_candidate(*spans, facts=["fact"]), SOURCES, grounding=lambda *_: 0.9)
    unreachable = gate.apply(_candidate(*spans, facts=["fact"]), SOURCES, grounding=lambda *_: None)
    assert weak["uncertain"] is True and weak["sourceQuote"]
    assert "uncertain" not in strong and "uncertain" not in unreachable


def test_gate_skips_grounding_for_deterministic_flags():
    calls = []
    gate.apply(_candidate(Evidence("screen", "#ad")), SOURCES, grounding=lambda *a: calls.append(a) or 0.0)
    assert calls == []


def test_clause_quote_repair_only_when_close():
    text = "Disclosure should not be buried in a group of hashtags or links."
    assert best_sentence("asci-ig/1.2(c)", "Disclosure should not be burried in a group of hashtags or links.") == text
    assert best_sentence("asci-ig/1.2(c)", "buried in a group of hashtags") == "buried in a group of hashtags"
    assert best_sentence("asci-ig/1.2(c)", "Labels go first") is None
    assert "Schedule" in clause_text("dmr-act/3(d)")


def test_scheduled_conditions():
    assert scheduled_conditions("I barely need my diabetes tablets now") == ["Diabetes"]
    assert scheduled_conditions("my BP is normal") == ["High or low blood pressure"]
    assert scheduled_conditions("I feel more energetic") == []


# Borrowed clip alignment

SOURCE = (
    "Thanks for having me. Vitamin D is something everyone should be taking daily if a blood test "
    "shows they're deficient. Too much of it can be harmful. But for most people sunlight is enough. "
    "We also talked about sleep."
)


def test_trimmed_condition_shows_as_a_deletion():
    result = align("Vitamin D is something everyone should be taking daily.", SOURCE)
    assert result is not None and result.cut_mid_sentence
    assert {"op": "delete", "text": " if a blood test shows they're deficient."} in result.segments
    assert result.segments[0] == {"op": "equal", "text": "Vitamin D is something everyone should be taking daily"}
    assert result.changes_meaning


def test_splice_is_detected():
    result = align("Vitamin D is something everyone should be taking daily, for most people sunlight is enough.", SOURCE)
    assert result is not None and result.splices
    assert result.splices[0].startswith("if a blood test")


def test_omitted_qualifier_sentence():
    result = align("Too much of it can be harmful.", SOURCE)
    assert result is not None
    assert result.omitted_next == "But for most people sunlight is enough."
    assert not result.splices and not result.cut_mid_sentence


def test_faithful_clip_is_not_flagged():
    result = align("We also talked about sleep.", SOURCE)
    assert result is not None and not result.changes_meaning


def test_unrelated_clip_does_not_align():
    assert align("Mutual funds are subject to market risks.", SOURCE) is None


# Report


def test_contradicted_fact_check_replaces_the_substantiation_flag():
    from app.pipeline.real import dedupe

    substantiation = {"category": "claims", "startMs": 1, "endMs": 2, "citation": {"clauseId": "asci-code/I.1.1"}}
    statutory = {"category": "claims", "startMs": 1, "endMs": 2, "citation": {"clauseId": "dmr-act/3(d)"}}
    contradicted = {"category": "factcheck", "startMs": 1, "endMs": 2, "factLabel": "contradicted"}
    assert dedupe([substantiation, statutory, contradicted]) == [statutory, contradicted]
    uncertain = {**contradicted, "uncertain": True}
    assert dedupe([substantiation, uncertain]) == [substantiation, uncertain]


# Fact check sources


def test_quote_attributed_by_grounding_support():
    from app.pipeline.checks.factcheck import _attributed
    from app.pipeline.gemini import Support

    quote = "Regular vitamin C supplementation did not reduce the incidence of colds in the general population."
    supports = [
        Support('"quote": "Regular vitamin C supplementation did not reduce the incidence of colds in the general population.",', (1, 2), (0.62, 0.91)),
        Support("Vitamin C may shorten colds a little.", (0,), (0.99,)),
    ]
    assert _attributed(quote, supports, 3) == 2
    assert _attributed(quote, supports, 2) is None  # source 2 was never retrieved
    weak = [Support(supports[0].text, (1,), (0.5,))]
    assert _attributed(quote, weak, 3) is None
    assert _attributed("Vitamin C cures colds instantly in every single person who takes it daily.", supports, 3) is None


def test_trusted_sources():
    from app.pipeline.checks.factcheck import trusted

    assert trusted("pib.gov.in") and trusted("https://www.icmr.gov.in/x") and trusted("www.boomlive.in")
    assert not trusted("example.org") and not trusted("https://notgov.in.evil.com/")


def test_gate_accepts_a_grounding_span():
    span = "Grounding text: regular vitamin C did not reduce the incidence of colds in the general population."
    sources = gate.Sources("", "", "", {"grounding:https://www.nih.gov/x": span})
    candidate = _candidate(Evidence("grounding", "did not reduce the incidence of colds", "grounding:https://www.nih.gov/x"))
    assert "uncertain" not in gate.apply(candidate, sources, grounding=lambda *_: None)


def test_routing_does_not_depend_on_the_models_checks_list():
    from app.pipeline.base import CheckContext
    from app.pipeline.checks.router import routes

    ctx = CheckContext("j", "u", "o", {"isPaid": False})
    ctx.data["ledger"] = [{"type": "health_claim", "text": "Vitamin C stops colds", "startMs": 0, "endMs": 1, "checks": ["claims"]}]
    assert routes(ctx) == ["claims", "factcheck"]
    ctx.data["ledger"] = [{"type": "promo_offer", "text": "Rs 599", "startMs": 0, "endMs": 1, "checks": ["disclosure"]}]
    assert routes(ctx) == ["disclosure"]


def test_a_failing_checker_is_skipped_not_fatal():
    import asyncio

    from app.pipeline.base import CheckContext
    from app.pipeline.checks.router import _guarded

    async def broken(state):
        raise RuntimeError("model unavailable")

    ctx = CheckContext("j", "u", "o", {})
    result = asyncio.run(_guarded("factcheck", broken)({"ctx": ctx, "candidates": []}))
    assert result == {"candidates": []}
    assert ctx.data["skipped"] == ["factcheck"]
