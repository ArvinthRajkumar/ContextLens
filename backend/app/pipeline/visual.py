"""What is on screen, from Gemini watching the video: text overlays,
disclosure labels, products and before/after shots, each with its time."""

from typing import Literal

from google.genai import types
from pydantic import BaseModel, Field

from .base import CheckContext
from .gemini import generate

ScreenTextKind = Literal[
    "disclosure_label",
    "promo_code",
    "price",
    "claim",
    "product_name",
    "subtitle",
    "credit",
    "title",
    "other",
]


class ScreenText(BaseModel):
    text: str = Field(description="The text exactly as shown, including symbols such as the rupee sign.")
    kind: ScreenTextKind
    start_s: float = Field(description="Second it first appears.")
    end_s: float = Field(description="Second it disappears.")
    position: Literal["top", "middle", "bottom"]


class ProductShot(BaseModel):
    product: str
    brand: str | None = None
    start_s: float
    end_s: float


class BeforeAfter(BaseModel):
    description: str
    start_s: float
    end_s: float


class BorrowedFootage(BaseModel):
    description: str = Field(description="For example a news clip, a podcast, another creator's video.")
    start_s: float
    end_s: float
    credited_on_screen: bool


class VisualFacts(BaseModel):
    screen_text: list[ScreenText]
    product_shots: list[ProductShot]
    before_after: list[BeforeAfter]
    borrowed_footage: list[BorrowedFootage]
    setting: str = Field(description="One short line: where and what the video shows.")


_SYSTEM = """You review short creator videos for an Indian pre-publish compliance check.
List only what is visible on screen. Never infer from audio.
Transcribe every text overlay exactly as shown, one entry per distinct overlay, with the
first and last second it is visible. Classify disclosure labels (Ad, #ad, Sponsored,
Collaboration, Partnership, Paid partnership, Affiliate, Free gift, Employee) as
disclosure_label even when small. List products or packaging that are shown, before and
after comparisons, and footage that looks borrowed from another source.
Times are seconds from the start of the video. Return empty lists when there is nothing."""


def analyse(ctx: CheckContext, stage: str, video_uri: str, mime_type: str, duration_ms: int | None) -> VisualFacts:
    # Two frames a second keeps label durations accurate to half a second on
    # reels; long videos drop to one. Low resolution is plenty for overlay
    # text and cuts the tokens (and the wait) by about four.
    fps = 2.0 if (duration_ms or 0) <= 180_000 else 1.0
    video = types.Part(
        file_data=types.FileData(file_uri=video_uri, mime_type=mime_type),
        video_metadata=types.VideoMetadata(fps=fps),
    )
    return generate(
        ctx,
        stage,
        [types.Content(role="user", parts=[video, types.Part(text="List what is on screen.")])],
        VisualFacts,
        _SYSTEM,
        thinking_budget=0,
        media_resolution=types.MediaResolution.MEDIA_RESOLUTION_LOW,
        attempt_seconds=45,
    )
