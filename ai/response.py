from __future__ import annotations

from pathlib import Path

from .generative import GenerativeResponder
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
        self.memory = ConversationMemory(max_messages=10)
        self.intent_detector = IntentDetector(self.project_root / "data" / "intents.json", self.nlp)
        self.lua_assistant = LuaAssistant(self.project_root / "data" / "lua_examples.json", self.nlp)
        self.knowledge = KnowledgeBase(self.project_root / "data" / "world_knowledge.json", self.nlp)
        self.web_search = WebSearchClient()
        self.generative = GenerativeResponder()
        self.last_intent_name = "capability_help"

    def chat(self, message: str, force_web: bool = False) -> str:
        cleaned = message.strip()
        if not cleaned:
            return "Будь ласка, введіть повідомлення."

        history = self.memory.messages_for_model(8)
        intent = self.intent_detector.detect(cleaned, history)
        related = self.intent_detector.retrieve_related(cleaned, limit=3)
        response = self._build_response(cleaned, intent, related, history=history, force_web=force_web)

        self.memory.add("user", cleaned)
        self.memory.add("assistant", response)
        self.last_intent_name = str(intent["name"])
        return response

    def status(self) -> dict[str, object]:
        web_status = self.web_search.status()
        generative_status = self.generative.status()
        return {
            "language": "uk",
            "engine": "hybrid-generative-ai" if generative_status["ready"] else "hybrid-ai-plus",
            "web_search": web_status["provider"],
            "web_enabled": web_status["enabled"],
            "google_ready": web_status["google_ready"],
            "generative_enabled": generative_status["enabled"],
            "generative_ready": generative_status["ready"],
            "generative_provider": generative_status["provider"],
            "generative_model": generative_status["model"],
        }

    def _build_response(
        self,
        message: str,
        intent: dict[str, object],
        related: list[dict[str, object]],
        history: list[dict[str, str]],
        force_web: bool = False,
    ) -> str:
        normalized = self.nlp.normalize(message, keep_code=True)
        intent_name = str(intent["name"])
        context_text = self.memory.context_as_text(limit=8)
        last_code = self.memory.latest_code()
        topic_hint = self.lua_assistant.last_topic

        local_answer: str | None = None
        lua_guidance: str | None = None

        if self._should_fix_lua(intent_name, normalized):
            lua_guidance = self.lua_assistant.fix_code(
                message,
                context_text=context_text,
                fallback_code=last_code,
            )
        elif self._should_explain_lua(intent_name, normalized):
            lua_guidance = self.lua_assistant.explain_code(
                message,
                context_text=context_text,
                fallback_code=last_code,
            )
        elif self._should_generate_lua(intent_name, normalized):
            lua_guidance = self.lua_assistant.generate_code(
                message,
                context_text=context_text,
                topic_hint=topic_hint,
            )
        else:
            local_answer = self.knowledge.answer(
                message,
                context_text=context_text,
                last_assistant_message=self.memory.last_message("assistant"),
            )

        has_local_answer = local_answer is not None
        search_requested = self.web_search.should_search(
            message,
            self.nlp,
            intent_name=intent_name,
            has_local_answer=has_local_answer,
            force_web=force_web,
        )
        web_result = self.web_search.search(message) if search_requested else None

        fallback_answer = self._fallback_response(
            message=message,
            intent=intent,
            related=related,
            local_answer=local_answer,
            lua_guidance=lua_guidance,
            web_result=web_result,
            context_text=context_text,
            topic_hint=topic_hint,
        )

        generated = self.generative.respond(
            message=message,
            history=history,
            intent_name=intent_name,
            context_text=context_text,
            local_answer=local_answer,
            web_result=web_result,
            lua_guidance=lua_guidance,
            fallback_answer=fallback_answer,
        )
        if generated:
            return generated

        if force_web and search_requested and not web_result:
            return (
                "Я спробував звернутися до онлайн-пошуку, але не отримав результат. "
                "Можемо або уточнити запит, або я відповім загально з локальних знань."
            )

        return fallback_answer

    def _fallback_response(
        self,
        *,
        message: str,
        intent: dict[str, object],
        related: list[dict[str, object]],
        local_answer: str | None,
        lua_guidance: str | None,
        web_result: dict[str, object] | None,
        context_text: str,
        topic_hint: str,
    ) -> str:
        intent_name = str(intent["name"])

        if web_result:
            return self.web_search.format_result(web_result) or self._generic_response(message)

        if lua_guidance:
            return lua_guidance

        if local_answer:
            return local_answer

        if intent_name in {"greeting", "capability_help", "thanks"}:
            return str(intent["intent"].get("template", "")).strip() or self._generic_response(message)

        if intent_name == "roblox_http":
            return self._roblox_http_response()

        if intent_name == "python_api":
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
            "Для Roblox клієнта використовуй HttpService і POST на `http://127.0.0.1:5000/chat`.\n\n"
            "Порядок роботи:\n"
            "- Увімкни `Allow HTTP Requests` у Roblox Studio.\n"
            "- Надсилай JSON виду `{ \"message\": \"...\" }`.\n"
            "- Читай поле `response` з JSON-відповіді сервера."
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
                "Можеш написати щось на кшталт: `поясни простими словами`, `знайди це в інтернеті`, "
                "`порівняй два варіанти` або `напиши приклад коду`."
            )

        return (
            "Тепер я можу не лише генерувати Lua-код, а й вільніше спілкуватися українською, "
            "пояснювати загальні теми та шукати актуальну інформацію онлайн. "
            "Спробуй звичайне питання або напиши `знайди ... в інтернеті`."
        )
