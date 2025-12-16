"""
TTS Service (Text-to-Speech)
============================

Uses Microsoft Edge TTS - completely FREE, no API key needed!
Implements sentence buffering for natural, non-robotic speech output.
"""

import os
import io
import logging
import edge_tts
from typing import AsyncGenerator

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
    Text-to-Speech service using Microsoft Edge TTS.
    
    Features:
    - Completely FREE - no API key needed!
    - High-quality neural voices
    - Sentence buffering for natural speech
    - Multiple language support
    """
    
    def __init__(self):
        self.voice = os.getenv("TTS_VOICE", EDGE_VOICES["aria"])
        self.use_mock = os.getenv("TTS_MOCK", "false").lower() == "true"
        
        if self.use_mock:
            logger.info("🔇 TTSService initialized in MOCK mode")
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
            Audio bytes (MP3 format) for each synthesized sentence/chunk
        """
        buffer = ""
        # Punctuation that marks a "speakable chunk"
        sentence_endings = {".", "!", "?", "\n"}

        async for chunk in text_stream:
            buffer += chunk
            
            # Heuristic: Speak if we hit punctuation OR buffer gets too long
            if any(end in buffer for end in sentence_endings) or len(buffer) > 150:
                audio = await self._synthesize(buffer.strip())
                if audio:
                    yield audio
                buffer = ""

        # Flush whatever is left at the end
        if buffer.strip():
            audio = await self._synthesize(buffer.strip())
            if audio:
                yield audio

    async def _synthesize(self, text: str) -> bytes:
        """
        Uses Edge TTS to synthesize speech.
        
        Args:
            text: Text to convert to speech
            
        Returns:
            Audio bytes (MP3 format)
        """
        if not text.strip():
            return b''

        if self.use_mock:
            logger.debug(f"🔇 Mock TTS: '{text[:30]}...'")
            return b'\x00' * 1024

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


# Singleton instance
tts_service = TTSService()

