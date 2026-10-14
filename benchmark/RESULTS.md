# ContextLens benchmark results

Run on 2026-10-14 against the deployed pipeline (Cloud Run revision `contextlens-api-00024-g59`, `PIPELINE_MODE=real`, `gemini-2.5-flash` in `us-central1`), 34 cases, 3 at a time, every case sent through the same API the app uses (`benchmark/run.py`).

**Read this first: the reels are synthetic.** Each one is a recreation, not a real creator's video: a script written to match a type of case ASCI handles (undisclosed promotion, late or buried label, gifted product, cure claims, Drugs and Magic Remedies Act conditions, guaranteed returns, before and after), voiced with Gemini TTS, laid over one stock clip, with overlays burned in. The fact-check claims are real claims that Indian fact-checkers rated, but the reels that say them are synthetic too. 34 cases is small, and we wrote both the cases and the system, so treat these numbers as a smoke test of the method, not a measure of real-world accuracy.

## Cases

| Set | Cases | What it tests |
|---|---|---|
| Compliance reels | 12 (C01 to C12) | Disclosure rules and claims against the clause index, with expected flags and clause IDs |
| Clean controls | 4 (K1 to K4) | No disclosure or claims flags should appear |
| Borrowed-clip pairs | 6 (B01 to B06): 4 clipped (splice, cut mid-sentence, omitted qualifier, words dropped at the start), 2 faithful | Alignment of a clip with its attached original |
| Fact-check claims | 8 (F01 to F08): 5 rated False, 2 Misleading, 1 Half True by The Quint, FACTLY, Vishvas News, BOOM, THIP Media and PIB Fact Check | Agreement with the published rating |
| Fresh fact-check claims | 4 (N01 to N04): 2 false, 2 true, checked to have no entry in the Fact Check Tools index | The verdict Gemini with Google Search reaches on its own |

Labels live in `benchmark/cases.json`; `benchmark/generate.py` rebuilds every reel; raw output is in `results/raw.json` and the scores in `results/metrics.json`.

## Metrics

| Metric | Result | How it is scored |
|---|---|---|
| Disclosure checker | precision 1.00, recall 1.00 (9 TP, 0 FP, 0 FN) | Verified flags matched one to one with expected flags of the same category; controls count any disclosure flag as a false positive |
| Claims checker | precision 1.00, recall 1.00 (6 TP, 0 FP, 0 FN); the previous run was 0.43 (8 FP) | Same; categories a case marks as allowed (for example a fact check next to a cure claim) are not counted |
| Clause citation accuracy | 0.93 (14 of 15 matched flags) | The matched flag cites one of the clause IDs the label accepts |
| Borrowed clips | precision 1.00, recall 1.00 (4 TP, 0 FP, 2 TN) | A verified borrowed flag on clipped pairs, none on faithful ones |
| Omission detection | 4 of 4 | Every clipped pair flagged |
| Alignment within 2 s | 4 of 4 | Where the system says the clip starts in the source, against the true cut point |
| Fact-check agreement | 8 of 8 | A verified flag rated contradicted or previously fact-checked (or insufficient evidence for the Half True claim) |
| Fresh fact-check agreement | 2 of 4 agree, 2 abstain, 0 disagree | A verified flag with the expected verdict; an uncertain one is an abstention |
| Abstention rate | 0.26 (20 of 77 flags uncertain) | Flags the evidence gate downgraded to "needs a human look" |
| Evidence-gate failures | **0** of 55 rechecked quotes | Every verified quote checked again after the run, independently: clause quotes against the clause index, clip originals against the source transcript, web quotes against a fresh fetch of the cited page. 2 quotes accepted through Google Search grounding spans cannot be rechecked offline and are not counted |
| Latency | median 36.3 s, p90 65.4 s per reel | Submit to report, measured by the client. Median by stage: extract 6.3 s, claim ledger 8.3 s, checking 14.8 s, evidence 0.3 s |
| Cost | about USD 0.05 per reel (median) | Tokens and calls from the logs at the list prices in `pricing.json`: about 5,100 input and 3,100 output tokens, 1 search-grounded call, 0.27 audio minutes per reel. Check Grounding is not included |

## What the numbers say

- **Disclosure** is deterministic once the ledger has the labels and timings, and it found every planted problem with no false alarms, including the 1 second label on a 9 second reel (C10) and the label buried as hashtag 7 of 7 (C03).
- **Claims precision went from 0.43 to 1.00 with recall kept.** The previous run had 8 extra claims flags: a second flag on the same violation (C11 got three) or a reach such as "battery life needs substantiation" on a plain review (C02). Four changes fixed it: the judge is asked for one finding per claim and only for what a regulator would act on; findings that share a ledger item, a subject or a clause (or a generic clause within 5 s of a specific one) merge into one flag with the most specific clause and all the evidence; a finding must quote a concrete span of the video (3 or more words, found in the ledger); and claims flags whose Check Grounding support is below 0.6 are dropped instead of shown as uncertain.
- **One clause miss**: C05 ("you will never fall sick again") cited the Drugs and Magic Remedies Act s. 3(d), which needs a Schedule condition; the label expects the ASCI health claim clauses. Merging now prefers the statute, which helps C06, C08 and C12 and costs this one. For C08 (lose 10 kilos in 7 days) the label now also accepts the Schedule entry, since Obesity is on it and s. 3(d) was already accepted.
- **Fact checks agree 8 of 8, with a caveat**: we picked the claims through the Fact Check Tools API, and the pipeline asks that same API first, so 7 of 8 were answered as "previously fact-checked". This shows the lookup works; it does not show how well Gemini with Search judges claims no fact-checker has covered. The supplements reel (Vitamin C prevents colds) exercises that path: verified as contradicted in 8 of 13 runs during Part A (2 of the final 3); 3 times it ended uncertain because the quote was not found on a fetched page, and twice the check was lost to repeated rate limiting (one job failed, one check was skipped).
- **Fresh claims are harder.** On four claims with no published fact check, Gemini with Google Search reached the right verdict every time but the gate verified only the two false ones (FD insurance cover, turmeric as a B12 source). Both true claims (UPI volume in August 2023, the MPC sets the repo rate) ended uncertain: their grounding support fell below 0.4. No fresh verdict was wrong.
- **Abstention is real**: about one flag in four ends as "needs a human look", mostly fact checks of passing remarks in the controls and cure reels whose quote could not be found word for word on a fetched page. That is the gate working as designed, at the cost of some noise in the report.
- **Latency** rose to 36 s at the median from 26 s in the previous run, with every stage slower by a similar share; the code path is the same apart from claims merging, so we read it as Vertex latency on the day, not a code change. It is still under a minute for most reels. A 40 s reel with five claims (supplements_hinglish) took 39 s to 87 s over the last three runs; the slow tail is Vertex returning 429 and 504 under shared capacity, which the hedged retries and the global fallback absorb.

## Known gaps

- No real creator videos, and a small set: real reels have music, cuts, noise and code-switching that synthetic voices do not.
- Single annotator (us). The labels were written with the scripts, before the run.
- Before and after is tested only as speech plus an overlay word; there is no visual comparison of two body shots.
- The fact-check set is biased toward claims already in Google's Fact Check Tools index; the 4 fresh claims are a start, not a measure.
