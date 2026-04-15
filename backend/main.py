import json
import os
from resources import get_response  # assuming your logic is here


def chat(request):
    """HTTP Cloud Function entry point"""

    # Handle CORS (important for frontend)
    if request.method == "OPTIONS":
        return ("", 204, {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "POST",
            "Access-Control-Allow-Headers": "Content-Type",
        })

    try:
        request_json = request.get_json()

        message = request_json.get("message")
        session_id = request_json.get("session_id")

        # Call your existing logic
        response_text, session_id = get_response(message, session_id)

        return (
            json.dumps({
                "response": response_text,
                "session_id": session_id
            }),
            200,
            {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            }
        )

    except Exception as e:
        return (
            json.dumps({"error": str(e)}),
            500,
            {"Access-Control-Allow-Origin": "*"}
        )