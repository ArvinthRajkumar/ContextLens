from app.pipeline.ledger import Sentence, _speech_span, caption_items, sentences, summary
from app.pipeline.speech import Transcript, Word
from app.pipeline.textmatch import contains, normalize


def _words(text: str, start: int = 0, step: int = 300, gap_after: dict[int, int] | None = None) -> list[Word]:
    out, t = [], start
    for i, w in enumerate(text.split()):
        out.append(Word(w, t, t + step - 20))
        t += step + (gap_after or {}).get(i, 0)
    return out


def test_sentences_split_on_punctuation_and_pauses():
    words = _words("Hi everyone, Priya here. Today I share three supplements so stay", gap_after={9: 1500})
    split = sentences(Transcript(words=words))
    assert [s.text for s in split] == [
        "Hi everyone, Priya here.",
        "Today I share three supplements so",
        "stay",
    ]


def test_span_narrows_to_the_quoted_words():
    sentence = Sentence(0, _words("Honestly, my sugar is under control since I started this.", start=1000))
    text, start, end = _speech_span(sentence, "my sugar is under control")
    assert text == "my sugar is under control"
    assert start == sentence.words[1].start_ms
    assert end == sentence.words[5].end_ms


def test_span_falls_back_to_the_sentence_when_not_verbatim():
    sentence = Sentence(0, _words("Vitamin C basically stops you from ever catching a cold."))
    text, start, end = _speech_span(sentence, "vitamin C prevents colds")
    assert text == sentence.text
    assert (start, end) == (sentence.words[0].start_ms, sentence.words[-1].end_ms)


def test_caption_label_up_front():
    [item] = caption_items("Ad: 3 supplements I take every morning\n\n#wellness")
    assert item["upFront"] is True
    assert item["hashtagPosition"] is None


def test_caption_label_buried_in_hashtags():
    [item] = caption_items("3 supplements\n\n#wellness #morningroutine #desi #ad")
    assert item["upFront"] is False
    assert (item["hashtagPosition"], item["hashtagCount"]) == (4, 4)


def test_caption_words_that_contain_ad_are_not_labels():
    assert caption_items("Read my bio, I made this at home #roadtrip #adventure") == []


def test_summary_line():
    items = [
        {"type": "health_claim"},
        {"type": "factual_claim"},
        {"type": "brand_mention"},
        {"type": "disclosure_label"},
    ]
    assert summary(items) == "2 claims found, 1 brand mention, 1 label"
    assert summary([]) == "0 claims found"


def test_matching_ignores_case_quotes_and_punctuation():
    assert normalize("  “Hello”,  World! ") == 'hello", world'
    assert contains("Each depositor in a bank is insured upto a maximum of ₹ 5,00,000", "BANK is insured upto")
    assert contains("the advertiser’s product", "advertiser's product")
    assert not contains("insured upto a maximum", "insured up to a maximum")
