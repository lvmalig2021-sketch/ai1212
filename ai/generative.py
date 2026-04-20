from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from typing import Any


class GenerativeResponder:
    def __init__(self) -> None:
        enabled_env = os.getenv("ENABLE_GENERATIVE_AI", "").strip().lower()
        self.provider = os.getenv("GENERATIVE_PROVIDER", "ollama").strip().lower() or "ollama"
        self.timeout = self._read_float("GENERATIVE_TIMEOUT", 60.0)
        self.temperature = self._read_float("GENERATIVE_TEMPERATURE", 0.45)
        self.max_tokens = self._read_int("GENERATIVE_MAX_TOKENS", 900)
        self.last_error = ""

        if self.provider == "ollama":
            self.base_url = (
                os.getenv("OLLAMA_BASE_URL")
                or os.getenv("LLM_BASE_URL")
                or "http://127.0.0.1:11434"
            ).rstrip("/")
            self.api_key = ""
            self.model = (os.getenv("OLLAMA_MODEL") or os.getenv("LLM_MODEL") or "").strip()
            self.keep_alive = os.getenv("OLLAMA_KEEP_ALIVE", "5m").strip() or "5m"
        else:
            self.base_url = (
                os.getenv("OPENAI_BASE_URL")
                or os.getenv("LLM_BASE_URL")
                or "https://api.openai.com/v1"
            ).rstrip("/")
            self.api_key = (os.getenv("OPENAI_API_KEY") or os.getenv("LLM_API_KEY") or "").strip()
            self.model = (os.getenv("OPENAI_MODEL") or os.getenv("LLM_MODEL") or "").strip()
            self.keep_alive = ""

        if enabled_env:
            self.enabled = enabled_env in {"1", "true", "yes", "on"}
        elif self.provider == "ollama":
            self.enabled = bool(self.model)
        else:
            self.enabled = bool(self.api_key and self.model)

    @property
    def is_ready(self) -> bool:
        if self.provider == "ollama":
            return self.enabled and bool(self.model) and self._ollama_model_available()
        return self.enabled and bool(self.api_key and self.model)

    def status(self) -> dict[str, object]:
        return {
            "enabled": self.enabled,
            "ready": self.is_ready,
            "provider": self.provider,
            "model": self.model or None,
            "base_url": self.base_url,
            "last_error": self.last_error or None,
        }

    def respond(
        self,
        *,
        message: str,
        history: list[dict[str, str]],
        intent_name: str,
        context_text: str = "",
        local_answer: str | None = None,
        web_result: dict[str, object] | None = None,
        lua_guidance: str | None = None,
        fallback_answer: str | None = None,
    ) -> str | None:
        if not self.is_ready:
            return None

        messages = self._build_messages(
            message=message,
            history=history,
            intent_name=intent_name,
            context_text=context_text,
            local_answer=local_answer,
            web_result=web_result,
            lua_guidance=lua_guidance,
            fallback_answer=fallback_answer,
        )

        try:
            if self.provider == "ollama":
                payload = {
                    "model": self.model,
                    "messages": messages,
                    "stream": False,
                    "keep_alive": self.keep_alive,
                    "options": {
                        "temperature": self.temperature,
                        "num_predict": self.max_tokens,
                    },
                }
                data = self._post_json(f"{self.base_url}/api/chat", payload)
                content = self._extract_ollama_content(data)
            else:
                payload = {
                    "model": self.model,
                    "messages": messages,
                    "temperature": self.temperature,
                    "max_tokens": self.max_tokens,
                }
                data = self._post_json(self._chat_url(), payload, bearer_token=self.api_key)
                content = self._extract_openai_content(data)

            if not content:
                self.last_error = "Порожня відповідь від генеративної моделі."
                return None
            self.last_error = ""
            return content
        except Exception as exc:
            self.last_error = str(exc)
            return None

    def _build_messages(
        self,
        *,
        message: str,
        history: list[dict[str, str]],
        intent_name: str,
        context_text: str,
        local_answer: str | None,
        web_result: dict[str, object] | None,
        lua_guidance: str | None,
        fallback_answer: str | None,
    ) -> list[dict[str, str]]:
        system_prompt = (
            "Ти українськомовний AI-помічник для Roblox, Lua/Luau, Python і загальних тем. "
            "Відповідай природно, своїми словами, без копіювання сирих уривків. "
            "Якщо є локальні знання, веб-результати чи чернетка коду, використовуй їх як опору, але формулюй відповідь наново. "
            "Для запитів про код давай робочий приклад і коротке пояснення. "
            "Для загальних тем пояснюй просто й по суті. "
            "Якщо в тебе є веб-джерела, можна коротко згадати, що це онлайн-інформація, і в кінці подати 1-3 джерела. "
            "Не вигадуй фактів, яких не знаєш. Якщо даних мало, чесно скажи це."
        )
        messages: list[dict[str, str]] = [{"role": "system", "content": system_prompt}]

        for item in history[-6:]:
            role = item.get("role", "user")
            if role not in {"user", "assistant", "system"}:
                role = "user"
            content = str(item.get("content", "")).strip()
            if not content:
                continue
            messages.append({"role": role, "content": content[:1800]})

        sections = [f"Намір користувача: {intent_name}."]
        if context_text:
            sections.append(f"Короткий контекст діалогу:\n{context_text}")
        if local_answer:
            sections.append(f"Локальна довідка:\n{local_answer}")
        if lua_guidance:
            sections.append(f"Чернетка або підказка для відповіді:\n{lua_guidance}")
        if fallback_answer and fallback_answer not in {local_answer, lua_guidance}:
            sections.append(f"Запасна відповідь, якщо потрібно:\n{fallback_answer}")

        web_context = self._format_web_context(web_result)
        if web_context:
            sections.append(web_context)

        sections.append(
            "Завдання: дай фінальну відповідь українською. "
            "Відповідай як живий помічник: можеш перефразовувати, узагальнювати, структурувати й пояснювати."
        )
        sections.append(f"Поточне повідомлення користувача:\n{message}")
        messages.append({"role": "user", "content": "\n\n".join(sections)})
        return messages

    def _format_web_context(self, web_result: dict[str, object] | None) -> str:
        if not web_result:
            return ""

        lines = [
            f"Онлайн-пошук: провайдер {web_result.get('provider', 'unknown')}.",
            f"Пошуковий запит: {web_result.get('query', '')}",
        ]
        summary = str(web_result.get("summary", "")).strip()
        if summary:
            lines.append(f"Короткий знайдений зміст: {summary}")

        results = web_result.get("results", [])
        if isinstance(results, list) and results:
            lines.append("Джерела та уривки:")
            for item in results[:3]:
                title = self._result_field(item, "title")
                snippet = self._result_field(item, "snippet")
                url = self._result_field(item, "url")
                source = self._result_field(item, "source")
                if not title and not snippet:
                    continue
                if len(snippet) > 300:
                    snippet = snippet[:297] + "..."
                lines.append(f"- {title} [{source}]")
                if snippet:
                    lines.append(f"  Уривок: {snippet}")
                if url:
                    lines.append(f"  URL: {url}")

        return "\n".join(lines)

    def _chat_url(self) -> str:
        if self.base_url.endswith("/chat/completions"):
            return self.base_url
        return f"{self.base_url}/chat/completions"

    def _ollama_model_available(self) -> bool:
        try:
            payload = self._get_json(f"{self.base_url}/api/tags")
        except Exception as exc:
            self.last_error = str(exc)
            return False

        models = payload.get("models", [])
        if not isinstance(models, list):
            return False

        expected = self.model.strip().lower()
        available_names: set[str] = set()
        for item in models:
            if not isinstance(item, dict):
                continue
            for field_name in ("name", "model"):
                value = str(item.get(field_name, "")).strip().lower()
                if value:
                    available_names.add(value)
        return expected in available_names

    def _post_json(self, url: str, payload: dict[str, Any], bearer_token: str = "") -> dict[str, Any]:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers = {"Content-Type": "application/json; charset=utf-8"}
        if bearer_token:
            headers["Authorization"] = f"Bearer {bearer_token}"

        request = urllib.request.Request(url, data=body, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                raw = response.read().decode("utf-8")
        except urllib.error.HTTPError as exc:
            raw = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"HTTP {exc.code}: {raw}") from exc
        except urllib.error.URLError as exc:
            raise RuntimeError(f"Не вдалося дістатися до LLM API: {exc.reason}") from exc

        return json.loads(raw)

    def _get_json(self, url: str, bearer_token: str = "") -> dict[str, Any]:
        headers = {"Content-Type": "application/json; charset=utf-8"}
        if bearer_token:
            headers["Authorization"] = f"Bearer {bearer_token}"

        request = urllib.request.Request(url, headers=headers, method="GET")
        try:
            with urllib.request.urlopen(request, timeout=min(self.timeout, 5.0)) as response:
                raw = response.read().decode("utf-8")
        except urllib.error.HTTPError as exc:
            raw = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"HTTP {exc.code}: {raw}") from exc
        except urllib.error.URLError as exc:
            raise RuntimeError(f"Не вдалося дістатися до LLM API: {exc.reason}") from exc

        return json.loads(raw)

    def _extract_openai_content(self, payload: dict[str, Any]) -> str:
        choices = payload.get("choices", [])
        if not isinstance(choices, list) or not choices:
            return ""

        message = choices[0].get("message", {})
        content = message.get("content", "")
        if isinstance(content, str):
            return content.strip()
        if isinstance(content, list):
            chunks: list[str] = []
            for item in content:
                if isinstance(item, dict) and item.get("type") == "text":
                    text = str(item.get("text", "")).strip()
                    if text:
                        chunks.append(text)
            return "\n".join(chunks).strip()
        return ""

    def _extract_ollama_content(self, payload: dict[str, Any]) -> str:
        message = payload.get("message", {})
        content = str(message.get("content", "")).strip()
        thinking = str(message.get("thinking", "")).strip()
        if content:
            return content
        return thinking

    def _read_float(self, key: str, default: float) -> float:
        value = os.getenv(key, "").strip()
        if not value:
            return default
        try:
            return float(value)
        except ValueError:
            return default

    def _read_int(self, key: str, default: int) -> int:
        value = os.getenv(key, "").strip()
        if not value:
            return default
        try:
            return int(value)
        except ValueError:
            return default

    def _result_field(self, item: object, field_name: str) -> str:
        if isinstance(item, dict):
            return str(item.get(field_name, "")).strip()
        return str(getattr(item, field_name, "")).strip()
