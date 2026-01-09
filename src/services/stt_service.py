"""
STT Service (Speech-to-Text)
============================

OpenAI Whisper integration for high-quality speech recognition.
Supports streaming audio transcription for real-time voice pipeline.
"""

import io
import logging
from typing import Optional
from openai import AsyncOpenAI

from config import settings

logger = logging.getLogger(__name__)


class STTService:
    """
    Speech-to-Text service using OpenAI Whisper API.
    
    Features:
    - High-quality transcription with Whisper-1
    - Language auto-detection
    - Supports WAV, MP3, WebM audio formats
    """
    
    def __init__(self):
        self.client: Optional[AsyncOpenAI] = None
        self.use_mock = not settings.openai_api_key
        
        if self.use_mock:
            logger.warning("⚠️ STTService in MOCK mode (no OPENAI_API_KEY)")
        else:
            self.client = AsyncOpenAI(api_key=settings.openai_api_key)
            logger.info("🎤 STTService initialized with OpenAI Whisper")
    
    async def transcribe_audio(
        self, 
        audio_data: bytes,
        language: Optional[str] = None,
        format: str = "wav"
    ) -> str:
        """
        Transcribe audio to text using OpenAI Whisper.
        
        Args:
            audio_data: Raw audio bytes
            language: Optional ISO-639-1 language code (e.g., "en", "hi")
            format: Audio format - "wav", "mp3", "webm", "m4a"
            
        Returns:
            Transcribed text
        """
        if not audio_data:
            return ""
        
        if self.use_mock:
            logger.debug("🔇 Mock STT: returning placeholder")
            return "[Mock transcription - no OPENAI_API_KEY]"
        
        try:
            # Create file-like object for OpenAI API
            audio_file = io.BytesIO(audio_data)
            audio_file.name = f"audio.{format}"
            
            # Transcribe with Whisper
            transcription = await self.client.audio.transcriptions.create(
                model="whisper-1",
                file=audio_file,
                language=language,  # None = auto-detect
                response_format="text"
            )
            
            text = transcription.strip() if isinstance(transcription, str) else str(transcription)
            logger.info(f"🎤 STT: '{text[:50]}...' ({len(audio_data)} bytes)")
            return text
            
        except Exception as e:
            logger.error(f"❌ STT Error: {e}")
            return ""
    
    async def transcribe_stream(
        self,
        audio_chunks: list[bytes],
        format: str = "wav"
    ) -> str:
        """
        Transcribe accumulated audio chunks.
        
        For real-time streaming, buffer chunks and transcribe periodically.
        """
        if not audio_chunks:
            return ""
        
        # Combine all chunks
        combined = b"".join(audio_chunks)
        return await self.transcribe_audio(combined, format=format)


# Singleton instance
stt_service = STTService()
