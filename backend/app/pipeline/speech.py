"""Speech to text with Chirp 3: words with start and end times."""

from dataclasses import asdict, dataclass, field
from functools import cache

from google.api_core.client_options import ClientOptions
from google.cloud.speech_v2 import SpeechClient
from google.cloud.speech_v2.types import cloud_speech

from ..config import settings

# Recognize takes up to 60 s of audio inline; longer goes through GCS.
_SYNC_LIMIT_MS = 55_000
_BATCH_TIMEOUT_S = 900


@dataclass(frozen=True)
class Word:
    text: str
    start_ms: int
    end_ms: int


@dataclass
class Transcript:
    language: str | None = None
    words: list[Word] = field(default_factory=list)

    @property
    def text(self) -> str:
        return " ".join(w.text for w in self.words)

    def to_json(self) -> dict:
        return {"language": self.language, "words": [asdict(w) for w in self.words]}


@cache
def _client() -> SpeechClient:
    return SpeechClient(
        client_options=ClientOptions(api_endpoint=f"{settings.speech_location}-speech.googleapis.com")
    )


def _config() -> cloud_speech.RecognitionConfig:
    return cloud_speech.RecognitionConfig(
        auto_decoding_config=cloud_speech.AutoDetectDecodingConfig(),
        model="chirp_3",
        language_codes=list(settings.speech_languages),
        features=cloud_speech.RecognitionFeatures(
            enable_word_time_offsets=True,
            enable_automatic_punctuation=True,
        ),
    )


def _recognizer() -> str:
    return f"projects/{settings.project_id}/locations/{settings.speech_location}/recognizers/_"


def _ms(offset) -> int:
    return int(offset.total_seconds() * 1000) if offset is not None else 0


def _collect(results) -> Transcript:
    transcript = Transcript()
    for result in results:
        if not result.alternatives:
            continue
        if result.language_code and transcript.language is None:
            transcript.language = result.language_code
        for word in result.alternatives[0].words:
            if word.word.strip():
                transcript.words.append(Word(word.word.strip(), _ms(word.start_offset), _ms(word.end_offset)))
    return transcript


def transcribe(audio_path: str, duration_ms: int | None, gcs_uri: str | None = None) -> Transcript:
    """`gcs_uri` must point at the same audio; it is used for long files."""
    if duration_ms is not None and duration_ms <= _SYNC_LIMIT_MS:
        with open(audio_path, "rb") as f:
            response = _client().recognize(
                request=cloud_speech.RecognizeRequest(recognizer=_recognizer(), config=_config(), content=f.read())
            )
        return _collect(response.results)

    if gcs_uri is None:
        raise ValueError("Audio over a minute needs a GCS copy")
    operation = _client().batch_recognize(
        request=cloud_speech.BatchRecognizeRequest(
            recognizer=_recognizer(),
            config=_config(),
            files=[cloud_speech.BatchRecognizeFileMetadata(uri=gcs_uri)],
            recognition_output_config=cloud_speech.RecognitionOutputConfig(
                inline_response_config=cloud_speech.InlineOutputConfig()
            ),
        )
    )
    response = operation.result(timeout=_BATCH_TIMEOUT_S)
    file_result = response.results[gcs_uri]
    if file_result.error and file_result.error.code:
        raise RuntimeError(f"Batch recognition failed: {file_result.error.code}")
    return _collect(file_result.transcript.results)
