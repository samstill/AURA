"""
Voice Router
============

Handles real-time voice interactions via WebSocket.
Integrates with Orchestrator (Brain) and TTS (Mouth) for full voice pipeline.

Authentication is required for all endpoints.
"""

import json
import logging
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException, Query
from pydantic import BaseModel
from typing import Optional

from dependencies.auth_dependencies import CurrentUser
from services.authentik_service import authentik_service
from services.orchestrator_service import orchestrator_service
from services.tts_service import tts_service

router = APIRouter()
logger = logging.getLogger(__name__)


# -----------------------------------------------------------------------------
# Request/Response Models
# -----------------------------------------------------------------------------
class VoiceSessionConfig(BaseModel):
    language: str = "en-US"
    voice_id: Optional[str] = None  # For TTS voice selection
    sample_rate: int = 16000


class VoiceSessionResponse(BaseModel):
    session_id: str
    user_id: str
    websocket_url: str


class TranscriptionResult(BaseModel):
    text: str
    confidence: float
    is_final: bool


# -----------------------------------------------------------------------------
# Protected REST Endpoints
# -----------------------------------------------------------------------------
@router.post("/session/start", response_model=VoiceSessionResponse)
async def start_voice_session(
    config: VoiceSessionConfig,
    user: CurrentUser,  # Requires authentication
):
    """
    Initialize a new voice session.
    
    Returns a session ID to be used with the WebSocket connection.
    Requires authentication.
    """
    # TODO: Create session in database
    session_id = f"voice-{user.sub[:8]}-placeholder"
    
    return VoiceSessionResponse(
        session_id=session_id,
        user_id=user.sub,
        websocket_url=f"/api/v1/voice/stream?token=<access_token>"
    )


@router.post("/session/{session_id}/end")
async def end_voice_session(
    session_id: str,
    user: CurrentUser,  # Requires authentication
):
    """
    End an active voice session and clean up resources.
    """
    # TODO: Verify user owns this session
    return {"message": f"Session {session_id} ended", "user_id": user.sub}


# -----------------------------------------------------------------------------
# WebSocket Endpoint (with token-based auth)
# -----------------------------------------------------------------------------
@router.websocket("/stream")
async def voice_stream(
    websocket: WebSocket,
    token: Optional[str] = Query(None),
):
    """
    Real-time Voice Pipeline WebSocket with Audio Streaming.
    
    Authentication: Pass access token as query parameter `?token=<access_token>`
    
    Protocol:
    1. Client -> Binary audio data (WAV/WebM chunks)
    2. Client -> {"action": "end_turn"} when done speaking
    3. Server -> {"type": "transcription", "text": "..."} 
    4. Server -> Binary Audio Chunks (TTS response)
    5. Server -> {"status": "turn_complete"}
    
    Message Types (JSON):
    - {"type": "authenticated", "user": {...}} - Connection successful
    - {"type": "transcription", "text": "..."} - User's transcribed speech
    - {"type": "processing"} - AI is thinking
    - {"status": "turn_complete"} - End of response turn
    - {"type": "error", "message": "..."} - Error occurred
    
    Client can also send:
    - {"text": "..."} - Direct text input (skips STT)
    - {"action": "end_turn"} - Signal end of audio input
    """
    from services.stt_service import stt_service
    
    # Validate token before accepting connection
    if not token:
        await websocket.close(code=4001, reason="Missing authentication token")
        return
    
    # Validate the access token
    user_info = await authentik_service.validate_access_token(token)
    if not user_info:
        await websocket.close(code=4002, reason="Invalid or expired token")
        return
    
    await websocket.accept()
    user_id = user_info.get('sub', 'unknown')
    logger.info(f"🎤 Voice WebSocket connected for user: {user_id}")
    
    # Audio buffer for accumulating chunks
    audio_buffer: list[bytes] = []
    
    try:
        # Send authentication confirmation
        await websocket.send_json({
            "type": "authenticated",
            "user": {
                "sub": user_info.get("sub"),
                "name": user_info.get("name"),
                "email": user_info.get("email"),
            },
            "message": "Voice stream connected. Send audio bytes or {\"text\": \"...\"} to start."
        })
        
        while True:
            # Receive message (can be binary audio or JSON)
            message = await websocket.receive()
            
            if "bytes" in message:
                # Binary audio data - buffer it
                audio_buffer.append(message["bytes"])
                continue
                
            elif "text" in message:
                data = json.loads(message["text"])
                
                # Check for end_turn signal
                if data.get("action") == "end_turn" and audio_buffer:
                    # Transcribe accumulated audio
                    combined_audio = b"".join(audio_buffer)
                    audio_buffer.clear()
                    
                    if len(combined_audio) < 1000:  # Too short
                        await websocket.send_json({
                            "type": "error",
                            "message": "Audio too short. Please speak longer."
                        })
                        continue
                    
                    # STT - Whisper transcription
                    await websocket.send_json({"type": "transcribing"})
                    user_text = await stt_service.transcribe_audio(combined_audio, format="webm")
                    
                    if not user_text:
                        await websocket.send_json({
                            "type": "error",
                            "message": "Could not understand audio. Please try again."
                        })
                        continue
                    
                    # Send transcription back to client
                    await websocket.send_json({
                        "type": "transcription",
                        "text": user_text
                    })
                    
                # Direct text input (skip STT)
                elif "text" in data:
                    user_text = data["text"]
                    audio_buffer.clear()  # Clear any buffered audio
                else:
                    continue
                
                if not user_text:
                    continue
                    
                logger.info(f"🎤 Heard from {user_id}: {user_text[:50]}...")
                
                # Signal processing
                await websocket.send_json({"type": "processing"})

                # 2. Ignite the Brain (Get Text Stream with routing)
                brain_stream = orchestrator_service.stream_voice_response(
                    user_text, 
                    user_id
                )

                # 3. Ignite the Mouth (Convert to Audio Stream)
                audio_stream = tts_service.stream_audio(brain_stream)

                # 4. Stream audio bytes to client
                chunk_count = 0
                async for audio_chunk in audio_stream:
                    if audio_chunk:
                        await websocket.send_bytes(audio_chunk)
                        chunk_count += 1
                
                logger.info(f"🔊 Sent {chunk_count} audio chunks to {user_id}")
                
                # 5. Signal end of turn (so client stops listening/waiting)
                await websocket.send_json({"status": "turn_complete"})

    except WebSocketDisconnect:
        logger.info(f"🔌 Voice Client Disconnected: {user_id}")
    except json.JSONDecodeError as e:
        logger.error(f"❌ Invalid JSON from client: {e}")
        try:
            await websocket.send_json({
                "type": "error",
                "message": "Invalid JSON format"
            })
        except:
            pass
        await websocket.close()
    except Exception as e:
        logger.error(f"❌ Voice Error for {user_id}: {e}")
        try:
            await websocket.send_json({
                "type": "error",
                "message": str(e)
            })
        except:
            pass
        await websocket.close()


