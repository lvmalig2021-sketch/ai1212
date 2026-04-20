from __future__ import annotations

import json
from pathlib import Path

from .nlp import UkrainianNLP


class LearningStore:
    LEARN_PREFIXES = [
        "запам'ятай, що",
        "запам'ятай що",
        "запамятай, що",
        "запамятай що",
        "запам'ятай:",
        "запамятай:",
        "навчися:",
        "збережи факт:",
        "додай в базу знань:",
        "додай у базу знань:",
    ]

    def __init__(self, storage_path: Path, nlp: UkrainianNLP) -> None:
        self.storage_path = Path(storage_path)
        self.nlp = nlp
        self.notes: list[dict[str, object]] = []
        self._prepared_notes: list[dict[str, object]] = []
        self._load()

    def status(self) -> dict[str, object]:
        return {"notes_count": len(self.notes)}

    def learn(self, message: str) -> str | None:
        fact = self._extract_fact(message)
        if not fact:
            return None

        normalized = self.nlp.normalize(fact)
        if not normalized:
            return None

        for note in self.notes:
            if str(note.get("normalized", "")).strip() == normalized:
                return "Я вже маю цей факт у локальній базі знань."

        keywords = self.nlp.keywords(fact)[:8]
        note = {
            "title": self._build_title(fact, keywords),
            "text": fact,
            "normalized": normalized,
            "keywords": keywords,
        }
        self.notes.append(note)
        self._save()
        self._rebuild_index()
        return "Гаразд, я зберіг це у локальній базі знань і зможу використати пізніше."

    def answer(self, message: str, limit: int = 2) -> str | None:
        matches = self.find_relevant(message, limit=limit)
        if not matches:
            return None

        lines = ["У локальній базі знань я маю такі збережені нотатки:"]
        for note in matches:
            lines.append(f"- {note['text']}")
        return "\n".join(lines)

    def find_relevant(self, message: str, limit: int = 2) -> list[dict[str, object]]:
        query_keywords = self.nlp.keywords(message)
        normalized = self.nlp.normalize(message)
        if not query_keywords and not normalized:
            return []

        ranked: list[tuple[float, dict[str, object]]] = []
        for note in self._prepared_notes:
            keyword_score = self.nlp.overlap_score(query_keywords, note["keywords"])
            soft_score = self._soft_keyword_score(query_keywords, note["keywords"])
            exact_bonus = 0.35 if normalized and normalized in str(note["normalized"]) else 0.0
            score = keyword_score + soft_score + exact_bonus
            if score >= 0.14:
                ranked.append((score, note["note"]))

        ranked.sort(key=lambda item: item[0], reverse=True)
        return [note for _, note in ranked[:limit]]

    def _soft_keyword_score(self, query_keywords: list[str], note_keywords: list[str]) -> float:
        if not query_keywords or not note_keywords:
            return 0.0

        matched = 0
        for left in query_keywords:
            for right in note_keywords:
                if len(left) >= 4 and len(right) >= 4 and (left.startswith(right) or right.startswith(left)):
                    matched += 1
                    break
        return min(0.45, matched * 0.18)

    def _extract_fact(self, message: str) -> str:
        original = message.strip()
        lowered = original.lower()
        for prefix in self.LEARN_PREFIXES:
            if lowered.startswith(prefix):
                fact = original[len(prefix) :].strip(" :-")
                return fact.strip()
        return ""

    def _build_title(self, fact: str, keywords: list[str]) -> str:
        sentence = fact.split(".")[0].strip()
        if 8 <= len(sentence) <= 64:
            return sentence
        if keywords:
            return " ".join(keywords[:4]).strip().capitalize()
        if len(fact) <= 64:
            return fact
        return fact[:61].rstrip() + "..."

    def _load(self) -> None:
        if not self.storage_path.exists():
            self.storage_path.write_text("[]\n", encoding="utf-8")

        raw = self.storage_path.read_text(encoding="utf-8").strip() or "[]"
        try:
            loaded = json.loads(raw)
        except json.JSONDecodeError:
            loaded = []

        if not isinstance(loaded, list):
            loaded = []

        self.notes = [item for item in loaded if isinstance(item, dict)]
        self._rebuild_index()

    def _save(self) -> None:
        self.storage_path.write_text(
            json.dumps(self.notes, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    def _rebuild_index(self) -> None:
        self._prepared_notes = []
        for note in self.notes:
            text = str(note.get("text", "")).strip()
            normalized = str(note.get("normalized", "")).strip() or self.nlp.normalize(text)
            keywords = note.get("keywords", [])
            if not isinstance(keywords, list):
                keywords = []
            if not keywords:
                keywords = self.nlp.keywords(text)
            self._prepared_notes.append(
                {
                    "note": note,
                    "normalized": normalized,
                    "keywords": [str(item) for item in keywords if str(item).strip()],
                }
            )
