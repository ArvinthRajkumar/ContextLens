"""Fetches a web page as plain text, so quotes can be matched against it."""

import html
import ipaddress
import re
import socket
from dataclasses import dataclass
from html.parser import HTMLParser
from urllib.parse import urlparse

import httpx

_TIMEOUT = httpx.Timeout(10.0, connect=5.0)
_MAX_BYTES = 3 * 1024 * 1024
_HEADERS = {"User-Agent": "Mozilla/5.0 (compatible; ContextLens fact check)", "Accept-Language": "en-IN,en;q=0.8"}
_SKIP = {"script", "style", "noscript", "svg", "template"}
_SPACE = re.compile(r"\s+")


@dataclass(frozen=True)
class Page:
    url: str
    title: str
    text: str


class _Text(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self.title = ""
        self._skip = 0
        self._in_title = False

    def handle_starttag(self, tag, attrs):
        if tag in _SKIP:
            self._skip += 1
        self._in_title = tag == "title"

    def handle_endtag(self, tag):
        if tag in _SKIP and self._skip:
            self._skip -= 1
        if tag == "title":
            self._in_title = False
        self.parts.append(" ")

    def handle_data(self, data):
        if self._in_title and not self.title:
            self.title = data.strip()
        if not self._skip:
            self.parts.append(data)


def _public(url: str) -> bool:
    """https only, and never a private or local address."""
    parsed = urlparse(url)
    if parsed.scheme != "https" or not parsed.hostname:
        return False
    try:
        for info in socket.getaddrinfo(parsed.hostname, 443):
            address = ipaddress.ip_address(info[4][0])
            if address.is_private or address.is_loopback or address.is_link_local or address.is_reserved:
                return False
    except (socket.gaierror, ValueError):
        return False
    return True


def fetch(url: str) -> Page | None:
    """None when the page can't be fetched or isn't HTML or text."""
    if not _public(url):
        return None
    try:
        with httpx.Client(timeout=_TIMEOUT, headers=_HEADERS, follow_redirects=True, max_redirects=5) as http:
            response = http.get(url)
    except httpx.HTTPError:
        return None
    final = str(response.url)
    if response.status_code != 200 or not _public(final):
        return None
    kind = response.headers.get("content-type", "")
    body = response.content[:_MAX_BYTES].decode(response.encoding or "utf-8", errors="replace")
    if "html" in kind:
        parser = _Text()
        parser.feed(body)
        text, title = "".join(parser.parts), parser.title
    elif kind.startswith("text/"):
        text, title = body, ""
    else:
        return None
    return Page(final, html.unescape(title), _SPACE.sub(" ", html.unescape(text)).strip())
