import functions_framework
import os
import json
import uuid
from datetime import datetime
from typing import List, Dict

from context import prompt

# Memory directory
MEMORY_DIR = "./memory"


def get_memory_path(session_id: str) -> str:
    return f"{session_id}.json"


def load_conversation(session_id: str) -> List[Dict]:
    file_path = os.path.join(MEMORY_DIR, get_memory_path(session_id))

    if os.path.exists(file_path):
        with open(file_path, "r") as f:
            return json.load(f)

    return []


def save_conversation(session_id: str, messages: List[Dict]):
    os.makedirs(MEMORY_DIR, exist_ok=True)

    file_path = os.path.join(MEMORY_DIR, get_memory_path(session_id))

    with open(file_path, "w") as f:
        json.dump(messages, f, indent=2)


@functions_framework.http
def chat(request):
    try:
        data = request.get_json()
        user_message = data.get("message", "")
        session_id = data.get("session_id") or str(uuid.uuid4())

        conversation = load_conversation(session_id)

        # Build messages
        messages = [{"role": "system", "content": prompt()}]

        for msg in conversation[-10:]:
            messages.append({"role": msg["role"], "content": msg["content"]})

        messages.append({"role": "user", "content": user_message})

        # 🔥 TEMP RESPONSE (we plug Vertex AI next)
        assistant_response = f"Echo: {user_message}"

        # Save conversation
        conversation.append({
            "role": "user",
            "content": user_message,
            "timestamp": datetime.now().isoformat()
        })

        conversation.append({
            "role": "assistant",
            "content": assistant_response,
            "timestamp": datetime.now().isoformat()
        })

        save_conversation(session_id, conversation)

        return {
            "response": assistant_response,
            "session_id": session_id
        }

    except Exception as e:
        return {"error": str(e)}, 500