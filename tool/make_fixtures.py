"""Builds the mock report fixtures for the app (assets/mock) and the backend
stub (backend/app/fixtures). Run from the project root:

    python tool/make_fixtures.py

Compliance citations come from backend/app/clauses/index.json, so a clause
ID, its label and its verbatim text never drift apart. Every "From the
source" quote is a verbatim substring of its source, which the script
checks.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INDEX = json.loads((ROOT / 'backend/app/clauses/index.json').read_text(encoding='utf-8'))
CLAUSES = {c['id']: c for c in INDEX['clauses']}


def rule(clause_id: str, quote: str | None = None) -> dict:
    """Citation plus the verbatim passage for a compliance flag."""
    clause = CLAUSES[clause_id]
    instrument = INDEX['instruments'][clause['instrument']]
    out = {
        'citation': {
            'title': instrument['title'],
            'url': instrument['url'],
            'publisher': instrument['publisher'],
            'clauseId': clause_id,
            'instrument': instrument['short'],
            'clause': clause['clause'],
            'authority': instrument['authority'],
        },
    }
    if quote is not None:
        assert quote in clause['text'], f'{clause_id}: quote is not verbatim'
        out['sourceQuote'] = {'text': quote, 'source': f"{instrument['short']}, {clause['clause']}"}
    return out


def source(title: str, publisher: str, url: str | None, quote: str, where: str) -> dict:
    citation = {'title': title, 'publisher': publisher}
    if url:
        citation['url'] = url
    return {'citation': citation, 'sourceQuote': {'text': quote, 'source': where}}


COCHRANE = ('Vitamin C for preventing and treating the common cold', 'Cochrane',
            'https://www.cochranelibrary.com/cdsr/doi/10.1002/14651858.CD000980.pub4/full')
DICGC = ('Deposit insurance FAQs', 'DICGC, Reserve Bank of India', 'https://www.dicgc.org.in/FAQs')
SEBI = ('SEBI cautions public against dealing with unregistered entities (PR No. 2/2024)', 'SEBI',
        'https://www.sebi.gov.in/media-and-notifications/press-releases/feb-2024/sebi-cautions-public-against-dealing-with-unregistered-entities_81395.html')
PIB = ('PIB Fact Check: Has the RBI asked banks to stop dispensing ₹500 notes from ATMs by September?', 'Angel One',
       'https://www.angelone.in/news/market-updates/pib-fact-check-has-the-rbi-asked-banks-to-stop-dispensing-500-notes-from-atms-by-september')

# Video A: a health creator's supplement routine. Run 1 has 4 issues; run 2
# fixes 3 of them.
disclosure = {
    'id': 'f1', 'fingerprint': 'disclosure:brand-mention:vitaboost', 'category': 'disclosure',
    'severity': 'high', 'startMs': 4200, 'endMs': 9800,
    'title': 'Brand deal without an Ad label',
    'evidence': 'You say "VitaBoost sent me these" and show the code PRIYA20 for ₹200 off, but there is no "Ad" or "Collaboration" label on screen or in the caption.',
    **rule('asci-ig/1.1(b)', "If the advertiser or its agents gives free or discounted products or service, or other perks, and then the influencer mentions one of its products or services, a disclosure is needed even if they were not specifically asked to talk about that product or service."),
    'suggestedFix': 'Put "Ad" on screen for at least a third of the video (about 20 seconds here) and start your caption with it.',
}
claim = {
    'id': 'f2', 'fingerprint': 'claims:disease:diabetes', 'category': 'claims',
    'severity': 'high', 'startMs': 15400, 'endMs': 19900,
    'title': 'Supplement shown as treating diabetes',
    'evidence': '"My sugar is under control since I started this, I barely need my diabetes tablets now" links the product to treating diabetes, a condition in the Act\'s Schedule.',
    **rule('dmr-act/3(d)', 'the diagnosis, cure, mitigation, treatment or prevention of any disease, disorder or condition specified in the Schedule'),
    'suggestedFix': 'Drop the diabetes line. Talk about your routine, not about treating a condition, and never suggest cutting prescribed medicine.',
}
original_line = "Vitamin D is something everyone should be taking daily if a blood test shows they're deficient."
borrowed = {
    'id': 'f3', 'fingerprint': 'borrowed:clip:podcast-ep212', 'category': 'borrowed',
    'severity': 'medium', 'startMs': 31000, 'endMs': 38500,
    'title': 'Podcast clip is trimmed in a way that changes its meaning',
    'evidence': 'The clip ends before the doctor adds a condition, so the quote sounds like advice for everyone.',
    **source('Episode 212: Do you really need supplements?', 'The Chai Break podcast', None,
             original_line, 'The Chai Break, episode 212, original audio at 18:42'),
    'suggestedFix': 'Keep the full sentence, or say in your own words that the doctor meant people with a tested deficiency.',
    'diff': {
        'clipTranscript': 'Vitamin D is something everyone should be taking daily.',
        'originalTranscript': original_line,
        'segments': [
            {'op': 'equal', 'text': 'Vitamin D is something everyone should be taking daily'},
            {'op': 'delete', 'text': " if a blood test shows they're deficient"},
            {'op': 'equal', 'text': '.'},
        ],
    },
}
vitamin_c = {
    'id': 'f4', 'fingerprint': 'factcheck:vitc-cold', 'category': 'factcheck',
    'severity': 'high', 'startMs': 45500, 'endMs': 49000,
    'title': 'Vitamin C does not prevent colds',
    'evidence': 'A review of placebo-controlled trials found regular vitamin C did not reduce how often people in the general population catch colds.',
    **source(*COCHRANE,
             'The failure of vitamin C supplementation to reduce the incidence of colds in the general population indicates that routine vitamin C supplementation is not justified',
             "Cochrane review CD000980, authors' conclusions"),
    'suggestedFix': 'Change the line to "it may make a cold a little shorter" or cut it.',
    'factLabel': 'contradicted',
}
shorter_colds = {
    'id': 'c1', 'fingerprint': 'factcheck:vitc-duration', 'category': 'factcheck',
    'startMs': 41000, 'endMs': 44200,
    'title': 'Vitamin C can make colds a little shorter',
    'evidence': 'Trials of regular supplementation found adults had slightly shorter colds.',
    **source(*COCHRANE, 'In adults the duration of colds was reduced by 8% (3% to 12%)',
             'Cochrane review CD000980, main results'),
    'suggestedFix': 'No change needed. Linking the review in your caption adds credibility.',
    'factLabel': 'supported',
}

v1 = {
    'id': 'job_demo_v1', 'ownerUid': 'mock-user', 'status': 'done', 'stage': 'report', 'version': 1,
    'title': '3 supplements I take every morning',
    'createdAt': '2026-10-12T07:40:00Z', 'updatedAt': '2026-10-12T07:42:10Z', 'expiresAt': '2026-10-13T07:40:00Z',
    'video': {'durationMs': 58000, 'width': 1080, 'height': 1920},
    'summary': {'total': 4, 'byCategory': {'disclosure': 1, 'claims': 1, 'borrowed': 1, 'factcheck': 1}},
    'flags': [disclosure, claim, borrowed, shorter_colds, vitamin_c],
}
v2 = dict(v1)
v2.update({
    'id': 'job_demo_v2', 'version': 2, 'parentJobId': 'job_demo_v1',
    'createdAt': '2026-10-12T09:05:00Z', 'updatedAt': '2026-10-12T09:07:02Z', 'expiresAt': '2026-10-13T09:05:00Z',
    'video': {'durationMs': 56000, 'width': 1080, 'height': 1920},
    'summary': {'total': 1, 'byCategory': {'factcheck': 1}},
    'comparison': {'previousJobId': 'job_demo_v1', 'resolved': 3, 'remaining': 1, 'newCount': 0},
    'flags': [shorter_colds, vitamin_c],
})

# Video B: a personal finance review. Covers every category, every fact
# label and one flag the evidence gate downgraded to uncertain.
finance = {
    'id': 'job_demo_finance', 'ownerUid': 'mock-user', 'status': 'done', 'stage': 'report', 'version': 1,
    'title': 'Is this savings app worth it?',
    'createdAt': '2026-10-12T06:10:00Z', 'updatedAt': '2026-10-12T06:12:40Z', 'expiresAt': '2026-10-13T06:10:00Z',
    'video': {'durationMs': 94000, 'width': 1080, 'height': 1920},
    'summary': {'total': 7, 'byCategory': {'disclosure': 1, 'claims': 1, 'visuals': 1, 'borrowed': 1, 'factcheck': 3}},
    'flags': [
        {'id': 'b1', 'fingerprint': 'disclosure:affiliate:paisapal', 'category': 'disclosure', 'severity': 'high',
         'startMs': 2000, 'endMs': 6500, 'title': 'Referral link is not clearly disclosed',
         'evidence': 'You say "use my link in bio for ₹250 cashback", and #affiliate only appears at the end of 14 hashtags.',
         **rule('asci-ig/1.2(c)', 'Disclosure should not be buried in a group of hashtags or links.'),
         'suggestedFix': 'Say "this is my affiliate link, I earn a commission" before you mention it, and start your caption with "Affiliate".'},
        {'id': 'b2', 'fingerprint': 'claims:guarantee:returns', 'category': 'claims', 'severity': 'medium',
         'startMs': 12000, 'endMs': 16000, 'title': 'Returns are presented as guaranteed',
         'evidence': '"You will earn a guaranteed 12% a year, better than any FD" promises a return the app does not guarantee.',
         **rule('asci-code/I.ex(e)', 'Advertisements inviting the public to invest money shall not contain statements which may mislead the consumer in respect of the security offered, rates of return or terms of amortisation'),
         'suggestedFix': "Quote the app's current rate, say it can change, and drop \"guaranteed\"."},
        {'id': 'b3', 'fingerprint': 'visuals:crop:fees', 'category': 'visuals', 'severity': 'medium',
         'startMs': 22000, 'endMs': 26500, 'title': 'Screenshot is cropped above the fees line',
         'evidence': 'The plans screen is cut off just above "₹99 a month", so the plan looks free.',
         **rule('asci-code/I.1.4', 'Advertisements shall not contain statements or visual presentation, which directly, or by implication or by omission or by ambiguity or by exaggeration, are likely to mislead the consumer about the product advertised'),
         'suggestedFix': 'Show the full plans screen, or say the ₹99 monthly fee out loud.'},
        {'id': 'b4', 'fingerprint': 'borrowed:clip:news-segment', 'category': 'borrowed', 'severity': 'low',
         'startMs': 30000, 'endMs': 36000, 'title': 'News clip used without credit',
         'evidence': 'A 6 second clip from a TV business segment appears without naming the channel.',
         'suggestedFix': 'Add an on-screen credit for the channel, or replace the clip with your own footage.'},
        {'id': 'b5', 'fingerprint': 'factcheck:deposit-insurance', 'category': 'factcheck', 'severity': 'high',
         'startMs': 41000, 'endMs': 45000, 'title': 'Deposit insurance covers ₹5 lakh, not ₹10 lakh',
         'evidence': 'You say "your money here is insured up to ₹10 lakh". DICGC insures bank deposits up to ₹5 lakh per depositor in a bank, and the app itself is not a bank.',
         **source(*DICGC, 'Each depositor in a bank is insured upto a maximum of ₹ 5,00,000 (Rupees Five Lakhs) for both principal and interest',
                  'DICGC FAQs, "What is the maximum deposit amount insured by the DICGC?"'),
         'suggestedFix': 'Say "deposits at the partner bank are insured up to ₹5 lakh by DICGC" and name the bank.',
         'factLabel': 'contradicted'},
        {'id': 'b6', 'fingerprint': 'factcheck:rs500-atm', 'category': 'factcheck', 'severity': 'low',
         'startMs': 52000, 'endMs': 56000, 'title': 'The ₹500 note claim was fact-checked before',
         'evidence': 'You repeat that "RBI is pulling ₹500 notes from ATMs". PIB Fact Check called this message fake in July 2025.',
         **source(*PIB, 'has debunked this claim, confirming that the RBI has not issued any such instruction',
                  'Angel One, reporting PIB Fact Check, 14 July 2025'),
         'suggestedFix': 'Cut the line, or say it was a viral rumour that PIB Fact Check debunked.',
         'factLabel': 'previously_fact_checked'},
        {'id': 'b7', 'fingerprint': 'factcheck:users-save-2000', 'category': 'factcheck', 'severity': 'low',
         'startMs': 61000, 'endMs': 64500, 'title': 'Not enough evidence for "users save ₹2,000 a month"',
         'evidence': "We couldn't find an independent source for this number. It only appears in the app's own ads.",
         'suggestedFix': 'Attribute it ("the company says") or leave it out.',
         'factLabel': 'insufficient_evidence'},
        {'id': 'c2', 'fingerprint': 'factcheck:no-assured-returns', 'category': 'factcheck',
         'startMs': 70000, 'endMs': 74000, 'title': 'No one can guarantee stock market returns',
         'evidence': 'SEBI warns that there can be no guarantee of assured returns in the securities market.',
         **source(*SEBI, 'there can be no guarantees of assured returns in the securities market',
                  'SEBI press release PR No. 2/2024, 13 February 2024'),
         'suggestedFix': 'No change needed.',
         'factLabel': 'supported'},
        {'id': 'u1', 'fingerprint': 'claims:qualification:sebi-registration', 'category': 'claims', 'severity': 'medium',
         'startMs': 78000, 'endMs': 82500, 'title': 'Fund tip may need your SEBI registration number',
         'evidence': 'You name a small-cap fund and say "start your SIP here". If that counts as investment advice, ASCI expects your SEBI registration number up front. We could not confirm the clause applies to this line.',
         **rule('asci-ig/add2-I.1'),
         'suggestedFix': "If you're SEBI registered, show your registration number at the start. If not, keep it general and don't name a fund.",
         'uncertain': True},
    ],
}

failed = {
    'id': 'job_demo_failed', 'ownerUid': 'mock-user', 'status': 'failed', 'stage': 'extract', 'version': 1,
    'title': 'Unboxing the new camera, first impressions',
    'createdAt': '2026-10-11T18:20:00Z', 'updatedAt': '2026-10-11T18:21:30Z', 'expiresAt': '2026-10-12T18:20:00Z',
    'video': {'durationMs': 142000, 'width': 1920, 'height': 1080},
    'error': {'code': 'audio_unreadable', 'message': "We couldn't read the audio track. Export the video again as MP4 and try once more."},
    'flags': [],
}


def write(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w', encoding='utf-8', newline='\n') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write('\n')


for name, data in [('report_v1', v1), ('report_v2', v2), ('report_finance', finance), ('run_failed', failed)]:
    write(ROOT / f'assets/mock/{name}.json', data)
for name, data in [('report_v1', v1), ('report_v2', v2)]:
    write(ROOT / f'backend/app/fixtures/{name}.json', data)

text = json.dumps([v1, v2, finance, failed], ensure_ascii=False)
for banned in (chr(0x2013), chr(0x2014), 'example.com', 'FDIC', 'FTC'):
    assert banned not in text, banned
print('fixtures written')
