from __future__ import annotations

import re
from collections import deque


class ConversationMemory:
    def __init__(self, max_messages: int = 5) -> None:
        self.messages: deque[dict[str, str]] = deque(maxlen=max_messages)

    def add(self, role: str, content: str) -> None:
        self.messages.append({"role": role, "content": content})

    def recent_messages(self, limit: int = 5) -> list[dict[str, str]]:
        return list(self.messages)[-limit:]

    def context_as_text(self, limit: int = 5) -> str:
        chunks: list[str] = []
        for message in self.recent_messages(limit):
            preview = message["content"].strip().replace("\n", " ")
            if len(preview) > 140:
                preview = preview[:137] + "..."
            chunks.append(f'{message["role"]}: {preview}')
        return "\n".join(chunks)

    def last_message(self, role: str | None = None) -> str:
        for message in reversed(self.messages):
            if role is None or message["role"] == role:
                return message["content"]
        return ""

    def latest_code(self) -> str:
        for message in reversed(self.messages):
            content = message["content"]
            fenced = re.search(r"```(?:lua)?\s*(.*?)```", content, flags=re.IGNORECASE | re.DOTALL)
            if fenced:
                return fenced.group(1).strip()
            if re.search(r"\b(local|function|if|for|while|return|end)\b", content):
                return content.strip()
        return ""
