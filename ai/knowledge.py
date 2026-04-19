from __future__ import annotations

import json
import re
from pathlib import Path

from .nlp import UkrainianNLP


class KnowledgeBase:
    def __init__(self, knowledge_path: Path, nlp: UkrainianNLP) -> None:
        self.nlp = nlp
        self.entries = json.loads(Path(knowledge_path).read_text(encoding="utf-8"))
        self._prepared_entries: list[dict[str, object]] = []

        for entry in self.entries:
            aliases = [str(entry["name"]), *[str(alias) for alias in entry.get("aliases", [])]]
            normalized_aliases = [self.nlp.normalize(alias) for alias in aliases]
            keywords: set[str] = set()
            for alias in normalized_aliases:
                keywords.update(token for token in alias.split(" ") if token)
            self._prepared_entries.append(
                {
                    "entry": entry,
                    "aliases": normalized_aliases,
                    "keywords": sorted(keywords),
                }
            )

    def answer(self, message: str, context_text: str = "", last_assistant_message: str = "") -> str | None:
        normalized = self.nlp.normalize(message, keep_code=True)

        if reply := self._smalltalk_response(normalized):
            return reply

        if reply := self._follow_up_response(normalized, last_assistant_message):
            return reply

        if reply := self._comparison_response(message):
            return reply

        match = self._match_entry(f"{message} {context_text}")
        if not match:
            return None

        entry = match["entry"]
        relations = entry.get("relations", {})

        if "столиц" in normalized and relations.get("capital"):
            return f"Столиця {entry['name']} — {relations['capital']}."

        if any(phrase in normalized for phrase in ["де знаход", "де розташ", "на якому континент"]):
            if relations.get("continent"):
                return f"{entry['name'].capitalize()} пов'язана з регіоном {relations['continent']}."
            if relations.get("location"):
                return f"{entry['name'].capitalize()} розташований(а) так: {relations['location']}."

        summary = str(entry.get("summary", "")).strip()
        facts = [str(item).strip() for item in entry.get("facts", []) if str(item).strip()]
        related = [str(item).strip() for item in entry.get("related", []) if str(item).strip()]

        lines = [summary] if summary else []
        if facts:
            lines.append("")
            lines.append("Короткі факти:")
            lines.extend(f"- {fact}" for fact in facts[:3])
        if related:
            lines.append("")
            lines.append(f"Пов'язані теми: {', '.join(related[:4])}.")

        return "\n".join(lines).strip() or None

    def has_local_answer(self, message: str, context_text: str = "") -> bool:
        normalized = self.nlp.normalize(message, keep_code=True)
        if self._smalltalk_response(normalized):
            return True
        if self._comparison_response(message):
            return True
        return self._match_entry(f"{message} {context_text}") is not None

    def _match_entry(self, message: str) -> dict[str, object] | None:
        normalized = self.nlp.normalize(message)
        query_keywords = self.nlp.keywords(message)
        best_match: dict[str, object] | None = None
        best_score = 0.0

        for prepared in self._prepared_entries:
            alias_hit = any(alias and alias in normalized for alias in prepared["aliases"])
            keyword_score = self.nlp.overlap_score(query_keywords, prepared["keywords"])
            score = keyword_score + (0.55 if alias_hit else 0.0)
            if score > best_score:
                best_score = score
                best_match = prepared

        if best_score < 0.20:
            return None
        return best_match

    def _comparison_response(self, message: str) -> str | None:
        normalized = self.nlp.normalize(message, keep_code=True)
        if not any(hint in normalized for hint in ["порівняй", "різниця", "чим відрізня"]):
            return None

        names = [prepared["entry"]["name"] for prepared in self._prepared_entries if any(alias in normalized for alias in prepared["aliases"])]
        unique_names: list[str] = []
        for name in names:
            if name not in unique_names:
                unique_names.append(name)

        if len(unique_names) < 2:
            return None

        first = self._match_entry(unique_names[0])
        second = self._match_entry(unique_names[1])
        if not first or not second:
            return None

        left = first["entry"]
        right = second["entry"]
        return (
            f"Коротке порівняння {left['name']} і {right['name']}:\n"
            f"- {left['name']}: {left.get('summary', '')}\n"
            f"- {right['name']}: {right.get('summary', '')}\n\n"
            "Якщо хочеш, я можу далі порівняти їх простіше, детальніше або з прикладами."
        )

    def _follow_up_response(self, normalized: str, last_assistant_message: str) -> str | None:
        if not last_assistant_message:
            return None

        if normalized in {"коротко", "коротше", "простими словами", "простiше", "простіше"}:
            preview = last_assistant_message.strip().split("\n")[0]
            if len(preview) > 170:
                preview = preview[:167] + "..."
            return f"Коротко: {preview}"

        if normalized in {"детальніше", "більш детально", "поясни детальніше"}:
            return "Можу розкрити тему глибше. Напиши, що саме цікавить: визначення, приклади, порівняння чи практичне застосування."

        return None

    def _smalltalk_response(self, normalized: str) -> str | None:
        if any(phrase in normalized for phrase in ["хто ти", "що ти таке"]):
            return (
                "Я українськомовний AI-помічник для Roblox, Lua, Python і загальних питань. "
                "Тепер я можу не лише працювати з кодом, а й підтримувати звичайну розмову та, коли потрібно, шукати інформацію онлайн."
            )

        if any(phrase in normalized for phrase in ["як справи", "як ти", "що нового"]):
            return "Працюю нормально. Можу спілкуватися вільно, пояснювати теми простими словами, допомагати з кодом і шукати актуальну інформацію."

        if any(phrase in normalized for phrase in ["скільки тобі років", "ти живий", "ти людина"]):
            return "Я не людина і не маю віку. Я програмний асистент, який відповідає українською і підлаштовується під тему розмови."

        if any(phrase in normalized for phrase in ["що вмієш", "які можливості", "допомога"]):
            return (
                "Я можу: вести розмову українською, пояснювати загальні поняття, генерувати та виправляти Lua/Luau код, "
                "підказувати по Python і Roblox, а також шукати свіжу інформацію онлайн, якщо це ввімкнено."
            )

        return None
