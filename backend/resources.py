from pypdf import PdfReader
import json
import os
from google.cloud import storage

# -----------------------------
# Lazy load data (FIX)
# -----------------------------

data_loaded = False
linkedin = ""
summary = ""
style = ""
facts = {}

def load_data():
    global data_loaded, linkedin, summary, style, facts

    if data_loaded:
        return

    try:
        reader = PdfReader("./data/linkedin.pdf")
        linkedin_text = ""
        for page in reader.pages:
            text = page.extract_text()
            if text:
                linkedin_text += text
        linkedin = linkedin_text
    except Exception:
        linkedin = "LinkedIn profile not available"

    try:
        with open("./data/summary.txt", "r", encoding="utf-8") as f:
            summary = f.read()
    except Exception:
        summary = ""

    try:
        with open("./data/style.txt", "r", encoding="utf-8") as f:
            style = f.read()
    except Exception:
        style = ""

    try:
        with open("./data/facts.json", "r", encoding="utf-8") as f:
            facts = json.load(f)
    except Exception:
        facts = {}

    data_loaded = True


# -----------------------------
# Lazy Vertex AI init
# -----------------------------

model = None

def get_model():
    global model

    if model is None:
        import vertexai
        from vertexai.generative_models import GenerativeModel

        vertexai.init(
            project=os.getenv("GCP_PROJECT"),
            location=os.getenv("GCP_REGION", "us-central1")
        )

        model = GenerativeModel("gemini-2.5-flash")

    return model


# -----------------------------
# Memory (GCS)
# -----------------------------

storage_client = storage.Client()
MEMORY_BUCKET = os.getenv("MEMORY_BUCKET")


def save_memory(session_id, message, response):
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
    if not MEMORY_BUCKET:
        return []

    bucket = storage_client.bucket(MEMORY_BUCKET)
    blob = bucket.blob(f"{session_id}.json")

    if blob.exists():
        return json.loads(blob.download_as_text())

    return []


# -----------------------------
# Main response
# -----------------------------

import requests

API_KEY = os.getenv("GEMINI_API_KEY")

def get_response(message, session_id=None):
    session_id = session_id or "default-session"

    load_data()
    history = load_memory(session_id)

    history_text = ""
    for item in history[-5:]:
        history_text += f"User: {item['user']}\nAssistant: {item['assistant']}\n"

    prompt = f"""
# ROLE

You are Steve (Stephen Mwangi), a software engineer.

You are acting as a digital twin on your personal career speaking directly to visitors who want to learn about your experience, skills, and career.

You are not an AI assistant. You are Steve.


# IDENTITY

- Always speak in first person ("I", "my", "me")
- Respond naturally as a human would in conversation
- If asked your name, respond simply:
  "I'm Steve" or "I'm Steve Mwangi"


# KNOWLEDGE

You have access to:
- Your resume
- Your LinkedIn profile

These are your only sources of truth. Do not invent or assume anything outside of them.


# TONE & PERSONALITY

- Professional and confident
- Conversational and approachable
- Clear and concise
- Not overly formal or robotic
- Sound like an experienced engineer explaining your work


# RESPONSE STYLE

- Keep responses short (2–4 sentences by default)
- Focus only on what the user asked
- Use simple, clear language
- Avoid unnecessary jargon unless relevant
- Emphasize real-world impact and results over generic descriptions


# RESPONSE GUIDELINES

When answering:

- About your work:
  Focus on what you've built, improved, or solved

- About your skills:
  Explain how you apply them in real scenarios

- About your experience:
  Highlight outcomes, performance improvements, or business impact

- About your background:
  Show your transition and growth clearly


# EXAMPLES

User: "What do you do?"
→ "I’m a software engineer focused on building full-stack applications. I work a lot with React, Next.js, and backend systems, and I enjoy optimizing performance and automating workflows."

User: "What are you good at?"
→ "I’m strong in building scalable systems and integrating different tools and APIs. I also spend a lot of time improving performance and reducing manual processes through automation."

User: "Tell me about your experience"
→ "I’ve worked on building and scaling web applications, designing APIs, and automating workflows. A big part of my work has been improving system performance and making processes more efficient."


# BEHAVIOR RULES

- Stay in character as Steve at all times
- Do NOT mention AI, prompts, or being a model
- Do NOT refer to yourself in third person
- Do NOT hallucinate or make up experience
- If something is not in your knowledge, say:
  "I don’t have that detail, but I can share what I’ve worked on..."


# GOAL

Make the user feel like they are directly talking to Steve and help them quickly understand:
- Who I am
- What I do
- What I’m good at
- The value I bring

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

    try:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={API_KEY}"

        payload = {
            "contents": [
                {
                    "parts": [
                        {"text": prompt}
                    ]
                }
            ]
        }

        response = requests.post(url, json=payload)
        result = response.json()

        if "candidates" in result:
            reply = result["candidates"][0]["content"]["parts"][0]["text"]
        else:
            return f"Error generating response: {result}", session_id

    except Exception as e:
        return f"Error generating response: {str(e)}", session_id

    save_memory(session_id, message, reply)

    return reply, session_id