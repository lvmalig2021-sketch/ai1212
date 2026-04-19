from __future__ import annotations

import json
import os
from difflib import SequenceMatcher
from pathlib import Path

from .nlp import UkrainianNLP


class IntentDetector:
    def __init__(self, intents_path: Path, nlp: UkrainianNLP) -> None:
        self.nlp = nlp
        self.intents = json.loads(Path(intents_path).read_text(encoding="utf-8"))
        self.examples: list[dict[str, object]] = []
        self.embeddings_enabled = os.getenv("ENABLE_EMBEDDINGS", "0").lower() in {"1", "true", "yes"}
        self.embedder = None
        self.embedding_util = None
        self.example_vectors = None

        for intent in self.intents:
            for example in intent.get("examples", []):
                self.examples.append(
                    {
                        "intent": intent,
                        "example": example,
                        "normalized": self.nlp.normalize(example),
                        "keywords": self.nlp.keywords(example),
                    }
                )

        if self.embeddings_enabled:
            self._load_embeddings()

    def _load_embeddings(self) -> None:
        try:
            from sentence_transformers import SentenceTransformer, util

            model_name = os.getenv("AI_EMBED_MODEL", "paraphrase-multilingual-MiniLM-L12-v2")
            self.embedder = SentenceTransformer(model_name)
            self.embedding_util = util
            self.example_vectors = self.embedder.encode(
                [item["example"] for item in self.examples],
                convert_to_tensor=True,
            )
        except Exception:
            self.embedder = None
            self.embedding_util = None
            self.example_vectors = None

    def retrieve_related(self, message: str, limit: int = 3) -> list[dict[str, object]]:
        normalized = self.nlp.normalize(message)
        query_keywords = self.nlp.keywords(message)
        results: list[dict[str, object]] = []

        embedding_scores: list[float] = [0.0] * len(self.examples)
        if self.embedder is not None and self.example_vectors is not None:
            try:
                query_vector = self.embedder.encode(message, convert_to_tensor=True)
                cosine_scores = self.embedding_util.cos_sim(query_vector, self.example_vectors)[0]
                embedding_scores = [float(score) for score in cosine_scores]
            except Exception:
                embedding_scores = [0.0] * len(self.examples)

        for index, item in enumerate(self.examples):
            fuzzy_score = SequenceMatcher(None, normalized, item["normalized"]).ratio()
            keyword_score = self.nlp.overlap_score(query_keywords, item["keywords"])
            embedding_score = embedding_scores[index]
            combined = (0.45 * fuzzy_score) + (0.35 * keyword_score) + (0.20 * embedding_score)
            results.append(
                {
                    "intent": item["intent"],
                    "example": item["example"],
                    "score": combined,
                }
            )

        return sorted(results, key=lambda row: row["score"], reverse=True)[:limit]

    def detect(self, message: str, context_messages: list[dict[str, str]] | None = None) -> dict[str, object]:
        query_keywords = self.nlp.keywords(message)
        related = self.retrieve_related(message, limit=min(6, max(1, len(self.examples))))
        related_by_intent: dict[str, float] = {}
        for row in related:
            intent_name = row["intent"]["name"]
            current_score = related_by_intent.get(intent_name, 0.0)
            related_by_intent[intent_name] = max(current_score, row["score"])
        context_text = " ".join(item["content"] for item in (context_messages or []))
        context_keywords = self.nlp.keywords(context_text)

        ranked: list[dict[str, object]] = []
        for intent in self.intents:
            keyword_score = self.nlp.overlap_score(query_keywords, intent.get("keywords", []))
            example_score = related_by_intent.get(intent["name"], 0.0)
            context_score = 0.10 * self.nlp.overlap_score(context_keywords, intent.get("keywords", []))
            total_score = (0.55 * example_score) + (0.35 * keyword_score) + context_score
            ranked.append({"intent": intent, "score": total_score})

        ranked.sort(key=lambda row: row["score"], reverse=True)
        best = ranked[0] if ranked else {"intent": {"name": "capability_help"}, "score": 0.0}

        if best["score"] < 0.16:
            return {
                "name": "capability_help",
                "score": best["score"],
                "intent": next(
                    (intent for intent in self.intents if intent["name"] == "capability_help"),
                    {"name": "capability_help", "keywords": [], "template": ""},
                ),
            }

        return {"name": best["intent"]["name"], "score": best["score"], "intent": best["intent"]}
