from __future__ import annotations

from pathlib import Path

from .intent import IntentDetector
from .lua_module import LuaAssistant
from .memory import ConversationMemory
from .nlp import UkrainianNLP


class UkrainianHybridAI:
    def __init__(self, project_root: Path) -> None:
        self.project_root = Path(project_root)
        self.nlp = UkrainianNLP()
        self.memory = ConversationMemory(max_messages=5)
        self.intent_detector = IntentDetector(self.project_root / "data" / "intents.json", self.nlp)
        self.lua_assistant = LuaAssistant(self.project_root / "data" / "lua_examples.json", self.nlp)
        self.last_intent_name = "capability_help"

    def chat(self, message: str) -> str:
        cleaned = message.strip()
        if not cleaned:
            return "\u0411\u0443\u0434\u044c \u043b\u0430\u0441\u043a\u0430, \u0432\u0432\u0435\u0434\u0456\u0442\u044c \u043f\u043e\u0432\u0456\u0434\u043e\u043c\u043b\u0435\u043d\u043d\u044f."

        history = self.memory.recent_messages(5)
        intent = self.intent_detector.detect(cleaned, history)
        related = self.intent_detector.retrieve_related(cleaned, limit=3)
        response = self._build_response(cleaned, intent, related)

        self.memory.add("user", cleaned)
        self.memory.add("assistant", response)
        self.last_intent_name = intent["name"]
        return response

    def _build_response(self, message: str, intent: dict[str, object], related: list[dict[str, object]]) -> str:
        normalized = self.nlp.normalize(message, keep_code=True)
        last_code = self.memory.latest_code()
        topic_hint = self.lua_assistant.last_topic

        if self._should_fix_lua(intent["name"], normalized):
            return self.lua_assistant.fix_code(
                message,
                context_text=self.memory.context_as_text(),
                fallback_code=last_code,
            )

        if self._should_explain_lua(intent["name"], normalized):
            return self.lua_assistant.explain_code(
                message,
                context_text=self.memory.context_as_text(),
                fallback_code=last_code,
            )

        if self._should_generate_lua(intent["name"], normalized):
            return self.lua_assistant.generate_code(
                message,
                context_text=self.memory.context_as_text(),
                topic_hint=topic_hint,
            )

        if intent["name"] in {"greeting", "capability_help", "thanks"}:
            return intent["intent"].get("template", "") or self._generic_response()

        if intent["name"] == "roblox_http":
            return self._roblox_http_response()

        if intent["name"] == "python_api":
            return self._python_api_response()

        if self.last_intent_name.startswith("lua_") and len(self.nlp.keywords(message)) <= 3:
            return self.lua_assistant.generate_code(
                message,
                context_text=self.memory.context_as_text(),
                topic_hint=topic_hint,
            )

        if related and related[0]["intent"]["name"] == "roblox_http":
            return self._roblox_http_response()

        return self._generic_response()

    def _should_generate_lua(self, intent_name: str, normalized: str) -> bool:
        generation_hints = [
            "\u043d\u0430\u043f\u0438\u0448\u0438",
            "\u0441\u0442\u0432\u043e\u0440\u0438",
            "\u0437\u0433\u0435\u043d\u0435\u0440\u0443\u0439",
            "\u043f\u0440\u0438\u043a\u043b\u0430\u0434",
            "\u043a\u043e\u0434",
            "\u0441\u043a\u0440\u0438\u043f\u0442",
        ]
        lua_hints = [
            "lua",
            "luau",
            "roblox",
            "\u0444\u0443\u043d\u043a\u0446",
            "\u0446\u0438\u043a\u043b",
            "\u0442\u0430\u0431\u043b\u0438\u0446",
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
            "\u043f\u043e\u044f\u0441\u043d\u0438",
            "\u0440\u043e\u0437\u0431\u0435\u0440\u0438",
            "\u0449\u043e \u0440\u043e\u0431\u0438\u0442\u044c",
            "\u043f\u043e\u044f\u0441\u043d\u0435\u043d\u043d\u044f",
            "\u0440\u043e\u0437\u043a\u0430\u0436\u0438",
        ]
        short_follow_up = self.last_intent_name == "lua_generate" and any(
            hint in normalized for hint in ["\u043f\u043e\u044f\u0441\u043d\u0438", "\u0440\u043e\u0437\u0431\u0435\u0440\u0438", "\u0446\u0435"]
        )
        return intent_name == "lua_explain" or any(hint in normalized for hint in explain_hints) or short_follow_up

    def _should_fix_lua(self, intent_name: str, normalized: str) -> bool:
        fix_hints = [
            "\u0432\u0438\u043f\u0440\u0430\u0432",
            "\u043f\u043e\u043b\u0430\u0433\u043e\u0434\u044c",
            "\u043d\u0435 \u043f\u0440\u0430\u0446\u044e\u0454",
            "\u043f\u043e\u043c\u0438\u043b\u043a\u0430",
            "fix",
            "\u0431\u0430\u0433",
            "error",
        ]
        return intent_name == "lua_fix" or any(hint in normalized for hint in fix_hints)

    def _roblox_http_response(self) -> str:
        return (
            "\u0414\u043b\u044f Roblox \u043a\u043b\u0456\u0454\u043d\u0442\u0430 \u0432\u0438\u043a\u043e\u0440\u0438\u0441\u0442\u043e\u0432\u0443\u0439\u0442\u0435 HttpService \u0456 POST \u043d\u0430 "
            "`http://127.0.0.1:5000/chat`.\n\n"
            "\u041f\u043e\u0440\u044f\u0434\u043e\u043a \u0440\u043e\u0431\u043e\u0442\u0438:\n"
            "- \u0423\u0432\u0456\u043c\u043a\u043d\u0456\u0442\u044c `Allow HTTP Requests` \u0443 Roblox Studio.\n"
            "- \u041d\u0430\u0434\u0441\u0438\u043b\u0430\u0439\u0442\u0435 JSON \u0432\u0438\u0434\u0443 `{ \"message\": \"...\" }`.\n"
            "- \u0427\u0438\u0442\u0430\u0439\u0442\u0435 \u043f\u043e\u043b\u0435 `response` \u0437 JSON-\u0432\u0456\u0434\u043f\u043e\u0432\u0456\u0434\u0456 \u0441\u0435\u0440\u0432\u0435\u0440\u0430."
        )

    def _python_api_response(self) -> str:
        return (
            "\u041b\u043e\u043a\u0430\u043b\u044c\u043d\u0438\u0439 Python \u0441\u0435\u0440\u0432\u0435\u0440 \u043f\u0440\u0430\u0446\u044e\u0454 \u0447\u0435\u0440\u0435\u0437 Flask \u0456 endpoint `POST /chat`.\n\n"
            "\u041f\u0440\u0438\u043a\u043b\u0430\u0434 \u0437\u0430\u043f\u0438\u0442\u0443:\n"
            "```json\n"
            "{\"message\": \"\u041d\u0430\u043f\u0438\u0448\u0438 Lua \u0444\u0443\u043d\u043a\u0446\u0456\u044e \u0434\u043b\u044f \u043c\u043e\u043d\u0435\u0442\"}\n"
            "```"
        )

    def _generic_response(self) -> str:
        return (
            "\u042f \u043f\u0440\u0430\u0446\u044e\u044e \u0443\u043a\u0440\u0430\u0457\u043d\u0441\u044c\u043a\u043e\u044e \u0456 \u043d\u0430\u0439\u043a\u0440\u0430\u0449\u0435 \u0434\u043e\u043f\u043e\u043c\u0430\u0433\u0430\u044e "
            "\u0437 Roblox Lua, \u043f\u043e\u044f\u0441\u043d\u0435\u043d\u043d\u044f\u043c \u043a\u043e\u0434\u0443, \u0432\u0438\u043f\u0440\u0430\u0432\u043b\u0435\u043d\u043d\u044f\u043c \u043f\u043e\u043c\u0438\u043b\u043e\u043a "
            "\u0442\u0430 \u043b\u043e\u043a\u0430\u043b\u044c\u043d\u0438\u043c Python API. \u041d\u0430\u043f\u0438\u0448\u0456\u0442\u044c \u0449\u043e\u0441\u044c \u043d\u0430 \u043a\u0448\u0442\u0430\u043b\u0442: "
            "`\u043d\u0430\u043f\u0438\u0448\u0438 Lua \u0446\u0438\u043a\u043b`, `\u043f\u043e\u044f\u0441\u043d\u0438 \u0446\u0435\u0439 \u0441\u043a\u0440\u0438\u043f\u0442`, "
            "`\u0432\u0438\u043f\u0440\u0430\u0432 \u043f\u043e\u043c\u0438\u043b\u043a\u0443 \u0432 \u043a\u043e\u0434\u0456` \u0430\u0431\u043e "
            "`\u044f\u043a \u043f\u0456\u0434\u043a\u043b\u044e\u0447\u0438\u0442\u0438 Roblox \u0434\u043e \u0441\u0435\u0440\u0432\u0435\u0440\u0430`."
        )
