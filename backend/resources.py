from pypdf import PdfReader
import json
import os
from google.cloud import storage
import vertexai
from vertexai.generative_models import GenerativeModel

# -----------------------------
# Load local data (same as before)
# -----------------------------

try:
    reader = PdfReader("./data/linkedin.pdf")
    linkedin = ""
    for page in reader.pages:
        text = page.extract_text()
        if text:
            linkedin += text
except FileNotFoundError:
    linkedin = "LinkedIn profile not available"

with open("./data/summary.txt", "r", encoding="utf-8") as f:
    summary = f.read()

with open("./data/style.txt", "r", encoding="utf-8") as f:
    style = f.read()

with open("./data/facts.json", "r", encoding="utf-8") as f:
    facts = json.load(f)

# -----------------------------
# Initialize Vertex AI (Gemini)
# -----------------------------

PROJECT_ID = os.getenv("GCP_PROJECT")
REGION = os.getenv("GCP_REGION", "us-central1")

vertexai.init(project=PROJECT_ID, location=REGION)

model = GenerativeModel("gemini-1.5-flash")  # equivalent to "nano/micro"

# -----------------------------
# Memory (GCS)
# -----------------------------

storage_client = storage.Client()
MEMORY_BUCKET = os.getenv("MEMORY_BUCKET")


def save_memory(session_id, message, response):
    """Save conversation to GCS"""
    if not MEMORY_BUCKET:
        return

    bucket = storage_client.bucket(MEMORY_BUCKET)
    blob = bucket.blob(f"{session_id}.json")

    history = []

    if blob.exists():
        history = json.loads(blob.download_as_text())

    history.append({
        "user": message,
        "assistant": response
    })

    blob.upload_from_string(json.dumps(history))


def load_memory(session_id):
    """Load conversation from GCS"""
    if not MEMORY_BUCKET:
        return []

    bucket = storage_client.bucket(MEMORY_BUCKET)
    blob = bucket.blob(f"{session_id}.json")

    if blob.exists():
        return json.loads(blob.download_as_text())

    return []

# -----------------------------
# Main response function
# -----------------------------

def get_response(message, session_id=None):
    """Generate response using Vertex AI (Gemini)"""

    session_id = session_id or "default-session"

    history = load_memory(session_id)

    # Build conversation history
    history_text = ""
    for item in history[-5:]:  # last 5 messages
        history_text += f"User: {item['user']}\nAssistant: {item['assistant']}\n"

    prompt = f"""
You are an AI digital twin.

Use the following information:

Summary:
{summary}

Style:
{style}

Facts:
{facts}

LinkedIn:
{linkedin}

Conversation so far:
{history_text}

User: {message}
Assistant:
"""

    response = model.generate_content(prompt)
    reply = response.text

    # Save memory
    save_memory(session_id, message, reply)

    return reply, session_id