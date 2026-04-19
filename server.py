import json
import os
from pathlib import Path

from flask import Flask, Response, request

from ai.response import UkrainianHybridAI


BASE_DIR = Path(__file__).resolve().parent
app = Flask(__name__)
assistant = UkrainianHybridAI(BASE_DIR)


def json_response(payload: dict[str, object], status: int = 200) -> Response:
    body = json.dumps(payload, ensure_ascii=False)
    return Response(body, status=status, content_type="application/json; charset=utf-8")


def text_response(body: str, status: int = 200) -> Response:
    return Response(body, status=status, content_type="text/plain; charset=utf-8")


@app.get("/health")
def health() -> Response:
    return json_response({"status": "ok", **assistant.status()})


@app.post("/chat")
def chat() -> Response:
    payload = request.get_json(silent=True) or {}
    message = str(payload.get("message", "")).strip()
    force_web = bool(payload.get("web", False))

    if not message:
        return json_response(
            {"response": "\u0411\u0443\u0434\u044c \u043b\u0430\u0441\u043a\u0430, \u0432\u0432\u0435\u0434\u0456\u0442\u044c \u043f\u043e\u0432\u0456\u0434\u043e\u043c\u043b\u0435\u043d\u043d\u044f \u0443 \u043f\u043e\u043b\u0456 message."},
            status=400,
        )

    try:
        return json_response({"response": assistant.chat(message, force_web=force_web)})
    except Exception as exc:  # pragma: no cover
        return json_response(
            {"response": f"\u0421\u0442\u0430\u043b\u0430\u0441\u044f \u043f\u043e\u043c\u0438\u043b\u043a\u0430 \u0441\u0435\u0440\u0432\u0435\u0440\u0430: {exc}"},
            status=500,
        )


@app.get("/chat_text")
def chat_text() -> Response:
    message = str(request.args.get("message", "")).strip()
    force_web = request.args.get("web", "").strip().lower() in {"1", "true", "yes", "on"}
    if not message:
        return text_response(
            "\u0411\u0443\u0434\u044c \u043b\u0430\u0441\u043a\u0430, \u043f\u0435\u0440\u0435\u0434\u0430\u0439\u0442\u0435 \u043f\u0430\u0440\u0430\u043c\u0435\u0442\u0440 message.",
            status=400,
        )

    try:
        return text_response(assistant.chat(message, force_web=force_web))
    except Exception as exc:  # pragma: no cover
        return text_response(
            f"\u0421\u0442\u0430\u043b\u0430\u0441\u044f \u043f\u043e\u043c\u0438\u043b\u043a\u0430 \u0441\u0435\u0440\u0432\u0435\u0440\u0430: {exc}",
            status=500,
        )


if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    app.run(host="0.0.0.0", port=port, debug=False)
