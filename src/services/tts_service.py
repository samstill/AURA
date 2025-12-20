"""
TTS Service (Text-to-Speech)
============================

Multi-mode TTS service supporting:
- KOKORO: Kokoro v0.19 via Colab (Hindi + English, high-quality)
- EDGE: Microsoft Edge TTS (free fallback)

Priority: Kokoro (Remote) > Edge TTS
"""

import os
import io
import logging
import asyncio
import aiohttp
import edge_tts
from typing import AsyncGenerator, Optional

from config import settings

logger = logging.getLogger(__name__)

# Popular Edge TTS voices (all free!)
EDGE_VOICES = {
    # English - US
    "jenny": "en-US-JennyNeural",        # Female, friendly
    "aria": "en-US-AriaNeural",          # Female, professional
    "guy": "en-US-GuyNeural",            # Male, casual
    "davis": "en-US-DavisNeural",        # Male, calm
    # English - UK
    "sonia": "en-GB-SoniaNeural",        # Female, British
    "ryan": "en-GB-RyanNeural",          # Male, British
    # English - India
    "neerja": "en-IN-NeerjaNeural",      # Female, Indian
    "prabhat": "en-IN-PrabhatNeural",    # Male, Indian
    # Hindi
    "swara": "hi-IN-SwaraNeural",        # Female, Hindi
    "madhur": "hi-IN-MadhurNeural",      # Male, Hindi
}


class TTSService:
    """
    Text-to-Speech service with multi-mode support:
    
    Priority order:
    1. Kokoro via Colab (if TTS_WORKER_URL configured)
    2. Edge TTS (free fallback)
    
    Features:
    - Kokoro: High-quality Hindi + English synthesis (82M params)
    - Sentence buffering for natural speech
    - Automatic fallback to Edge TTS
    """
    
    def __init__(self):
        # Configuration from settings
        self.use_mock = settings.tts_mock
        self.tts_worker_url = settings.tts_synthesis_url
        self.voice = os.getenv("TTS_VOICE", EDGE_VOICES["aria"])
        
        # Mode detection
        self.use_remote = bool(self.tts_worker_url) and not self.use_mock
        
        if self.use_mock:
            logger.info("🔇 TTSService initialized in MOCK mode")
        elif self.use_remote:
            logger.info(f"🎙️ TTSService initialized with Kokoro (Remote)")
            logger.info(f"   Worker URL: {self.tts_worker_url}")
        else:
            logger.info(f"🔊 TTSService initialized with Edge TTS (voice: {self.voice})")

    async def stream_audio(
        self, 
        text_stream: AsyncGenerator[str, None]
    ) -> AsyncGenerator[bytes, None]:
        """
        Consumes the text stream from the Brain and converts it to Audio on the fly.
        Implements 'Sentence Buffering' to prevent robotic choppiness.
        
        Args:
            text_stream: Async generator yielding text chunks
            
        Yields:
            Audio bytes (WAV format from Kokoro, MP3 from Edge)
        """
        buffer = ""
        # Punctuation that marks a "speakable chunk"
        sentence_endings = {".", "!", "?", "\n", ":", ";"}

        async for chunk in text_stream:
            buffer += chunk
            
            # Buffer until we have a complete thought/sentence for better prosody
            # Kokoro handles longer text well, so we can use larger buffers
            min_buffer = 80 if self.use_remote else 10
            
            if any(end in buffer for end in sentence_endings) and len(buffer) > min_buffer:
                audio = await self._synthesize_chunk(buffer.strip())
                if audio:
                    yield audio
                buffer = ""

        # Flush whatever is left at the end
        if buffer.strip():
            audio = await self._synthesize_chunk(buffer.strip())
            if audio:
                yield audio

    async def _synthesize_chunk(self, text: str) -> bytes:
        """
        Route synthesis to appropriate backend.
        Priority: Kokoro (Remote) > Edge TTS
        """
        if not text.strip():
            return b''
        
        if self.use_mock:
            logger.debug(f"🔇 Mock TTS: '{text[:30]}...'")
            return b'\x00' * 1024
        
        # Try Kokoro remote worker first
        if self.use_remote:
            result = await self._synthesize_kokoro(text)
            if result:
                return result
            # Fall through to Edge TTS on error
        
        # Final fallback: Edge TTS
        return await self._synthesize_edge(text)

    async def _synthesize_kokoro(self, text: str) -> bytes:
        """
        Calls Kokoro TTS API running on Colab.
        
        Endpoint: POST /synthesize?text=...&language=h
        Returns: WAV audio (24kHz)
        """
        if not self.tts_worker_url:
            return b''
        
        try:
            async with aiohttp.ClientSession() as session:
                url = f"{self.tts_worker_url}/synthesize"
                
                # Detect language: use 'hi' for Hindi content, 'en' for English
                # Simple heuristic: check for Hindi Unicode range
                has_hindi = any('\u0900' <= char <= '\u097F' for char in text)
                language = 'hi' if has_hindi else 'en'
                
                async with session.post(
                    url,
                    params={"text": text, "language": language},
                    timeout=aiohttp.ClientTimeout(total=60)  # Kokoro can be slow
                ) as resp:
                    if resp.status == 200:
                        audio_data = await resp.read()
                        # Debug log the full text being sent
                        logger.debug(f"TTS full text: {repr(text)}")
                        logger.info(f"🎙️ Remote TTS: {len(audio_data)} bytes for first 30 chars (lang={language})")
                        return audio_data
                    else:
                        error_text = await resp.text()
                        logger.error(f"Kokoro Error {resp.status}: {error_text[:200]}")
                        return b''
                        
        except asyncio.TimeoutError:
            logger.error(f"Kokoro timeout for text: {text[:50]}...")
            return b''
        except Exception as e:
            logger.error(f"Kokoro Error: {e}")
            return b''

    async def _synthesize_edge(self, text: str) -> bytes:
        """
        Uses Microsoft Edge TTS (free fallback).
        
        Returns:
            Audio bytes (MP3 format)
        """
        if not text.strip():
            return b''

        try:
            communicate = edge_tts.Communicate(text, self.voice)
            
            audio_data = io.BytesIO()
            async for chunk in communicate.stream():
                if chunk["type"] == "audio":
                    audio_data.write(chunk["data"])
            
            result = audio_data.getvalue()
            if result:
                logger.info(f"🔊 Edge TTS: {len(result)} bytes for '{text[:30]}...'")
            return result
                        
        except Exception as e:
            logger.error(f"Edge TTS Error: {e}")
            return b''

    async def synthesize_text(self, text: str) -> bytes:
        """
        One-shot synthesis for a complete text string.
        """
        return await self._synthesize_chunk(text)


# Singleton instance
tts_service = TTSService()
