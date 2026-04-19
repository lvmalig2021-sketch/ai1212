from __future__ import annotations

import re
from typing import Iterable


class UkrainianNLP:
    STOPWORDS = {
        "\u0430",
        "\u0430\u0431\u043e",
        "\u0430\u043b\u0435",
        "\u0431\u0443\u0434\u044c",
        "\u0431\u0443\u0434\u044c \u043b\u0430\u0441\u043a\u0430",
        "\u0432",
        "\u0432\u0438",
        "\u0432\u0441\u0435",
        "\u0434\u043b\u044f",
        "\u0434\u043e",
        "\u0456",
        "\u0456\u0437",
        "\u0439",
        "\u0437",
        "\u0437\u0430",
        "\u043a\u043e\u043b\u0438",
        "\u043c\u0435\u043d\u0456",
        "\u043c\u0438",
        "\u043d\u0430",
        "\u043d\u0435",
        "\u043d\u0456",
        "\u043f\u043e",
        "\u043f\u0440\u043e",
        "\u0442\u0430",
        "\u0442\u0438",
        "\u0442\u043e",
        "\u0443",
        "\u0446\u0435",
        "\u0446\u0435\u0439",
        "\u0449\u043e",
        "\u044f\u043a",
    }

    def normalize(self, text: str, keep_code: bool = False) -> str:
        if not text:
            return ""

        prepared = (
            text.replace("\u2019", "'")
            .replace("\u02bc", "'")
            .replace("`", "'")
            .replace("\u0451", "\u0435")
            .replace("\u044a", "")
            .lower()
            .strip()
        )

        if keep_code:
            return re.sub(r"\s+", " ", prepared).strip()

        prepared = re.sub("[^0-9a-z\u0430-\u044f\u0456\u0457\u0454\u0491_+#/\\-\\s]", " ", prepared, flags=re.IGNORECASE)
        return re.sub(r"\s+", " ", prepared).strip()

    def tokenize(self, text: str) -> list[str]:
        normalized = self.normalize(text)
        if not normalized:
            return []
        return [token for token in normalized.split(" ") if token]

    def keywords(self, text: str) -> list[str]:
        return [token for token in self.tokenize(text) if len(token) > 1 and token not in self.STOPWORDS]

    def overlap_score(self, source: Iterable[str], target: Iterable[str]) -> float:
        left = set(source)
        right = set(target)
        if not left or not right:
            return 0.0
        return len(left & right) / len(left | right)

    def contains_code(self, text: str) -> bool:
        if not text:
            return False

        patterns = [
            r"\blocal\b",
            r"\bfunction\b",
            r"\bif\b",
            r"\bthen\b",
            r"\bfor\b",
            r"\bwhile\b",
            r"\bend\b",
            r"game:GetService",
            r"script\.Parent",
            r"MouseButton1Click",
            r"==",
            r"\{",
            r"\}",
        ]
        return any(re.search(pattern, text, flags=re.IGNORECASE) for pattern in patterns)

    def extract_code_block(self, text: str) -> str:
        if not text:
            return ""

        fenced = re.search(r"```(?:lua)?\s*(.*?)```", text, flags=re.IGNORECASE | re.DOTALL)
        if fenced:
            return fenced.group(1).strip()

        code_lines = [
            line.rstrip()
            for line in text.splitlines()
            if re.search(
                r"\b(local|function|if|elseif|for|while|repeat|until|end|return)\b|=|\{|\}|game:GetService|MouseButton1Click",
                line,
                flags=re.IGNORECASE,
            )
        ]
        if len(code_lines) >= 2:
            return "\n".join(code_lines).strip()

        stripped = text.strip()
        return stripped if self.contains_code(stripped) else ""
