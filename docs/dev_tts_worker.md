# XTTS-v2 Colab Worker Setup Guide

This guide documents how to set up the Google Colab GPU worker for high-fidelity voice synthesis using Coqui XTTS-v2.

## Prerequisites

- Google account with Colab access
- Ngrok account and auth token (free tier)
- Reference audio file (`aura_reference.wav`) - 10-15 seconds of clear speech

---

## Notebook Setup

Create a new Colab notebook named `dev_tts_worker.ipynb` with the following cells:

### Cell 1: Install Dependencies

```python
# Install Coqui TTS and networking tools
!pip install TTS uvicorn fastapi pyngrok python-multipart nest_asyncio scipy
```

### Cell 2: Initialize Model

```python
import torch
from TTS.api import TTS

# Check for GPU
device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"🚀 Loading XTTS-v2 on {device}...")

# Initialize XTTS-v2 (Multi-lingual, Voice Cloning)
# This downloads the ~2GB model on first run
tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2").to(device)

print("✅ Model Loaded!")
```

### Cell 3: Upload Reference Audio

Use the Colab file browser (folder icon on left) to upload your reference voice file:
- **Filename**: `aura_reference.wav`
- **Requirements**: 10-15 seconds, clear audio, WAV format
- **Tip**: Use a calm, professional voice for best results

### Cell 4: Start API Server

```python
from fastapi import FastAPI, Response
import uvicorn
import nest_asyncio
from pyngrok import ngrok
import io
import numpy as np
import scipy.io.wavfile

app = FastAPI()

@app.get("/health")
async def health():
    return {"status": "healthy", "model": "xtts-v2"}

@app.post("/synthesize")
async def synthesize(text: str, language: str = "en"):
    """
    Generates audio from text using the reference voice style.
    Returns: WAV audio bytes (24kHz).
    """
    try:
        # Generate audio using reference voice
        wav = tts.tts(
            text=text, 
            language=language, 
            speaker_wav="aura_reference.wav",
            speed=1.0  # Increase to 1.2 for snappier responses
        )
        
        # Convert to WAV bytes
        byte_io = io.BytesIO()
        scipy.io.wavfile.write(byte_io, 24000, np.array(wav))
        
        return Response(content=byte_io.getvalue(), media_type="audio/wav")
    except Exception as e:
        return Response(content=str(e), status_code=500)

# ============================================================
# IMPORTANT: Replace with YOUR ngrok auth token
# Get it from: https://dashboard.ngrok.com/get-started/your-authtoken
# ============================================================
ngrok.set_auth_token("YOUR_NGROK_AUTH_TOKEN")

# Start tunnel
public_url = ngrok.connect(8001).public_url
print(f"\n{'='*60}")
print(f"🎙️ XTTS Voice Factory Active!")
print(f"📡 Public URL: {public_url}")
print(f"{'='*60}")
print(f"\nCopy this URL to your TTS_WORKER_URL environment variable")

# Start server
nest_asyncio.apply()
uvicorn.run(app, port=8001)
```

---

## Local Configuration

After running the Colab notebook, update your local environment:

### Option 1: Environment Variables

```bash
export TTS_WORKER_URL="https://your-ngrok-url.ngrok-free.app"
export AURA_ENV="DEV"
```

### Option 2: Kubernetes Secrets

```bash
kubectl create secret generic aura-secrets \
  --save-config \
  --dry-run=client \
  --from-literal=TTS_WORKER_URL="https://your-ngrok-url.ngrok-free.app" \
  --from-literal=AURA_ENV="DEV" \
  # ... other existing secrets ...
  -o yaml | kubectl apply -f -
```

### Option 3: .env File

Add to your `.env` file:

```
TTS_WORKER_URL=https://your-ngrok-url.ngrok-free.app
AURA_ENV=DEV
```

---

## Testing

### Direct Worker Test

```bash
curl -X POST "https://your-ngrok-url.ngrok-free.app/synthesize?text=Hello%20world" \
  --output test.wav
```

### Backend Integration Test

```bash
python scripts/test_voice_backend.py --host localhost --port 30000
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "CUDA out of memory" | Restart Colab runtime, only run one model |
| Ngrok tunnel expires | Get new URL and update environment |
| Slow first response | Normal - model warmup takes ~5s |
| Audio sounds robotic | Use longer, clearer reference audio |

---

## Production Migration

In production, XTTS-v2 runs as a K8s service instead of Colab:

```yaml
# Set environment variable
AURA_ENV=PROD

# The backend automatically uses:
# http://xtts-service.default.svc.cluster.local:8000
```
