"""
TTS Service (Text-to-Speech)
============================

Manages connection to the AI4Bharat TTS container for real-time audio synthesis.
Implements sentence buffering for natural, non-robotic speech output.
"""

import os
import aiohttp
import logging
from typing import AsyncGenerator

logger = logging.getLogger(__name__)


class TTSService:
    """
    Text-to-Speech service using AI4Bharat / Indic-Parler.
    
    Features:
    - Sentence buffering for natural speech
    - Mock mode for testing without GPU
    - Async streaming support
    """
    
    def __init__(self):
        # Internal K8s DNS or Localhost URL
        self.tts_url = os.getenv("TTS_URL", "http://localhost:5002/api/tts")
        # If True, yield silent bytes instead of calling the heavy GPU model
        self.use_mock = os.getenv("TTS_MOCK", "True").lower() == "true"
        
        if self.use_mock:
            logger.info("🔇 TTSService initialized in MOCK mode")
        else:
            logger.info(f"🔊 TTSService initialized with URL: {self.tts_url}")

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
            Audio bytes for each synthesized sentence/chunk
        """
        buffer = ""
        # Punctuation that marks a "speakable chunk"
        sentence_endings = {".", "!", "?", "\n", ":", ";"}

        async for chunk in text_stream:
            buffer += chunk
            
            # Heuristic: Speak if we hit punctuation OR buffer gets too long
            if any(end in buffer for end in sentence_endings) or len(buffer) > 80:
                audio = await self._synthesize(buffer)
                if audio:
                    yield audio
                buffer = ""

        # Flush whatever is left at the end
        if buffer:
            audio = await self._synthesize(buffer)
            if audio:
                yield audio

    async def _synthesize(self, text: str) -> bytes:
        """
        Calls the AI4Bharat Container to synthesize speech.
        
        Args:
            text: Text to convert to speech
            
        Returns:
            Audio bytes (WAV/PCM format)
        """
        if not text.strip():
            return b''

        if self.use_mock:
            # Return 1 second of silence (for testing logic without GPU)
            # 16-bit PCM at 16kHz = 32000 bytes per second
            logger.debug(f"🔇 Mock TTS: '{text[:30]}...'")
            return b'\x00' * 1024

        try:
            # AI4Bharat / Indic-Parler Payload
            payload = {
                "input": text,
                "gender": "female",
                "alpha": 1.0,  # Speed multiplier
                "lang": "en"   # or 'hi' for Hindi
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    self.tts_url, 
                    json=payload, 
                    timeout=aiohttp.ClientTimeout(total=5.0)
                ) as resp:
                    if resp.status == 200:
                        audio_data = await resp.read()
                        logger.debug(f"🔊 TTS: {len(audio_data)} bytes for '{text[:30]}...'")
                        return audio_data
                    else:
                        error_text = await resp.text()
                        logger.error(f"TTS Error {resp.status}: {error_text}")
                        return b''
                        
        except aiohttp.ClientError as e:
            logger.error(f"TTS Connection Failed: {e}")
            return b''
        except Exception as e:
            logger.error(f"TTS Unexpected Error: {e}")
            return b''


# Singleton instance
tts_service = TTSService()
