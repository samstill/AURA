"""
TTS Service (Text-to-Speech)
============================

Dual-mode TTS service supporting:
- LOCAL: Microsoft Edge TTS (free, no GPU needed)
- REMOTE: XTTS-v2 via Colab/K8s worker (high-quality, cloneable voice)

The mode is auto-detected based on TTS_WORKER_URL presence.
"""

import os
import io
import logging
import aiohttp
import edge_tts
from typing import AsyncGenerator, Optional

from ..config import settings

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
    Text-to-Speech service with dual-mode support:
    - LOCAL: Microsoft Edge TTS (free, no GPU needed)
    - REMOTE: XTTS-v2 via Colab worker (high-quality, cloneable)
    
    Features:
    - Automatic mode detection based on TTS_WORKER_URL
    - Sentence buffering for natural speech
    - Fallback to Edge TTS if remote worker unavailable
    """
    
    def __init__(self):
        # Configuration from settings
        self.use_mock = settings.tts_mock
        self.tts_worker_url = settings.tts_synthesis_url
        self.voice = os.getenv("TTS_VOICE", EDGE_VOICES["aria"])
        
        # Mode detection: use remote if worker URL is configured
        self.use_remote = bool(self.tts_worker_url) and not self.use_mock
        
        if self.use_mock:
            logger.info("🔇 TTSService initialized in MOCK mode")
        elif self.use_remote:
            logger.info(f"🎙️ TTSService initialized in REMOTE mode")
            logger.info(f"   Target: {self.tts_worker_url}")
            logger.info(f"   Environment: {settings.aura_env}")
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
            Audio bytes (WAV for remote XTTS, MP3 for Edge TTS)
        """
        buffer = ""
        # Punctuation that marks a "speakable chunk"
        sentence_endings = {".", "!", "?", "\n", ":", ";"}

        async for chunk in text_stream:
            buffer += chunk
            
            # Buffer until we have a complete thought/sentence for better prosody
            # For remote XTTS, we want slightly larger chunks for better quality
            min_buffer = 50 if self.use_remote else 10
            
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
        """
        if not text.strip():
            return b''
        
        if self.use_mock:
            logger.debug(f"🔇 Mock TTS: '{text[:30]}...'")
            return b'\x00' * 1024
        
        if self.use_remote:
            return await self._synthesize_remote(text)
        
        return await self._synthesize_edge(text)

    async def _synthesize_remote(self, text: str) -> bytes:
        """
        Calls the remote TTS endpoint (Fish Speech or XTTS on Colab/K8s).
        
        Supports both:
        - Fish Speech API: POST /v1/tts with JSON body
        - XTTS API: POST /synthesize with query params
        
        Args:
            text: Text to convert to speech
            
        Returns:
            Audio bytes (WAV format)
        """
        if not self.tts_worker_url:
            logger.warning("TTS Worker URL not configured, falling back to Edge TTS")
            return await self._synthesize_edge(text)
        
        try:
            async with aiohttp.ClientSession() as session:
                # Try Fish Speech API first (POST /v1/tts with JSON)
                fish_speech_url = f"{self.tts_worker_url}/v1/tts"
                
                async with session.post(
                    fish_speech_url,
                    json={
                        "text": text,
                        "reference_id": "aura",  # Voice clone reference
                        "format": "wav"
                    },
                    timeout=aiohttp.ClientTimeout(total=30)
                ) as resp:
                    if resp.status == 200:
                        audio_data = await resp.read()
                        logger.info(f"🐟 Fish Speech: {len(audio_data)} bytes for '{text[:30]}...'")
                        return audio_data
                    elif resp.status == 404:
                        # Fallback to XTTS-style API
                        logger.debug("Fish Speech endpoint not found, trying XTTS format...")
                        return await self._synthesize_xtts(text)
                    else:
                        error_text = await resp.text()
                        logger.error(f"Fish Speech Error {resp.status}: {error_text}")
                        return await self._synthesize_edge(text)
                        
        except aiohttp.ClientError as e:
            logger.error(f"TTS Connection Failed: {e}")
            return await self._synthesize_edge(text)
        except Exception as e:
            logger.error(f"TTS Unexpected Error: {e}")
            return await self._synthesize_edge(text)

    async def _synthesize_xtts(self, text: str) -> bytes:
        """
        Fallback for XTTS-v2 style API (query params format).
        """
        try:
            async with aiohttp.ClientSession() as session:
                url = f"{self.tts_worker_url}/synthesize"
                
                async with session.post(
                    url,
                    params={"text": text, "language": "en"},
                    timeout=aiohttp.ClientTimeout(total=30)
                ) as resp:
                    if resp.status == 200:
                        audio_data = await resp.read()
                        logger.info(f"🎙️ XTTS: {len(audio_data)} bytes for '{text[:30]}...'")
                        return audio_data
                    else:
                        error_text = await resp.text()
                        logger.error(f"XTTS Worker Error {resp.status}: {error_text}")
                        return await self._synthesize_edge(text)
        except Exception as e:
            logger.error(f"XTTS Error: {e}")
            return await self._synthesize_edge(text)

    async def _synthesize_edge(self, text: str) -> bytes:
        """
        Uses Microsoft Edge TTS to synthesize speech (local fallback).
        
        Args:
            text: Text to convert to speech
            
        Returns:
            Audio bytes (MP3 format)
        """
        if not text.strip():
            return b''

        try:
            # Create TTS communicate object
            communicate = edge_tts.Communicate(text, self.voice)
            
            # Collect audio chunks
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
        Useful for testing or short phrases.
        
        Args:
            text: Complete text to synthesize
            
        Returns:
            Audio bytes
        """
        return await self._synthesize_chunk(text)


# Singleton instance
tts_service = TTSService()
