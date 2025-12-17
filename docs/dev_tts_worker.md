# Fish Speech (OpenAudio S1) Colab Worker Setup

This guide documents how to set up the Google Colab GPU worker for high-fidelity voice synthesis using Fish Speech / OpenAudio S1-mini.

> **OpenAudio S1** is ranked #1 on TTS-Arena2 with 99% voice accuracy and supports emotion control.

## Prerequisites

- Google account with Colab access
- Ngrok account and auth token (free tier)
- Reference audio file (`aura_reference.wav`) - 10-15 seconds of clear speech

---

## Notebook Setup

Create a new Colab notebook named `dev_tts_worker.ipynb` with the following cells:

### Cell 1: Install Dependencies

```python
# Install Fish Speech and networking tools
!pip install fish-speech uvicorn fastapi pyngrok nest_asyncio

# Download model weights (~4GB)
!pip install huggingface_hub[cli]
!huggingface-cli download fishaudio/openaudio-s1-mini --local-dir checkpoints/openaudio-s1-mini
```

### Cell 2: Upload Reference Audio

Use the Colab file browser (folder icon on left) to upload your reference voice file:
- **Filename**: `aura_reference.wav`
- **Requirements**: 10-15 seconds, clear audio, WAV format
- **Tip**: Use a calm, professional voice for best results

Also create a text file `aura_reference.lab` with the transcript of the reference audio.

```python
# Create references directory structure
!mkdir -p references/aura
!mv aura_reference.wav references/aura/sample.wav

# Create the label file with transcript (edit the text below)
with open("references/aura/sample.lab", "w") as f:
    f.write("Hello, I am Aura, your AI assistant. How can I help you today?")

print("✅ Reference audio configured!")
```

### Cell 3: Start API Server with Ngrok

```python
!pip install pyngrok
import subprocess
import threading
import time
import nest_asyncio
from pyngrok import ngrok

nest_asyncio.apply()

# ============================================================
# IMPORTANT: Replace with YOUR ngrok auth token
# Get it from: https://dashboard.ngrok.com/get-started/your-authtoken
# ============================================================
ngrok.set_auth_token("YOUR_NGROK_AUTH_TOKEN")

# Start Fish Speech API server in background
def start_server():
    subprocess.run([
        "python", "-m", "tools.api_server",
        "--listen", "0.0.0.0:8080",
        "--llama-checkpoint-path", "checkpoints/openaudio-s1-mini",
        "--decoder-checkpoint-path", "checkpoints/openaudio-s1-mini/codec.pth",
        "--decoder-config-name", "modded_dac_vq"
    ])

server_thread = threading.Thread(target=start_server, daemon=True)
server_thread.start()

# Wait for server to start
print("⏳ Starting Fish Speech server...")
time.sleep(30)

# Start ngrok tunnel
public_url = ngrok.connect(8080).public_url
print(f"\n{'='*60}")
print(f"🐟 Fish Speech (OpenAudio S1) Active!")
print(f"📡 Public URL: {public_url}")
print(f"{'='*60}")
print(f"\nCopy this URL to your TTS_WORKER_URL environment variable")
print(f"\nAPI Docs: {public_url}/docs")

# Keep alive
while True:
    time.sleep(60)
```

---

## API Usage

Fish Speech API endpoint for synthesis:

```bash
# Test the API
curl -X POST "{PUBLIC_URL}/v1/tts" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello, I am Aura!",
    "reference_id": "aura"
  }' \
  --output test.wav
```

### Emotion Control

Add emotion markers directly in text:
```
(excited) Hello! I am so happy to help you today!
(calm) Let me think about that for a moment.
(sad) I am sorry to hear that.
```

Available markers:
- **Basic**: `(angry)` `(sad)` `(excited)` `(surprised)` `(satisfied)` `(delighted)` `(scared)` `(worried)` `(nervous)` `(confident)` `(curious)` `(joyful)`
- **Tone**: `(whispering)` `(shouting)` `(soft tone)`
- **Effects**: `(laughing)` `(sighing)` `(chuckling)`

---

## Local Configuration

After running the Colab notebook, update your local environment:

### Option 1: .env File
```
TTS_WORKER_URL=https://your-ngrok-url.ngrok-free.app
AURA_ENV=DEV
```

### Option 2: Environment Variables
```bash
export TTS_WORKER_URL="https://your-ngrok-url.ngrok-free.app"
export AURA_ENV="DEV"
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Model download slow | Use Colab Pro for faster download |
| Server startup timeout | Increase sleep time to 60s |
| Ngrok tunnel expires | Get new URL and update environment |
| Audio sounds robotic | Use longer, clearer reference audio |

---

## Comparison: Fish Speech vs XTTS

| Feature | Fish Speech | XTTS-v2 |
|---------|-------------|---------|
| TTS-Arena Rank | #1 | - |
| Voice Accuracy | 99% | ~90% |
| Emotion Control | ✅ Built-in markers | ❌ |
| Python 3.12 | ✅ | ❌ |
| VRAM Required | 4GB | 4GB |
| Languages | 40+ | 17 |
