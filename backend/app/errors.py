"""The error shape from the spec: {"error": {"code", "message", "retryable"}}."""

from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


class ApiError(Exception):
    def __init__(self, status: int, code: str, message: str, retryable: bool = False):
        super().__init__(message)
        self.status = status
        self.code = code
        self.message = message
        self.retryable = retryable


def _body(code: str, message: str, retryable: bool) -> dict:
    return {"error": {"code": code, "message": message, "retryable": retryable}}


async def api_error_handler(_: Request, exc: ApiError) -> JSONResponse:
    return JSONResponse(_body(exc.code, exc.message, exc.retryable), status_code=exc.status)


async def validation_error_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
    first = exc.errors()[0] if exc.errors() else {}
    field = ".".join(str(p) for p in first.get("loc", [])[1:]) or "body"
    return JSONResponse(
        _body("invalid_request", f"Invalid {field}: {first.get('msg', 'bad value')}", False),
        status_code=400,
    )


async def unhandled_error_handler(_: Request, exc: Exception) -> JSONResponse:
    # Never echo internals (URLs, tokens, paths) back to the client.
    return JSONResponse(_body("internal", "Something went wrong on our side.", True), status_code=500)
