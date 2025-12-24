"""
Calendar Database Service (SQLite)
==================================

Temporary SQLite-based storage for Google Calendar integration.
Stores OAuth tokens (encrypted) and calendar sources.

This will be replaced by Supermemory once implemented.
"""

import os
import json
import logging
import aiosqlite
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from pathlib import Path
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import base64

from config import settings

logger = logging.getLogger(__name__)

# Database path (in project root for development)
DB_PATH = Path(__file__).parent.parent.parent / "data" / "calendar.db"


def _get_encryption_key() -> bytes:
    """
    Derive encryption key from secret_key using PBKDF2.
    This ensures a consistent 32-byte key for Fernet.
    """
    salt = b"aura_calendar_salt_v1"  # Fixed salt for key derivation
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=100000,
    )
    key = base64.urlsafe_b64encode(kdf.derive(settings.secret_key.encode()))
    return key


class CalendarDBService:
    """
    SQLite-based storage for calendar integrations.
    
    Tables:
    - user_integrations: OAuth tokens (refresh token encrypted)
    - calendar_sources: Discovered calendars with sync preferences
    """
    
    def __init__(self):
        self._initialized = False
        self._fernet: Optional[Fernet] = None
    
    async def initialize(self):
        """Initialize the database and create tables if needed."""
        if self._initialized:
            return
        
        # Ensure data directory exists
        DB_PATH.parent.mkdir(parents=True, exist_ok=True)
        
        # Initialize encryption
        self._fernet = Fernet(_get_encryption_key())
        
        async with aiosqlite.connect(DB_PATH) as db:
            # Create user_integrations table
            await db.execute("""
                CREATE TABLE IF NOT EXISTS user_integrations (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    provider TEXT NOT NULL DEFAULT 'google_calendar',
                    access_token TEXT NOT NULL,
                    refresh_token_encrypted TEXT NOT NULL,
                    token_expiry TEXT NOT NULL,
                    email TEXT,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(user_id, provider)
                )
            """)
            
            # Create calendar_sources table
            await db.execute("""
                CREATE TABLE IF NOT EXISTS calendar_sources (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    integration_id INTEGER NOT NULL,
                    google_calendar_id TEXT NOT NULL,
                    calendar_name TEXT NOT NULL,
                    access_role TEXT,
                    sync_enabled INTEGER NOT NULL DEFAULT 1,
                    color TEXT,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (integration_id) REFERENCES user_integrations(id) ON DELETE CASCADE,
                    UNIQUE(integration_id, google_calendar_id)
                )
            """)
            
            await db.commit()
        
        self._initialized = True
        logger.info("✅ Calendar SQLite database initialized")
    
    def _encrypt(self, plaintext: str) -> str:
        """Encrypt a string using Fernet."""
        return self._fernet.encrypt(plaintext.encode()).decode()
    
    def _decrypt(self, ciphertext: str) -> str:
        """Decrypt a string using Fernet."""
        return self._fernet.decrypt(ciphertext.encode()).decode()
    
    # -------------------------------------------------------------------------
    # User Integrations
    # -------------------------------------------------------------------------
    async def save_tokens(
        self,
        user_id: str,
        access_token: str,
        refresh_token: str,
        token_expiry: datetime,
        email: Optional[str] = None,
        provider: str = "google_calendar"
    ) -> int:
        """
        Save or update OAuth tokens for a user.
        
        Returns:
            Integration ID
        """
        encrypted_refresh = self._encrypt(refresh_token)
        expiry_str = token_expiry.isoformat()
        
        async with aiosqlite.connect(DB_PATH) as db:
            await db.execute("""
                INSERT INTO user_integrations 
                    (user_id, provider, access_token, refresh_token_encrypted, token_expiry, email, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(user_id, provider) DO UPDATE SET
                    access_token = excluded.access_token,
                    refresh_token_encrypted = excluded.refresh_token_encrypted,
                    token_expiry = excluded.token_expiry,
                    email = excluded.email,
                    updated_at = excluded.updated_at
            """, (user_id, provider, access_token, encrypted_refresh, expiry_str, email, datetime.now(timezone.utc).isoformat()))
            
            await db.commit()
            
            # Get the integration ID
            cursor = await db.execute(
                "SELECT id FROM user_integrations WHERE user_id = ? AND provider = ?",
                (user_id, provider)
            )
            row = await cursor.fetchone()
            return row[0] if row else -1
    
    async def get_tokens(self, user_id: str, provider: str = "google_calendar") -> Optional[Dict[str, Any]]:
        """
        Get OAuth tokens for a user.
        
        Returns:
            Dict with access_token, refresh_token (decrypted), token_expiry, integration_id
        """
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cursor = await db.execute(
                "SELECT * FROM user_integrations WHERE user_id = ? AND provider = ?",
                (user_id, provider)
            )
            row = await cursor.fetchone()
            
            if not row:
                return None
            
            return {
                "integration_id": row["id"],
                "user_id": row["user_id"],
                "access_token": row["access_token"],
                "refresh_token": self._decrypt(row["refresh_token_encrypted"]),
                "token_expiry": datetime.fromisoformat(row["token_expiry"]),
                "email": row["email"],
            }
    
    async def update_access_token(
        self,
        user_id: str,
        access_token: str,
        token_expiry: datetime,
        provider: str = "google_calendar"
    ):
        """Update just the access token after refresh."""
        async with aiosqlite.connect(DB_PATH) as db:
            await db.execute("""
                UPDATE user_integrations 
                SET access_token = ?, token_expiry = ?, updated_at = ?
                WHERE user_id = ? AND provider = ?
            """, (access_token, token_expiry.isoformat(), datetime.now(timezone.utc).isoformat(), user_id, provider))
            await db.commit()
    
    async def delete_integration(self, user_id: str, provider: str = "google_calendar") -> bool:
        """Remove a user's integration (tokens and calendars)."""
        async with aiosqlite.connect(DB_PATH) as db:
            # Calendars will be deleted via CASCADE
            result = await db.execute(
                "DELETE FROM user_integrations WHERE user_id = ? AND provider = ?",
                (user_id, provider)
            )
            await db.commit()
            return result.rowcount > 0
    
    async def has_integration(self, user_id: str, provider: str = "google_calendar") -> bool:
        """Check if user has connected the integration."""
        async with aiosqlite.connect(DB_PATH) as db:
            cursor = await db.execute(
                "SELECT 1 FROM user_integrations WHERE user_id = ? AND provider = ?",
                (user_id, provider)
            )
            return await cursor.fetchone() is not None
    
    # -------------------------------------------------------------------------
    # Calendar Sources
    # -------------------------------------------------------------------------
    async def save_calendars(
        self,
        integration_id: int,
        calendars: List[Dict[str, Any]]
    ):
        """
        Save discovered calendars for an integration.
        
        Args:
            integration_id: FK to user_integrations
            calendars: List of dicts with google_calendar_id, calendar_name, access_role, color
        """
        async with aiosqlite.connect(DB_PATH) as db:
            for cal in calendars:
                # Default sync_enabled based on access role
                sync_enabled = 1 if cal.get("access_role") in ("owner", "writer") else 0
                
                await db.execute("""
                    INSERT INTO calendar_sources 
                        (integration_id, google_calendar_id, calendar_name, access_role, sync_enabled, color)
                    VALUES (?, ?, ?, ?, ?, ?)
                    ON CONFLICT(integration_id, google_calendar_id) DO UPDATE SET
                        calendar_name = excluded.calendar_name,
                        access_role = excluded.access_role,
                        color = excluded.color
                """, (
                    integration_id,
                    cal["google_calendar_id"],
                    cal["calendar_name"],
                    cal.get("access_role"),
                    sync_enabled,
                    cal.get("color")
                ))
            
            await db.commit()
    
    async def get_calendars(self, user_id: str, provider: str = "google_calendar") -> List[Dict[str, Any]]:
        """Get all discovered calendars for a user."""
        async with aiosqlite.connect(DB_PATH) as db:
            db.row_factory = aiosqlite.Row
            cursor = await db.execute("""
                SELECT cs.* FROM calendar_sources cs
                JOIN user_integrations ui ON cs.integration_id = ui.id
                WHERE ui.user_id = ? AND ui.provider = ?
            """, (user_id, provider))
            rows = await cursor.fetchall()
            
            return [
                {
                    "id": row["id"],
                    "google_calendar_id": row["google_calendar_id"],
                    "calendar_name": row["calendar_name"],
                    "access_role": row["access_role"],
                    "sync_enabled": bool(row["sync_enabled"]),
                    "color": row["color"],
                }
                for row in rows
            ]
    
    async def get_synced_calendars(self, user_id: str, provider: str = "google_calendar") -> List[str]:
        """Get only the calendar IDs that have sync enabled."""
        async with aiosqlite.connect(DB_PATH) as db:
            cursor = await db.execute("""
                SELECT cs.google_calendar_id FROM calendar_sources cs
                JOIN user_integrations ui ON cs.integration_id = ui.id
                WHERE ui.user_id = ? AND ui.provider = ? AND cs.sync_enabled = 1
            """, (user_id, provider))
            rows = await cursor.fetchall()
            return [row[0] for row in rows]
    
    async def update_calendar_sync(
        self,
        user_id: str,
        calendar_id: int,
        sync_enabled: bool,
        provider: str = "google_calendar"
    ) -> bool:
        """Toggle sync enabled for a specific calendar."""
        async with aiosqlite.connect(DB_PATH) as db:
            result = await db.execute("""
                UPDATE calendar_sources 
                SET sync_enabled = ?
                WHERE id = ? AND integration_id IN (
                    SELECT id FROM user_integrations WHERE user_id = ? AND provider = ?
                )
            """, (1 if sync_enabled else 0, calendar_id, user_id, provider))
            await db.commit()
            return result.rowcount > 0
    
    async def get_all_calendars(self, user_id: str, provider: str = "google_calendar") -> List[Dict[str, Any]]:
        """Alias for get_calendars - returns all calendars for a user (for AI tool use)."""
        return await self.get_calendars(user_id, provider)


# Singleton instance
calendar_db_service = CalendarDBService()
