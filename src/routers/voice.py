"""
Voice Router
============

Handles real-time voice interactions via WebSocket.
Integrates with speech-to-text and text-to-speech services.

Authentication is required for all endpoints.
"""

import logging
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException, Query
from pydantic import BaseModel
from typing import Optional

from dependencies.auth_dependencies import CurrentUser
from services.authentik_service import authentik_service

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
    WebSocket endpoint for real-time voice streaming.
    
    Authentication: Pass access token as query parameter `?token=<access_token>`
    
    Protocol:
    1. Client connects with token: ws://host/api/v1/voice/stream?token=xxx
    2. Server validates token and accepts connection
    3. Client sends audio chunks (binary)
    4. Server transcribes and responds with text (JSON)
    5. Server can optionally send TTS audio back (binary)
    
    Message Types (JSON):
    - {"type": "authenticated", "user": {...}}
    - {"type": "transcript", "text": "...", "is_final": true}
    - {"type": "response", "text": "...", "audio_url": "..."}
    - {"type": "error", "message": "..."}
    """
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
    logger.info(f"Voice WebSocket connected for user: {user_info.get('sub', 'unknown')}")
    
    try:
        # Send authentication confirmation
        await websocket.send_json({
            "type": "authenticated",
            "user": {
                "sub": user_info.get("sub"),
                "name": user_info.get("name"),
                "email": user_info.get("email"),
            },
            "message": "Voice stream connected. Feature not yet fully implemented."
        })
        
        while True:
            # Receive audio data
            data = await websocket.receive()
            
            if "bytes" in data:
                # Audio chunk received
                audio_chunk = data["bytes"]
                # TODO: Process audio with Deepgram/Whisper
                await websocket.send_json({
                    "type": "info",
                    "message": f"Received {len(audio_chunk)} bytes. Processing not implemented."
                })
            elif "text" in data:
                # Text command received
                text = data["text"]
                if text == "ping":
                    await websocket.send_json({"type": "pong"})
                else:
                    await websocket.send_json({
                        "type": "echo",
                        "text": text,
                        "user": user_info.get("name")
                    })
                
    except WebSocketDisconnect:
        logger.info(f"Voice WebSocket disconnected for user: {user_info.get('sub', 'unknown')}")
    except Exception as e:
        logger.error(f"Voice WebSocket error: {e}")
        try:
            await websocket.send_json({
                "type": "error",
                "message": str(e)
            })
        except:
            pass
        await websocket.close()