# -----------------------------------------------------------------------------
# DEV WebSocket Endpoint (No Authentication - for local testing only)
# -----------------------------------------------------------------------------
@router.websocket("/stream/dev")
async def voice_stream_dev(websocket: WebSocket):
    """
    Development Voice Pipeline WebSocket - NO AUTHENTICATION.
    
    ⚠️ WARNING: For local development only! Do not expose in production.
    
    Protocol:
    1. Client -> {"text": "What is my schedule?"}
    2. Server -> Binary Audio Chunk ...
    3. Server -> Binary Audio Chunk ...
    4. Server -> {"status": "turn_complete"}
    """
    await websocket.accept()
    # Use a valid UUID for dev user to avoid DB query errors
    user_id = "00000000-0000-0000-0000-000000000000"
    logger.info(f"🎤 [DEV] Voice WebSocket connected")
    
    try:
        # Send authentication confirmation (mock)
        await websocket.send_json({
            "type": "authenticated",
            "user": {
                "sub": user_id,
                "name": "Dev User",
                "email": "dev@localhost",
            },
            "message": "Voice stream connected (DEV MODE - no auth)."
        })
        
        while True:
            # 1. Wait for user input (Text from Client STT)
            data = await websocket.receive_json()
            user_text = data.get("text")
            
            if not user_text:
                await websocket.send_json({
                    "type": "error",
                    "message": "Missing 'text' field in request"
                })
                continue
                
            logger.info(f"🎤 [DEV] Heard: {user_text[:50]}...")

            # 2. Ignite the Brain (Get Text Stream with routing)
            brain_stream = orchestrator_service.stream_voice_response(
                user_text, 
                user_id
            )

            # 3. Ignite the Mouth (Convert to Audio Stream)
            audio_stream = tts_service.stream_audio(brain_stream)

            # 4. Stream audio bytes to client
            chunk_count = 0
            async for audio_chunk in audio_stream:
                if audio_chunk:
                    await websocket.send_bytes(audio_chunk)
                    chunk_count += 1
            
            logger.info(f"🔊 [DEV] Sent {chunk_count} audio chunks")
            
            # 5. Signal end of turn
            await websocket.send_json({"status": "turn_complete"})

    except WebSocketDisconnect:
        logger.info(f"🔌 [DEV] Voice Client Disconnected")
    except json.JSONDecodeError as e:
        logger.error(f"❌ [DEV] Invalid JSON: {e}")
        try:
            await websocket.send_json({"type": "error", "message": "Invalid JSON format"})
        except:
            pass
        await websocket.close()
    except Exception as e:
        logger.error(f"❌ [DEV] Voice Error: {e}")
        try:
            await websocket.send_json({"type": "error", "message": str(e)})
        except:
            pass
        await websocket.close()
