from __future__ import annotations

from pathlib import Path

from .intent import IntentDetector
from .knowledge import KnowledgeBase
from .lua_module import LuaAssistant
from .memory import ConversationMemory
from .nlp import UkrainianNLP
from .web_search import WebSearchClient


class UkrainianHybridAI:
    def __init__(self, project_root: Path) -> None:
        self.project_root = Path(project_root)
        self.nlp = UkrainianNLP()
        self.memory = ConversationMemory(max_messages=8)
        self.intent_detector = IntentDetector(self.project_root / "data" / "intents.json", self.nlp)
        self.lua_assistant = LuaAssistant(self.project_root / "data" / "lua_examples.json", self.nlp)
        self.knowledge = KnowledgeBase(self.project_root / "data" / "world_knowledge.json", self.nlp)
        self.web_search = WebSearchClient()
        self.last_intent_name = "capability_help"

    def chat(self, message: str, force_web: bool = False) -> str:
        cleaned = message.strip()
        if not cleaned:
            return "Будь ласка, введіть повідомлення."

        history = self.memory.recent_messages(8)
        intent = self.intent_detector.detect(cleaned, history)
        related = self.intent_detector.retrieve_related(cleaned, limit=3)
        response = self._build_response(cleaned, intent, related, force_web=force_web)

        self.memory.add("user", cleaned)
        self.memory.add("assistant", response)
        self.last_intent_name = intent["name"]
        return response

    def status(self) -> dict[str, object]:
        web_status = self.web_search.status()
        return {
            "language": "uk",
            "engine": "hybrid-ai-plus",
            "web_search": web_status["provider"],
            "web_enabled": web_status["enabled"],
            "google_ready": web_status["google_ready"],
        }

    def _build_response(
        self,
        message: str,
        intent: dict[str, object],
        related: list[dict[str, object]],
        force_web: bool = False,
    ) -> str:
        normalized = self.nlp.normalize(message, keep_code=True)
        context_text = self.memory.context_as_text(limit=8)
        last_code = self.memory.latest_code()
        topic_hint = self.lua_assistant.last_topic

        if self._should_fix_lua(intent["name"], normalized):
            return self.lua_assistant.fix_code(
                message,
                context_text=context_text,
                fallback_code=last_code,
            )

        if self._should_explain_lua(intent["name"], normalized):
            return self.lua_assistant.explain_code(
                message,
                context_text=context_text,
                fallback_code=last_code,
            )

        if self._should_generate_lua(intent["name"], normalized):
            return self.lua_assistant.generate_code(
                message,
                context_text=context_text,
                topic_hint=topic_hint,
            )

        local_answer = self.knowledge.answer(
            message,
            context_text=context_text,
            last_assistant_message=self.memory.last_message("assistant"),
        )
        has_local_answer = local_answer is not None

        if self.web_search.should_search(
            message,
            self.nlp,
            intent_name=str(intent["name"]),
            has_local_answer=has_local_answer,
            force_web=force_web,
        ):
            web_answer = self.web_search.answer(message)
            if web_answer:
                return web_answer
            if force_web:
                return (
                    "Я спробував звернутися до онлайн-пошуку, але не отримав результат. "
                    "Можемо або уточнити запит, або я відповім загально з локальних знань."
                )

        if has_local_answer:
            return local_answer

        if intent["name"] in {"greeting", "capability_help", "thanks"}:
            return intent["intent"].get("template", "") or self._generic_response(message)

        if intent["name"] == "roblox_http":
            return self._roblox_http_response()

        if intent["name"] == "python_api":
            return self._python_api_response()

        if self.last_intent_name.startswith("lua_") and len(self.nlp.keywords(message)) <= 3:
            return self.lua_assistant.generate_code(
                message,
                context_text=context_text,
                topic_hint=topic_hint,
            )

        if related and related[0]["intent"]["name"] == "roblox_http":
            return self._roblox_http_response()

        return self._generic_response(message)

    def _should_generate_lua(self, intent_name: str, normalized: str) -> bool:
        generation_hints = [
            "напиши",
            "створи",
            "згенеруй",
            "приклад",
            "код",
            "скрипт",
        ]
        lua_hints = [
            "lua",
            "luau",
            "roblox",
            "функц",
            "цикл",
            "таблиц",
            "if",
            "button",
            "gui",
        ]
        return intent_name == "lua_generate" or (
            any(hint in normalized for hint in generation_hints)
            and any(hint in normalized for hint in lua_hints)
        )

    def _should_explain_lua(self, intent_name: str, normalized: str) -> bool:
        explain_hints = [
            "поясни",
            "розбери",
            "що робить",
            "пояснення",
            "розкажи",
        ]
        short_follow_up = self.last_intent_name == "lua_generate" and any(
            hint in normalized for hint in ["поясни", "розбери", "це"]
        )
        return intent_name == "lua_explain" or any(hint in normalized for hint in explain_hints) or short_follow_up

    def _should_fix_lua(self, intent_name: str, normalized: str) -> bool:
        fix_hints = [
            "виправ",
            "полагодь",
            "не працює",
            "помилка",
            "fix",
            "баг",
            "error",
        ]
        return intent_name == "lua_fix" or any(hint in normalized for hint in fix_hints)

    def _roblox_http_response(self) -> str:
        return (
            "Для Roblox клієнта використовуйте HttpService і POST на `http://127.0.0.1:5000/chat`.\n\n"
            "Порядок роботи:\n"
            "- Увімкніть `Allow HTTP Requests` у Roblox Studio.\n"
            "- Надсилайте JSON виду `{ \"message\": \"...\" }`.\n"
            "- Читайте поле `response` з JSON-відповіді сервера."
        )

    def _python_api_response(self) -> str:
        return (
            "Python сервер працює через Flask і endpoint `POST /chat`.\n\n"
            "Для простого текстового сценарію також доступний `GET /chat_text?message=...`.\n"
            "Якщо потрібно примусово звернутися до онлайн-пошуку, можна передати `web=1`.\n\n"
            "Приклад JSON-запиту:\n"
            "```json\n"
            "{\"message\": \"Напиши Lua функцію для монет\", \"web\": false}\n"
            "```"
        )

    def _generic_response(self, message: str) -> str:
        topic_words = self.nlp.keywords(message)[:4]
        topic_hint = ", ".join(topic_words)
        if topic_hint:
            return (
                f"Можу поговорити про тему `{topic_hint}` простими словами, допомогти з Roblox/Lua/Python "
                "або, якщо потрібна свіжа інформація, спробувати знайти її онлайн. "
                "Можеш написати щось на кшталт: `поясни простими словами`, `загугли це`, `порівняй два варіанти`."
            )

        return (
            "Тепер я можу не лише генерувати Lua-код, а й вільніше спілкуватися українською, пояснювати загальні теми "
            "та шукати актуальну інформацію онлайн. Спробуй звичайне питання або напиши `загугли ...`."
        )
