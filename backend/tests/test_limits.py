import pytest

from app import limits
from app.errors import ApiError


@pytest.mark.parametrize(
    ("mine", "everyone", "running", "code"),
    [
        (0, 0, 0, None),
        (9, 149, 2, None),
        (10, 0, 0, "daily_limit"),
        (0, 150, 0, "busy"),
        (0, 0, 3, "too_many_running"),
        # The user's own limit is the more useful message when both apply.
        (10, 150, 3, "daily_limit"),
    ],
)
def test_verdict(mine, everyone, running, code):
    if code is None:
        limits.verdict(mine, everyone, running)
        return
    with pytest.raises(ApiError) as caught:
        limits.verdict(mine, everyone, running)
    assert caught.value.code == code


def test_busy_is_final_not_retried():
    # The app retries retryable errors on its own; these must reach the user.
    assert not limits.BUSY.retryable
    assert not limits.DAILY_LIMIT.retryable
    assert limits.DAILY_LIMIT.message == "Daily limit reached, try again tomorrow."
    assert limits.BUSY.message == "ContextLens is busy, try later."
