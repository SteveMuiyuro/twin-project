import functions_framework
import uuid

from resources import get_response


@functions_framework.http
def chat(request):
    # ✅ Handle CORS preflight
    if request.method == "OPTIONS":
        return ("", 204, {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type",
        })

    try:
        request_json = request.get_json(silent=True) or {}

        message = request_json.get("message", "")
        session_id = request_json.get("session_id") or str(uuid.uuid4())

        if not message:
            return (
                {"error": "Message is required"},
                400,
                {"Access-Control-Allow-Origin": "*"}
            )

        reply, session_id = get_response(message, session_id)

        return (
            {
                "response": reply,
                "session_id": session_id
            },
            200,
            {
                "Access-Control-Allow-Origin": "*"
            }
        )

    except Exception as e:
        return (
            {"error": str(e)},
            500,
            {"Access-Control-Allow-Origin": "*"}
        )