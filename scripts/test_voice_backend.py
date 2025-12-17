#!/usr/bin/env python3
"""
Voice Backend Test Script
=========================

Tests the WebSocket voice pipeline without needing Flutter.
Validates: Connection -> Text Input -> Audio Streaming -> Turn Complete

Usage:
    python scripts/test_voice_backend.py [--token <access_token>]
    python scripts/test_voice_backend.py --save output.wav  # Save audio
    python scripts/test_voice_backend.py --direct-tts https://ngrok-url  # Test XTTS worker

Note: Requires valid authentication token or backend running in dev mode.
"""

import asyncio
import argparse
import json
import time
import sys
import aiohttp

try:
    import websockets
except ImportError:
    print("❌ Please install websockets: pip install websockets")
    sys.exit(1)


async def test_direct_tts(url: str, text: str = "Hello, who are you?"):
    """Test the XTTS worker endpoint directly."""
    print(f"🎙️ Testing XTTS Worker at {url}")
    print(f"📝 Text: '{text}'")
    
    try:
        start_time = time.time()
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{url}/synthesize",
                params={"text": text, "language": "en"},
                timeout=aiohttp.ClientTimeout(total=30)
            ) as resp:
                if resp.status == 200:
                    audio_data = await resp.read()
                    elapsed = time.time() - start_time
                    print(f"✅ Success!")
                    print(f"📊 Stats:")
                    print(f"   - Response time: {elapsed:.3f}s")
                    print(f"   - Audio size: {len(audio_data)} bytes")
                    
                    # Save to file
                    with open("tts_test_output.wav", "wb") as f:
                        f.write(audio_data)
                    print(f"   - Saved to: tts_test_output.wav")
                    return True
                else:
                    error = await resp.text()
                    print(f"❌ Error {resp.status}: {error}")
                    return False
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return False


async def test_voice_interaction(uri: str, token: str | None = None, save_path: str | None = None):
    """Test the voice WebSocket endpoint."""
    
    # Append token to URI if provided
    full_uri = f"{uri}?token={token}" if token else uri
    
    print(f"🔌 Connecting to {uri}...")
    
    audio_chunks = []  # Collect for saving
    
    try:
        async with websockets.connect(full_uri) as websocket:
            print("✅ Connected!")
            
            # Wait for authentication message
            auth_response = await websocket.recv()
            if isinstance(auth_response, str):
                auth_data = json.loads(auth_response)
                if auth_data.get("type") == "authenticated":
                    print(f"✅ Authenticated as: {auth_data.get('user', {}).get('name', 'Unknown')}")
                elif auth_data.get("type") == "error":
                    print(f"❌ Auth Error: {auth_data.get('message')}")
                    return False
            
            # 1. Simulate User Speaking
            query = "Book a meeting with the investors tomorrow at 3pm."
            print(f"\n🗣️ Sending: '{query}'")
            
            await websocket.send(json.dumps({"text": query}))
            
            # 2. Receive Audio Stream
            start_time = time.time()
            chunk_count = 0
            total_bytes = 0
            first_byte_time = None
            
            while True:
                response = await websocket.recv()
                
                if isinstance(response, bytes):
                    chunk_count += 1
                    total_bytes += len(response)
                    audio_chunks.append(response)
                    
                    if chunk_count == 1:
                        first_byte_time = time.time() - start_time
                        print(f"⚡ TTFB (Time to First Byte): {first_byte_time:.3f}s")
                    
                    print(f"🎵 Received Audio Chunk #{chunk_count}: {len(response)} bytes")
                    
                elif isinstance(response, str):
                    # JSON Control Message
                    data = json.loads(response)
                    
                    if data.get("status") == "turn_complete":
                        total_time = time.time() - start_time
                        print(f"\n✅ Turn Complete!")
                        print(f"📊 Stats:")
                        print(f"   - Total chunks: {chunk_count}")
                        print(f"   - Total bytes: {total_bytes}")
                        print(f"   - TTFB: {first_byte_time:.3f}s" if first_byte_time else "   - TTFB: N/A")
                        print(f"   - Total time: {total_time:.3f}s")
                        break
                    elif data.get("type") == "error":
                        print(f"❌ Error: {data.get('message')}")
                        break
            
            # Save audio if requested
            if save_path and audio_chunks:
                with open(save_path, "wb") as f:
                    for chunk in audio_chunks:
                        f.write(chunk)
                print(f"\n💾 Audio saved to: {save_path}")
                        
            print("\n🎉 Test Passed!" if chunk_count > 0 else "\n⚠️ No audio chunks received")
            return chunk_count > 0
            
    except websockets.exceptions.InvalidStatusCode as e:
        print(f"❌ Connection rejected: {e}")
        return False
    except ConnectionRefusedError:
        print("❌ Connection refused. Is the backend running?")
        print("   Start it with: ./dev.sh")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Test the Voice Backend WebSocket")
    parser.add_argument(
        "--host", 
        default="localhost", 
        help="Backend host (default: localhost)"
    )
    parser.add_argument(
        "--port", 
        type=int, 
        default=30000, 
        help="Backend port (default: 30000)"
    )
    parser.add_argument(
        "--token", 
        help="Access token for authentication"
    )
    parser.add_argument(
        "--no-ssl",
        action="store_true",
        default=True,
        help="Use ws:// instead of wss:// (default: True for localhost)"
    )
    parser.add_argument(
        "--save",
        metavar="FILE",
        help="Save received audio to file (e.g., output.wav)"
    )
    parser.add_argument(
        "--direct-tts",
        metavar="URL",
        help="Test XTTS worker directly (e.g., https://ngrok-url.app)"
    )
    parser.add_argument(
        "--text",
        default="Hello, who are you?",
        help="Text to synthesize for direct TTS test"
    )
    
    args = parser.parse_args()
    
    # Direct TTS worker test
    if args.direct_tts:
        success = asyncio.run(test_direct_tts(args.direct_tts, args.text))
        sys.exit(0 if success else 1)
    
    # WebSocket test
    protocol = "ws" if args.no_ssl else "wss"
    uri = f"{protocol}://{args.host}:{args.port}/api/v1/voice/stream"
    
    if not args.token:
        print("⚠️  No token provided. Connection will likely fail.")
        print("   Use --token <access_token> to authenticate.")
        print("   Or modify backend for dev bypass.\n")
    
    success = asyncio.run(test_voice_interaction(uri, args.token, args.save))
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()

