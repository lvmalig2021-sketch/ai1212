from __future__ import annotations

import json
import os
import urllib.parse
import urllib.request
from dataclasses import dataclass

from .nlp import UkrainianNLP


@dataclass
class SearchHit:
    title: str
    snippet: str
    url: str
    source: str


class WebSearchClient:
    SEARCH_HINTS = (
        "загугли",
        "гугли",
        "google",
        "пошукай",
        "знайди",
        "в інтернеті",
        "в інтернет",
        "онлайн",
        "новини",
        "актуаль",
        "сьогодні",
        "зараз",
        "останні",
        "latest",
    )
    TIME_SENSITIVE_HINTS = (
        "новин",
        "сьогодні",
        "зараз",
        "курс",
        "ціна",
        "погода",
        "дата",
        "коли",
        "актуаль",
        "останн",
        "latest",
        "current",
    )

    def __init__(self) -> None:
        self.enabled = os.getenv("ENABLE_WEB_SEARCH", "1").lower() in {"1", "true", "yes", "on"}
        self.provider = os.getenv("WEB_SEARCH_PROVIDER", "auto").strip().lower() or "auto"
        self.google_api_key = os.getenv("GOOGLE_SEARCH_API_KEY", "").strip()
        self.google_cx = os.getenv("GOOGLE_SEARCH_CX", "").strip()
        self.user_agent = os.getenv(
            "WEB_SEARCH_USER_AGENT",
            "RobloxUkrainianAI/1.0 (+https://roblox-ukrainian-ai.onrender.com)",
        )

    @property
    def google_ready(self) -> bool:
        return bool(self.google_api_key and self.google_cx)

    def status(self) -> dict[str, object]:
        return {
            "enabled": self.enabled,
            "provider": self.active_provider(),
            "google_ready": self.google_ready,
        }

    def active_provider(self) -> str:
        if not self.enabled:
            return "disabled"
        if self.provider == "google" and self.google_ready:
            return "google"
        if self.provider in {"wikipedia", "wiki"}:
            return "wikipedia"
        if self.google_ready:
            return "google"
        return "wikipedia"

    def should_search(
        self,
        message: str,
        nlp: UkrainianNLP,
        intent_name: str = "",
        has_local_answer: bool = False,
        force_web: bool = False,
    ) -> bool:
        if not self.enabled:
            return False

        if force_web:
            return True

        normalized = nlp.normalize(message, keep_code=True)
        if any(hint in normalized for hint in self.SEARCH_HINTS):
            return True

        if intent_name == "web_search":
            return True

        if nlp.contains_code(message):
            return False

        if any(hint in normalized for hint in self.TIME_SENSITIVE_HINTS):
            return True

        if message.strip().endswith("?") and not has_local_answer and len(nlp.keywords(message)) >= 2:
            return True

        return False

    def answer(self, query: str, limit: int = 3) -> str | None:
        result = self.search(query, limit=limit)
        if not result:
            return None

        lines = [
            f"Я знайшов інформацію онлайн за запитом: {result['query']}",
            "",
            f"Коротко: {result['summary']}",
        ]
        if result["results"]:
            lines.append("")
            lines.append("Джерела:")
            for item in result["results"][:limit]:
                lines.append(f"- {item.title} — {item.source}")
                lines.append(f"- {item.url}")
        lines.append("")
        lines.append(f"Провайдер пошуку: {result['provider']}.")
        return "\n".join(lines)

    def search(self, query: str, limit: int = 3) -> dict[str, object] | None:
        if not self.enabled:
            return None

        prepared_query = self._clean_query(query)
        providers = self._provider_order()
        for provider in providers:
            try:
                if provider == "google":
                    result = self._google_search(prepared_query, limit=limit)
                else:
                    result = self._wikipedia_search(prepared_query, limit=limit)
            except Exception:
                result = None
            if result:
                return result
        return None

    def _provider_order(self) -> list[str]:
        if self.provider == "google":
            return ["google", "wikipedia"] if self.google_ready else ["wikipedia"]
        if self.provider in {"wikipedia", "wiki"}:
            return ["wikipedia"]
        if self.google_ready:
            return ["google", "wikipedia"]
        return ["wikipedia"]

    def _google_search(self, query: str, limit: int = 3) -> dict[str, object] | None:
        if not self.google_ready:
            return None

        params = urllib.parse.urlencode(
            {
                "key": self.google_api_key,
                "cx": self.google_cx,
                "q": query,
                "num": max(1, min(limit, 10)),
                "hl": "uk",
                "safe": "off",
            }
        )
        payload = self._read_json(f"https://customsearch.googleapis.com/customsearch/v1?{params}")
        items = payload.get("items", [])
        if not items:
            return None

        results = [
            SearchHit(
                title=str(item.get("title", "")).strip(),
                snippet=str(item.get("snippet", "")).strip(),
                url=str(item.get("link", "")).strip(),
                source=str(item.get("displayLink", "Google")).strip() or "Google",
            )
            for item in items[:limit]
            if item.get("link")
        ]
        if not results:
            return None

        summary = results[0].snippet or f"Знайдено матеріал: {results[0].title}."
        return {
            "provider": "google",
            "query": query,
            "summary": summary,
            "results": results,
        }

    def _wikipedia_search(self, query: str, limit: int = 3) -> dict[str, object] | None:
        titles = self._search_wikipedia_titles("uk", query, limit=limit)
        language = "uk"
        if not titles:
            titles = self._search_wikipedia_titles("en", query, limit=limit)
            language = "en"
        if not titles:
            return None

        extracts = self._load_wikipedia_extracts(language, titles)
        results: list[SearchHit] = []
        for title in titles:
            page = extracts.get(title, {})
            snippet = str(page.get("extract", "")).strip()
            if not snippet:
                continue
            article_url = f"https://{language}.wikipedia.org/wiki/{urllib.parse.quote(title.replace(' ', '_'))}"
            results.append(
                SearchHit(
                    title=title,
                    snippet=snippet,
                    url=article_url,
                    source=f"Wikipedia ({language})",
                )
            )
        if not results:
            return None

        summary = results[0].snippet
        return {
            "provider": "wikipedia",
            "query": query,
            "summary": summary,
            "results": results[:limit],
        }

    def _search_wikipedia_titles(self, language: str, query: str, limit: int = 3) -> list[str]:
        params = urllib.parse.urlencode(
            {
                "action": "query",
                "list": "search",
                "srsearch": query,
                "format": "json",
                "utf8": 1,
                "srlimit": max(1, min(limit, 10)),
            }
        )
        payload = self._read_json(f"https://{language}.wikipedia.org/w/api.php?{params}")
        return [str(item.get("title", "")).strip() for item in payload.get("query", {}).get("search", []) if item.get("title")]

    def _load_wikipedia_extracts(self, language: str, titles: list[str]) -> dict[str, dict[str, object]]:
        params = urllib.parse.urlencode(
            {
                "action": "query",
                "prop": "extracts",
                "exintro": 1,
                "explaintext": 1,
                "titles": "|".join(titles),
                "format": "json",
                "utf8": 1,
            }
        )
        payload = self._read_json(f"https://{language}.wikipedia.org/w/api.php?{params}")
        pages = payload.get("query", {}).get("pages", {})
        mapped: dict[str, dict[str, object]] = {}
        for page in pages.values():
            title = str(page.get("title", "")).strip()
            if title:
                mapped[title] = page
        return mapped

    def _read_json(self, url: str) -> dict[str, object]:
        request = urllib.request.Request(url, headers={"User-Agent": self.user_agent})
        with urllib.request.urlopen(request, timeout=10) as response:
            payload = response.read().decode("utf-8")
        return json.loads(payload)

    def _clean_query(self, query: str) -> str:
        cleaned = query.strip()
        for prefix in ["загугли", "гугли", "пошукай", "знайди", "в інтернеті", "онлайн"]:
            if cleaned.lower().startswith(prefix):
                cleaned = cleaned[len(prefix) :].strip(" :,-")
        return cleaned or query.strip()
