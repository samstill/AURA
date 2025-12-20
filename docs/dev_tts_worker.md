# Kokoro TTS Worker (Colab)

High-quality Hindi + English TTS using **Kokoro v0.19** (82M parameters) running on Google Colab.

## Quick Start

1. Open the Colab notebook: `temp/dev_tts_worker_kokoro.ipynb`
2. Enable GPU: Runtime → Change runtime type → T4 GPU
3. Run all cells
4. Copy the ngrok URL to your `.env`:
   ```
   TTS_WORKER_URL=https://your-kokoro-url.ngrok-free.dev
   ```
5. Restart backend: `./dev.sh`

## API Endpoint

```
POST /synthesize?text=Hello&language=h
```

| Param | Description |
|-------|-------------|
| `text` | Text to synthesize |
| `language` | `h` = Hindi, `a` = American English, `b` = British English |

**Response**: WAV audio (24kHz)

## Voices Available

| Voice | Description |
|-------|-------------|
| `af_bella` | Female, American (default) |
| `af_sarah` | Female, American |
| `hf_alpha` | Female, Hindi |
| `am_adam` | Male, American |

## Why Kokoro?

- 🚀 **Fast**: 10x faster than XTTS
- 🇮🇳 **Hindi**: Native Hindi support (`lang_code='h'`)
- 🎯 **82M params**: Runs easily on Colab T4 GPU
- 🔊 **Quality**: Rivals much larger models

## Troubleshooting

**No audio received?**
- Check Colab is still running (cells may timeout)
- Verify ngrok URL is accessible: `curl YOUR_URL/synthesize?text=test`

**Slow responses?**
- Colab cold starts take ~30 seconds
- First request loads model to GPU

**Hindi not working?**
- Ensure text contains Hindi Unicode characters
- Backend auto-detects and sends `language=h`
