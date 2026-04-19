from __future__ import annotations

import json
import re
from difflib import SequenceMatcher
from pathlib import Path

from .nlp import UkrainianNLP


class LuaAssistant:
    TOPIC_HINTS = {
        "loops": ["\u0446\u0438\u043a\u043b", "for", "while", "repeat", "\u0456\u0442\u0435\u0440\u0430\u0446", "\u043f\u0435\u0440\u0435\u0431\u0456\u0440"],
        "functions": ["\u0444\u0443\u043d\u043a\u0446", "function", "return", "\u0430\u0440\u0433\u0443\u043c\u0435\u043d\u0442"],
        "tables": ["table", "\u0442\u0430\u0431\u043b\u0438\u0446", "\u043c\u0430\u0441\u0438\u0432", "\u0441\u043b\u043e\u0432\u043d\u0438\u043a", "\u0434\u0430\u043d\u0456"],
        "conditions": ["if", "elseif", "else", "\u0443\u043c\u043e\u0432", "\u043f\u0435\u0440\u0435\u0432\u0456\u0440", "\u043b\u043e\u0433\u0456\u043a"],
        "roblox": ["roblox", "player", "gui", "button", "service", "part"],
    }

    def __init__(self, examples_path: Path, nlp: UkrainianNLP) -> None:
        self.nlp = nlp
        self.examples = json.loads(Path(examples_path).read_text(encoding="utf-8"))
        self.last_topic = "roblox"

    def detect_topic(self, message: str, topic_hint: str | None = None) -> str:
        normalized = self.nlp.normalize(message, keep_code=True)
        best_topic = self.last_topic
        best_score = 0

        for topic, hints in self.TOPIC_HINTS.items():
            score = sum(1 for hint in hints if hint in normalized)
            if score > best_score:
                best_score = score
                best_topic = topic

        if best_score > 0:
            return best_topic
        if topic_hint:
            return topic_hint
        return self.last_topic

    def retrieve_example(self, message: str, preferred_topic: str | None = None) -> dict[str, object]:
        normalized = self.nlp.normalize(message)
        query_keywords = self.nlp.keywords(message)
        best_match = self.examples[0]
        best_score = -1.0

        for example in self.examples:
            joined = " ".join(
                [
                    str(example["title"]),
                    str(example["use_case"]),
                    " ".join(example.get("keywords", [])),
                    str(example["explanation"]),
                ]
            )
            fuzzy = SequenceMatcher(None, normalized, self.nlp.normalize(joined)).ratio()
            keyword_score = self.nlp.overlap_score(query_keywords, example.get("keywords", []))
            topic_bonus = 0.25 if preferred_topic and example["topic"] == preferred_topic else 0.0
            score = (0.55 * fuzzy) + (0.45 * keyword_score) + topic_bonus
            if score > best_score:
                best_score = score
                best_match = example

        return best_match

    def generate_code(self, message: str, context_text: str = "", topic_hint: str | None = None) -> str:
        topic = self.detect_topic(f"{message} {context_text}", topic_hint=topic_hint)
        example = self.retrieve_example(f"{message} {context_text}", preferred_topic=topic)
        self.last_topic = topic

        if topic == "loops":
            code, notes = self._loop_example(message)
        elif topic == "functions":
            code, notes = self._function_example(message)
        elif topic == "tables":
            code, notes = self._table_example()
        elif topic == "conditions":
            code, notes = self._condition_example()
        else:
            code, notes = self._roblox_example(message)

        note_block = "\n".join(f"- {note}" for note in notes)
        return (
            "\u041e\u0441\u044c \u043f\u0440\u0438\u043a\u043b\u0430\u0434 Lua/Luau \u043a\u043e\u0434\u0443:\n\n"
            f"```lua\n{code}\n```\n\n"
            "\u041a\u043e\u0440\u043e\u0442\u043a\u0435 \u043f\u043e\u044f\u0441\u043d\u0435\u043d\u043d\u044f:\n"
            f"{note_block}\n\n"
            f"\u041e\u0440\u0456\u0454\u043d\u0442\u0438\u0440: {example['title']}."
        )

    def explain_code(self, message: str, context_text: str = "", fallback_code: str = "") -> str:
        code = self.nlp.extract_code_block(message) or fallback_code
        if not code:
            return (
                "\u041d\u0430\u0434\u0456\u0448\u043b\u0456\u0442\u044c Lua-\u043a\u043e\u0434, \u044f\u043a\u0438\u0439 \u0442\u0440\u0435\u0431\u0430 \u043f\u043e\u044f\u0441\u043d\u0438\u0442\u0438. "
                "\u042f \u043c\u043e\u0436\u0443 \u0440\u043e\u0437\u0456\u0431\u0440\u0430\u0442\u0438 \u0444\u0443\u043d\u043a\u0446\u0456\u0457, \u0446\u0438\u043a\u043b\u0438, \u0442\u0430\u0431\u043b\u0438\u0446\u0456, \u0443\u043c\u043e\u0432\u0438 \u0442\u0430 Roblox API."
            )

        self.last_topic = self.detect_topic(f"{code} {context_text}")
        details: list[str] = []
        warnings: list[str] = []

        if re.search(r"\b(local\s+)?function\b", code):
            details.append("\u0423 \u043a\u043e\u0434\u0456 \u0454 \u0444\u0443\u043d\u043a\u0446\u0456\u044f, \u0442\u043e\u0431\u0442\u043e \u043b\u043e\u0433\u0456\u043a\u0430 \u0437\u0456\u0431\u0440\u0430\u043d\u0430 \u0432 \u043e\u043a\u0440\u0435\u043c\u0438\u0439 \u0431\u043b\u043e\u043a.")
        if re.search(r"\bfor\b", code):
            details.append("\u0412\u0438\u043a\u043e\u0440\u0438\u0441\u0442\u0430\u043d\u043e \u0446\u0438\u043a\u043b for \u0434\u043b\u044f \u043f\u043e\u0432\u0442\u043e\u0440\u0456\u0432 \u0430\u0431\u043e \u043f\u0435\u0440\u0435\u0431\u043e\u0440\u0443.")
        if re.search(r"\bwhile\b", code):
            details.append("\u0404 \u0446\u0438\u043a\u043b while, \u0442\u043e\u043c\u0443 \u043a\u043e\u0434 \u043f\u0440\u0430\u0446\u044e\u0454, \u043f\u043e\u043a\u0438 \u0443\u043c\u043e\u0432\u0430 \u0456\u0441\u0442\u0438\u043d\u043d\u0430.")
        if re.search(r"\bif\b", code):
            details.append("\u0404 \u0443\u043c\u043e\u0432\u043d\u0430 \u043f\u0435\u0440\u0435\u0432\u0456\u0440\u043a\u0430 if.")
        if "{" in code and "}" in code:
            details.append("\u0423 \u043a\u043e\u0434\u0456 \u0454 \u0442\u0430\u0431\u043b\u0438\u0446\u044f Lua.")
        if "game:GetService" in code:
            details.append("\u0421\u043a\u0440\u0438\u043f\u0442 \u0437\u0432\u0435\u0440\u0442\u0430\u0454\u0442\u044c\u0441\u044f \u0434\u043e Roblox API \u0447\u0435\u0440\u0435\u0437 game:GetService.")
        if "MouseButton1Click" in code:
            details.append("\u041e\u0431\u0440\u043e\u0431\u043b\u044f\u0454\u0442\u044c\u0441\u044f \u043d\u0430\u0442\u0438\u0441\u043a\u0430\u043d\u043d\u044f \u043a\u043d\u043e\u043f\u043a\u0438 GUI.")
        if re.search(r"\breturn\b", code):
            details.append("return \u043f\u043e\u0432\u0435\u0440\u0442\u0430\u0454 \u0440\u0435\u0437\u0443\u043b\u044c\u0442\u0430\u0442 \u0437 \u0444\u0443\u043d\u043a\u0446\u0456\u0457.")

        if re.search(r"^\s*[A-Za-z_][A-Za-z0-9_]*\s*=", code, flags=re.MULTILINE) and "local " not in code:
            warnings.append("\u0404 \u0440\u0438\u0437\u0438\u043a \u0433\u043b\u043e\u0431\u0430\u043b\u044c\u043d\u0438\u0445 \u0437\u043c\u0456\u043d\u043d\u0438\u0445. \u0427\u0430\u0441\u0442\u043e \u043a\u0440\u0430\u0449\u0435 \u0432\u0438\u043a\u043e\u0440\u0438\u0441\u0442\u0430\u0442\u0438 local.")
        if "wait(" in code:
            warnings.append("\u0423 Luau \u0447\u0430\u0441\u0442\u043e \u043a\u0440\u0430\u0449\u0435 \u0432\u0438\u043a\u043e\u0440\u0438\u0441\u0442\u0430\u0442\u0438 task.wait() \u0437\u0430\u043c\u0456\u0441\u0442\u044c wait().")

        if not details:
            details.append("\u0426\u0435 \u043d\u0435\u0432\u0435\u043b\u0438\u043a\u0438\u0439 Lua-\u0444\u0440\u0430\u0433\u043c\u0435\u043d\u0442 \u0431\u0435\u0437 \u0441\u043a\u043b\u0430\u0434\u043d\u0438\u0445 \u043a\u043e\u043d\u0441\u0442\u0440\u0443\u043a\u0446\u0456\u0439.")
        if not warnings:
            warnings.append("\u041a\u0440\u0438\u0442\u0438\u0447\u043d\u0438\u0445 \u043f\u0440\u043e\u0431\u043b\u0435\u043c \u0443 \u0441\u0442\u0440\u0443\u043a\u0442\u0443\u0440\u0456 \u043d\u0435 \u0432\u0438\u0434\u043d\u043e.")

        detail_block = "\n".join(f"- {item}" for item in details)
        warning_block = "\n".join(f"- {item}" for item in warnings)
        return (
            "\u041f\u043e\u044f\u0441\u043d\u0435\u043d\u043d\u044f \u043a\u043e\u0434\u0443:\n\n"
            f"{detail_block}\n\n"
            "\u041d\u0430 \u0449\u043e \u0437\u0432\u0435\u0440\u043d\u0443\u0442\u0438 \u0443\u0432\u0430\u0433\u0443:\n"
            f"{warning_block}"
        )

    def fix_code(self, message: str, context_text: str = "", fallback_code: str = "") -> str:
        code = self.nlp.extract_code_block(message) or fallback_code
        if not code:
            return "\u041d\u0430\u0434\u0456\u0448\u043b\u0456\u0442\u044c Lua-\u043a\u043e\u0434 \u0437 \u043f\u043e\u043c\u0438\u043b\u043a\u043e\u044e, \u0456 \u044f \u0437\u0430\u043f\u0440\u043e\u043f\u043e\u043d\u0443\u044e \u0432\u0438\u043f\u0440\u0430\u0432\u043b\u0435\u043d\u0443 \u0432\u0435\u0440\u0441\u0456\u044e."

        fixed, issues = self._auto_fix_code(code)
        self.last_topic = self.detect_topic(f"{fixed} {context_text}")
        issue_block = "\n".join(f"- {issue}" for issue in issues) if issues else "- \u042f\u0432\u043d\u0438\u0445 \u0441\u0438\u043d\u0442\u0430\u043a\u0441\u0438\u0447\u043d\u0438\u0445 \u043f\u0440\u043e\u0431\u043b\u0435\u043c \u043d\u0435 \u0437\u043d\u0430\u0439\u0448\u043e\u0432."
        return (
            "\u0419\u043c\u043e\u0432\u0456\u0440\u043d\u0456 \u043f\u0440\u043e\u0431\u043b\u0435\u043c\u0438:\n"
            f"{issue_block}\n\n"
            "\u041c\u043e\u0436\u043b\u0438\u0432\u0430 \u0432\u0438\u043f\u0440\u0430\u0432\u043b\u0435\u043d\u0430 \u0432\u0435\u0440\u0441\u0456\u044f:\n\n"
            f"```lua\n{fixed}\n```"
        )

    def _loop_example(self, message: str) -> tuple[str, list[str]]:
        normalized = self.nlp.normalize(message, keep_code=True)
        if "while" in normalized or "\u043f\u043e\u043a\u0438" in normalized:
            code = (
                "local attempt = 1\n\n"
                "while attempt <= 5 do\n"
                "    print(\"Attempt:\", attempt)\n"
                "    attempt = attempt + 1\n"
                "end"
            )
            notes = [
                "\u0417\u043c\u0456\u043d\u043d\u0430 attempt \u0437\u0431\u0435\u0440\u0456\u0433\u0430\u0454 \u043d\u043e\u043c\u0435\u0440 \u043f\u043e\u0442\u043e\u0447\u043d\u043e\u0457 \u0441\u043f\u0440\u043e\u0431\u0438.",
                "while \u043f\u0440\u0430\u0446\u044e\u0454, \u043f\u043e\u043a\u0438 attempt <= 5.",
                "\u0412\u0441\u0435\u0440\u0435\u0434\u0438\u043d\u0456 \u0446\u0438\u043a\u043b\u0443 \u043b\u0456\u0447\u0438\u043b\u044c\u043d\u0438\u043a \u0437\u0431\u0456\u043b\u044c\u0448\u0443\u0454\u0442\u044c\u0441\u044f.",
            ]
            return code, notes

        code = (
            "for index = 1, 5 do\n"
            "    print(\"Step:\", index)\n"
            "end"
        )
        notes = [
            "for \u0437\u0430\u043f\u0443\u0441\u043a\u0430\u0454 \u0431\u043b\u043e\u043a \u043a\u043e\u0434\u0443 5 \u0440\u0430\u0437\u0456\u0432.",
            "index \u0430\u0432\u0442\u043e\u043c\u0430\u0442\u0438\u0447\u043d\u043e \u0437\u043c\u0456\u043d\u044e\u0454\u0442\u044c\u0441\u044f \u0432\u0456\u0434 1 \u0434\u043e 5.",
            "\u0422\u0430\u043a\u0438\u0439 \u0446\u0438\u043a\u043b \u0437\u0440\u0443\u0447\u043d\u0438\u0439 \u0434\u043b\u044f \u043f\u043e\u0432\u0442\u043e\u0440\u0456\u0432.",
        ]
        return code, notes

    def _function_example(self, message: str) -> tuple[str, list[str]]:
        normalized = self.nlp.normalize(message, keep_code=True)
        if "coin" in normalized or "\u043c\u043e\u043d\u0435\u0442" in normalized or "\u0433\u0440\u0430\u0432" in normalized:
            code = (
                "local function giveCoins(player, amount)\n"
                "    local leaderstats = player:FindFirstChild(\"leaderstats\")\n"
                "    if not leaderstats then\n"
                "        return\n"
                "    end\n\n"
                "    local coins = leaderstats:FindFirstChild(\"Coins\")\n"
                "    if coins then\n"
                "        coins.Value = coins.Value + amount\n"
                "    end\n"
                "end"
            )
            notes = [
                "\u0424\u0443\u043d\u043a\u0446\u0456\u044f \u043f\u0440\u0438\u0439\u043c\u0430\u0454 player \u0456 amount.",
                "\u041f\u0435\u0440\u0435\u0432\u0456\u0440\u043a\u0430 leaderstats \u0437\u0430\u0445\u0438\u0449\u0430\u0454 \u0432\u0456\u0434 nil.",
                "\u042f\u043a\u0449\u043e Coins \u0456\u0441\u043d\u0443\u0454, \u0434\u043e \u043d\u044c\u043e\u0433\u043e \u0434\u043e\u0434\u0430\u0454\u0442\u044c\u0441\u044f amount.",
            ]
            return code, notes

        code = (
            "local function calculateDamage(baseDamage, level)\n"
            "    local bonus = level * 2\n"
            "    return baseDamage + bonus\n"
            "end\n\n"
            "local totalDamage = calculateDamage(10, 5)\n"
            "print(\"Total damage:\", totalDamage)"
        )
        notes = [
            "\u0424\u0443\u043d\u043a\u0446\u0456\u044f \u043f\u0440\u0438\u0439\u043c\u0430\u0454 \u0434\u0432\u0430 \u0430\u0440\u0433\u0443\u043c\u0435\u043d\u0442\u0438.",
            "return \u043f\u043e\u0432\u0435\u0440\u0442\u0430\u0454 \u0440\u0435\u0437\u0443\u043b\u044c\u0442\u0430\u0442 \u043e\u0431\u0447\u0438\u0441\u043b\u0435\u043d\u043d\u044f.",
            "\u041f\u0456\u0441\u043b\u044f \u0446\u044c\u043e\u0433\u043e \u0444\u0443\u043d\u043a\u0446\u0456\u044f \u0432\u0438\u043a\u043b\u0438\u043a\u0430\u0454\u0442\u044c\u0441\u044f \u0437 \u043a\u043e\u043d\u043a\u0440\u0435\u0442\u043d\u0438\u043c\u0438 \u0437\u043d\u0430\u0447\u0435\u043d\u043d\u044f\u043c\u0438.",
        ]
        return code, notes

    def _table_example(self) -> tuple[str, list[str]]:
        code = (
            "local playerData = {\n"
            "    Name = \"Builder\",\n"
            "    Level = 12,\n"
            "    Inventory = {\"Sword\", \"Potion\", \"Key\"}\n"
            "}\n\n"
            "print(playerData.Name)\n\n"
            "for index, item in ipairs(playerData.Inventory) do\n"
            "    print(index, item)\n"
            "end"
        )
        notes = [
            "\u0422\u0430\u0431\u043b\u0438\u0446\u044f playerData \u0437\u0431\u0435\u0440\u0456\u0433\u0430\u0454 \u043f\u043e\u0432'\u044f\u0437\u0430\u043d\u0456 \u0434\u0430\u043d\u0456.",
            "\u0414\u043e \u043f\u043e\u043b\u0456\u0432 \u043c\u043e\u0436\u043d\u0430 \u0437\u0432\u0435\u0440\u0442\u0430\u0442\u0438\u0441\u044f \u0447\u0435\u0440\u0435\u0437 \u043a\u0440\u0430\u043f\u043a\u0443.",
            "ipairs \u0437\u0440\u0443\u0447\u043d\u0438\u0439 \u0434\u043b\u044f \u043f\u0435\u0440\u0435\u0431\u043e\u0440\u0443 \u0441\u043f\u0438\u0441\u043a\u0443.",
        ]
        return code, notes

    def _condition_example(self) -> tuple[str, list[str]]:
        code = (
            "local coins = 120\n"
            "local price = 80\n\n"
            "if coins >= price then\n"
            "    print(\"Purchase allowed\")\n"
            "elseif coins > 0 then\n"
            "    print(\"Not enough coins yet\")\n"
            "else\n"
            "    print(\"No coins\")\n"
            "end"
        )
        notes = [
            "if \u043f\u0435\u0440\u0435\u0432\u0456\u0440\u044f\u0454 \u0433\u043e\u043b\u043e\u0432\u043d\u0443 \u0443\u043c\u043e\u0432\u0443.",
            "elseif \u0441\u043f\u0440\u0430\u0446\u044c\u043e\u0432\u0443\u0454 \u044f\u043a\u0449\u043e \u043f\u0435\u0440\u0448\u0430 \u0443\u043c\u043e\u0432\u0430 \u0445\u0438\u0431\u043d\u0430.",
            "else \u043e\u0431\u0440\u043e\u0431\u043b\u044f\u0454 \u043e\u0441\u0442\u0430\u043d\u043d\u0456\u0439 \u0432\u0438\u043f\u0430\u0434\u043e\u043a.",
        ]
        return code, notes

    def _roblox_example(self, message: str) -> tuple[str, list[str]]:
        normalized = self.nlp.normalize(message, keep_code=True)
        if "button" in normalized or "gui" in normalized or "\u043a\u043d\u043e\u043f" in normalized:
            code = (
                "local button = script.Parent\n\n"
                "button.MouseButton1Click:Connect(function()\n"
                "    print(\"Button clicked\")\n"
                "end)"
            )
            notes = [
                "script.Parent \u0443 \u0446\u044c\u043e\u043c\u0443 \u043f\u0440\u0438\u043a\u043b\u0430\u0434\u0456 \u043c\u0430\u0454 \u0431\u0443\u0442\u0438 \u043a\u043d\u043e\u043f\u043a\u043e\u044e.",
                "MouseButton1Click \u0441\u043f\u0440\u0430\u0446\u044c\u043e\u0432\u0443\u0454 \u043f\u0456\u0441\u043b\u044f \u043a\u043b\u0456\u043a\u0443.",
                "\u0423\u0441\u0435\u0440\u0435\u0434\u0438\u043d\u0456 \u043c\u043e\u0436\u043d\u0430 \u0432\u0438\u043a\u043b\u0438\u043a\u0430\u0442\u0438 \u0456\u0433\u0440\u043e\u0432\u0443 \u043b\u043e\u0433\u0456\u043a\u0443.",
            ]
            return code, notes

        code = (
            "local Players = game:GetService(\"Players\")\n"
            "local player = Players.LocalPlayer\n\n"
            "if player then\n"
            "    print(\"Hello, \" .. player.Name)\n"
            "end"
        )
        notes = [
            "game:GetService \u043e\u0442\u0440\u0438\u043c\u0443\u0454 \u0441\u0435\u0440\u0432\u0456\u0441 Players.",
            "LocalPlayer \u0434\u043e\u0441\u0442\u0443\u043f\u043d\u0438\u0439 \u0443 LocalScript.",
            "\u041f\u0435\u0440\u0435\u0432\u0456\u0440\u043a\u0430 if \u0437\u0430\u0445\u0438\u0449\u0430\u0454 \u0432\u0456\u0434 nil.",
        ]
        return code, notes

    def _auto_fix_code(self, code: str) -> tuple[str, list[str]]:
        issues: list[str] = []
        fixed_lines: list[str] = []

        for raw_line in code.splitlines():
            line = raw_line.rstrip()
            stripped = line.strip()

            if re.match(r"^if\s+.+$", stripped) and "then" not in stripped:
                line += " then"
                issues.append("\u0414\u043e\u0434\u0430\u043d\u043e then \u0434\u043e if.")
            elif re.match(r"^elseif\s+.+$", stripped) and "then" not in stripped:
                line += " then"
                issues.append("\u0414\u043e\u0434\u0430\u043d\u043e then \u0434\u043e elseif.")
            elif re.match(r"^for\s+.+$", stripped) and "do" not in stripped:
                line += " do"
                issues.append("\u0414\u043e\u0434\u0430\u043d\u043e do \u0434\u043e for.")
            elif re.match(r"^while\s+.+$", stripped) and "do" not in stripped:
                line += " do"
                issues.append("\u0414\u043e\u0434\u0430\u043d\u043e do \u0434\u043e while.")

            match = re.match(r"^(\s*)(if|elseif)\s+(.+?)\s+then\s*$", line)
            if match:
                indent, keyword, condition = match.groups()
                if "==" not in condition and "~=" not in condition and re.search(r"\s=\s", condition):
                    line = f"{indent}{keyword} {re.sub(r'\\s=\\s', ' == ', condition, count=1)} then"
                    issues.append("\u0417\u0430\u043c\u0456\u043d\u0435\u043d\u043e = \u043d\u0430 == \u0432 \u0443\u043c\u043e\u0432\u0456.")

            fixed_lines.append(line)

        fixed = "\n".join(fixed_lines).strip()
        openings = 0
        closings = 0
        for raw_line in fixed.splitlines():
            stripped = raw_line.strip()
            if re.match(r"^(local\s+)?function\b", stripped):
                openings += 1
            elif re.match(r"^if\b.+\bthen$", stripped):
                openings += 1
            elif re.match(r"^for\b.+\bdo$", stripped):
                openings += 1
            elif re.match(r"^while\b.+\bdo$", stripped):
                openings += 1
            elif re.match(r"^repeat\b", stripped):
                openings += 1

            if re.match(r"^end\b", stripped):
                closings += 1
            elif re.match(r"^until\b", stripped):
                closings += 1

        if openings > closings:
            missing = openings - closings
            fixed = fixed + ("\n" if fixed else "") + "\n".join("end" for _ in range(missing))
            issues.append(f"\u0414\u043e\u0434\u0430\u043d\u043e {missing} \u0437\u0430\u043a\u0440\u0438\u0432\u0430\u043b\u044c\u043d\u0438\u0439 end.")

        return fixed, list(dict.fromkeys(issues))
