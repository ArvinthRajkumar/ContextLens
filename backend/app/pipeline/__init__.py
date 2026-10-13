"""The check pipeline: five stages run in order against one job.

`runner.run_check` drives any list of `Stage`s and writes progress to
Firestore. Today every stage is a stub (`stub.py`); the real pipeline
replaces them one at a time (for example `ExtractStage` using Speech and
Vertex AI) without touching the runner or the API.
"""

from .base import CheckContext, Stage, StageResult  # noqa: F401
