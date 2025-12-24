"""
Google Calendar Service
=======================

Handles Google Calendar API operations:
- OAuth2 flow (authorization URL, token exchange, refresh)
- Calendar discovery
- Event fetching
"""

import logging
from datetime import datetime, timezone, timedelta
from typing import Optional, List, Dict, Any
from urllib.parse import urlencode

import httpx
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

from config import settings
from services.calendar_db_service import calendar_db_service

logger = logging.getLogger(__name__)

# Google OAuth endpoints
GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
GOOGLE_USERINFO_URL = "https://www.googleapis.com/oauth2/v2/userinfo"


class GoogleCalendarService:
    """
    Service for Google Calendar OAuth and API operations.
    """
    
    def __init__(self):
        self._http_client: Optional[httpx.AsyncClient] = None
    
    async def _get_client(self) -> httpx.AsyncClient:
        """Get or create HTTP client."""
        if self._http_client is None:
            self._http_client = httpx.AsyncClient(timeout=30.0)
        return self._http_client
    
    # -------------------------------------------------------------------------
    # OAuth Flow
    # -------------------------------------------------------------------------
    def get_authorization_url(self, state: str) -> str:
        """
        Generate Google OAuth authorization URL.
        
        Args:
            state: CSRF token to validate callback
            
        Returns:
            Authorization URL to redirect user to
        """
        params = {
            "client_id": settings.google_calendar_client_id,
            "redirect_uri": settings.google_calendar_redirect_uri,
            "scope": settings.google_calendar_scopes,
            "response_type": "code",
            "state": state,
            "access_type": "offline",  # Required for refresh token
            "prompt": "consent",  # Force consent to ensure refresh token
        }
        return f"{GOOGLE_AUTH_URL}?{urlencode(params)}"
    
    async def exchange_code_for_tokens(self, code: str) -> Dict[str, Any]:
        """
        Exchange authorization code for access and refresh tokens.
        
        Args:
            code: Authorization code from callback
            
        Returns:
            Dict with access_token, refresh_token, expires_in
        """
        client = await self._get_client()
        
        response = await client.post(
            GOOGLE_TOKEN_URL,
            data={
                "client_id": settings.google_calendar_client_id,
                "client_secret": settings.google_calendar_client_secret,
                "code": code,
                "grant_type": "authorization_code",
                "redirect_uri": settings.google_calendar_redirect_uri,
            }
        )
        
        if response.status_code != 200:
            error = response.json()
            logger.error(f"Token exchange failed: {error}")
            raise Exception(f"Token exchange failed: {error.get('error_description', error.get('error'))}")
        
        return response.json()
    
    async def refresh_access_token(self, refresh_token: str) -> Dict[str, Any]:
        """
        Refresh an expired access token.
        
        Args:
            refresh_token: The refresh token
            
        Returns:
            Dict with new access_token and expires_in
        """
        client = await self._get_client()
        
        response = await client.post(
            GOOGLE_TOKEN_URL,
            data={
                "client_id": settings.google_calendar_client_id,
                "client_secret": settings.google_calendar_client_secret,
                "refresh_token": refresh_token,
                "grant_type": "refresh_token",
            }
        )
        
        if response.status_code != 200:
            error = response.json()
            logger.error(f"Token refresh failed: {error}")
            raise Exception(f"Token refresh failed: {error.get('error_description', error.get('error'))}")
        
        return response.json()
    
    async def get_user_email(self, access_token: str) -> str:
        """Get the user's email from the access token."""
        client = await self._get_client()
        
        response = await client.get(
            GOOGLE_USERINFO_URL,
            headers={"Authorization": f"Bearer {access_token}"}
        )
        
        if response.status_code != 200:
            raise Exception("Failed to get user info")
        
        data = response.json()
        return data.get("email", "")
    
    # -------------------------------------------------------------------------
    # Token Management with Auto-Refresh
    # -------------------------------------------------------------------------
    async def get_valid_credentials(self, user_id: str) -> Optional[Dict[str, Any]]:
        """
        Get valid credentials for a user, refreshing if needed.
        
        Returns:
            Dict with access_token and other token info, or None if not connected
        """
        tokens = await calendar_db_service.get_tokens(user_id)
        if not tokens:
            return None
        
        # Check if token is expired (with 5 min buffer)
        now = datetime.now(timezone.utc)
        expiry = tokens["token_expiry"]
        
        # Ensure expiry is timezone-aware
        if expiry.tzinfo is None:
            expiry = expiry.replace(tzinfo=timezone.utc)
        
        if now + timedelta(minutes=5) >= expiry:
            logger.info(f"🔄 Refreshing expired token for user {user_id}")
            
            try:
                new_tokens = await self.refresh_access_token(tokens["refresh_token"])
                new_expiry = datetime.now(timezone.utc) + timedelta(seconds=new_tokens["expires_in"])
                
                await calendar_db_service.update_access_token(
                    user_id=user_id,
                    access_token=new_tokens["access_token"],
                    token_expiry=new_expiry
                )
                
                tokens["access_token"] = new_tokens["access_token"]
                tokens["token_expiry"] = new_expiry
                
            except Exception as e:
                logger.error(f"Failed to refresh token for user {user_id}: {e}")
                return None
        
        return tokens
    
    def _build_service(self, access_token: str):
        """Build Google Calendar API service."""
        credentials = Credentials(token=access_token)
        return build("calendar", "v3", credentials=credentials, cache_discovery=False)
    
    # -------------------------------------------------------------------------
    # Calendar Discovery
    # -------------------------------------------------------------------------
    async def discover_calendars(self, user_id: str) -> List[Dict[str, Any]]:
        """
        Discover all calendars for a user.
        
        Returns:
            List of calendars with id, name, access_role, color
        """
        creds = await self.get_valid_credentials(user_id)
        if not creds:
            raise Exception("User not connected to Google Calendar")
        
        service = self._build_service(creds["access_token"])
        
        # Run in thread pool since googleapiclient is synchronous
        import asyncio
        loop = asyncio.get_event_loop()
        
        def fetch_calendars():
            calendars = []
            page_token = None
            
            while True:
                calendar_list = service.calendarList().list(pageToken=page_token).execute()
                
                for item in calendar_list.get("items", []):
                    calendars.append({
                        "google_calendar_id": item["id"],
                        "calendar_name": item.get("summary", "Unnamed"),
                        "access_role": item.get("accessRole", "reader"),
                        "color": item.get("backgroundColor"),
                    })
                
                page_token = calendar_list.get("nextPageToken")
                if not page_token:
                    break
            
            return calendars
        
        calendars = await loop.run_in_executor(None, fetch_calendars)
        
        # Save to database
        await calendar_db_service.save_calendars(creds["integration_id"], calendars)
        
        return calendars
    
    # -------------------------------------------------------------------------
    # Event Operations
    # -------------------------------------------------------------------------
    async def get_events(
        self,
        user_id: str,
        start_time: datetime,
        end_time: datetime,
        calendar_ids: Optional[List[str]] = None
    ) -> List[Dict[str, Any]]:
        """
        Get events from user's calendars.
        
        Args:
            user_id: User ID
            start_time: Start of time range (UTC)
            end_time: End of time range (UTC)
            calendar_ids: Specific calendars to query (None = all synced)
            
        Returns:
            List of events with source calendar info
        """
        creds = await self.get_valid_credentials(user_id)
        if not creds:
            raise Exception("User not connected to Google Calendar")
        
        # Get calendars to query
        if calendar_ids is None:
            calendar_ids = await calendar_db_service.get_synced_calendars(user_id)
        
        if not calendar_ids:
            return []
        
        # Build calendar ID to name mapping
        all_calendars = await calendar_db_service.get_calendars(user_id)
        calendar_name_map = {}
        for cal in all_calendars:
            calendar_name_map[cal["google_calendar_id"]] = cal.get("calendar_name", cal["google_calendar_id"])
        
        service = self._build_service(creds["access_token"])
        
        # Format times for Google API - ensure timezone suffix
        time_min = start_time.isoformat()
        time_max = end_time.isoformat()
        if not time_min.endswith("Z") and "+" not in time_min:
            time_min += "Z"
        if not time_max.endswith("Z") and "+" not in time_max:
            time_max += "Z"
        
        import asyncio
        loop = asyncio.get_event_loop()
        
        all_events = []
        
        def fetch_events_for_calendar(cal_id: str, cal_name: str):
            events = []
            try:
                events_result = service.events().list(
                    calendarId=cal_id,
                    timeMin=time_min,
                    timeMax=time_max,
                    singleEvents=True,
                    orderBy="startTime"
                ).execute()
                
                for event in events_result.get("items", []):
                    # Parse start/end times
                    start = event.get("start", {})
                    end = event.get("end", {})
                    
                    events.append({
                        "id": event.get("id"),
                        "title": event.get("summary", "No Title"),
                        "description": event.get("description", ""),
                        "start": start.get("dateTime") or start.get("date"),
                        "end": end.get("dateTime") or end.get("date"),
                        "location": event.get("location", ""),
                        "all_day": "date" in start,
                        "calendar": cal_name,  # Human-readable name for AI to use
                        "calendar_id": cal_id,  # ID for API operations
                        "is_recurring": "recurringEventId" in event,
                        "recurring_event_id": event.get("recurringEventId"),
                        "html_link": event.get("htmlLink"),
                    })
            except Exception as e:
                logger.error(f"Failed to fetch events from {cal_id}: {e}")
            
            return events
        
        # Fetch from all calendars
        for cal_id in calendar_ids:
            cal_name = calendar_name_map.get(cal_id, cal_id)
            events = await loop.run_in_executor(None, fetch_events_for_calendar, cal_id, cal_name)
            all_events.extend(events)
        
        # Sort by start time
        all_events.sort(key=lambda e: e.get("start", ""))
        
        return all_events

    async def create_event(
        self,
        user_id: str,
        title: str,
        start_time: datetime,
        end_time: datetime,
        description: str = "",
        location: str = "",
        calendar_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Create a new calendar event.
        
        Args:
            user_id: User ID
            title: Event title/summary
            start_time: Event start time (UTC)
            end_time: Event end time (UTC)
            description: Optional event description
            location: Optional event location
            calendar_id: Specific calendar to create in (None = primary)
            
        Returns:
            Created event details
        """
        creds = await self.get_valid_credentials(user_id)
        if not creds:
            raise Exception("User not connected to Google Calendar")
        
        service = self._build_service(creds["access_token"])
        
        # Use primary calendar if not specified
        if calendar_id is None:
            calendar_id = "primary"
        
        # Build event body
        event_body = {
            "summary": title,
            "start": {
                "dateTime": start_time.isoformat(),
                "timeZone": "UTC",
            },
            "end": {
                "dateTime": end_time.isoformat(),
                "timeZone": "UTC",
            },
        }
        
        if description:
            event_body["description"] = description
        if location:
            event_body["location"] = location
        
        import asyncio
        loop = asyncio.get_event_loop()
        
        def create():
            return service.events().insert(
                calendarId=calendar_id,
                body=event_body
            ).execute()
        
        created_event = await loop.run_in_executor(None, create)
        
        logger.info(f"📅 Created event '{title}' for user {user_id}")
        
        return {
            "id": created_event.get("id"),
            "title": created_event.get("summary"),
            "start": created_event.get("start", {}).get("dateTime"),
            "end": created_event.get("end", {}).get("dateTime"),
            "html_link": created_event.get("htmlLink"),
        }

    async def delete_event(
        self,
        user_id: str,
        event_id: str,
        calendar_id: Optional[str] = None
    ) -> bool:
        """
        Delete a calendar event by ID.
        
        Args:
            user_id: User ID
            event_id: Google Calendar event ID
            calendar_id: Specific calendar to delete from (None = primary)
            
        Returns:
            True if deleted successfully
        """
        creds = await self.get_valid_credentials(user_id)
        if not creds:
            raise Exception("User not connected to Google Calendar")
        
        service = self._build_service(creds["access_token"])
        
        # Use primary calendar if not specified
        if calendar_id is None:
            calendar_id = "primary"
        
        import asyncio
        loop = asyncio.get_event_loop()
        
        def delete():
            service.events().delete(
                calendarId=calendar_id,
                eventId=event_id
            ).execute()
        
        await loop.run_in_executor(None, delete)
        
        logger.info(f"🗑️ Deleted event '{event_id}' for user {user_id}")
        
        return True

    async def update_event(
        self,
        user_id: str,
        event_id: str,
        calendar_id: Optional[str] = None,
        title: Optional[str] = None,
        start_time: Optional[datetime] = None,
        end_time: Optional[datetime] = None,
        description: Optional[str] = None,
        location: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Update an existing calendar event (partial update).
        Only provided fields are updated.
        """
        creds = await self.get_valid_credentials(user_id)
        if not creds:
            raise Exception("User not connected to Google Calendar")
        
        service = self._build_service(creds["access_token"])
        
        if calendar_id is None:
            calendar_id = "primary"
        
        # Build patch body with only provided fields
        patch_body = {}
        if title is not None:
            patch_body["summary"] = title
        if start_time is not None:
            patch_body["start"] = {"dateTime": start_time.isoformat(), "timeZone": "UTC"}
        if end_time is not None:
            patch_body["end"] = {"dateTime": end_time.isoformat(), "timeZone": "UTC"}
        if description is not None:
            patch_body["description"] = description
        if location is not None:
            patch_body["location"] = location
        
        import asyncio
        loop = asyncio.get_event_loop()
        
        def patch():
            return service.events().patch(
                calendarId=calendar_id,
                eventId=event_id,
                body=patch_body
            ).execute()
        
        updated_event = await loop.run_in_executor(None, patch)
        
        logger.info(f"✏️ Updated event '{event_id}' for user {user_id}")
        
        return {
            "id": updated_event.get("id"),
            "title": updated_event.get("summary"),
            "start": updated_event.get("start", {}).get("dateTime"),
            "end": updated_event.get("end", {}).get("dateTime"),
            "html_link": updated_event.get("htmlLink"),
        }

    async def get_next_event(
        self,
        user_id: str
    ) -> Optional[Dict[str, Any]]:
        """
        Get the next upcoming event.
        """
        creds = await self.get_valid_credentials(user_id)
        if not creds:
            raise Exception("User not connected to Google Calendar")
        
        service = self._build_service(creds["access_token"])
        
        import asyncio
        loop = asyncio.get_event_loop()
        
        now = datetime.now(timezone.utc).isoformat()
        
        def fetch():
            return service.events().list(
                calendarId="primary",
                timeMin=now,
                maxResults=1,
                singleEvents=True,
                orderBy="startTime"
            ).execute()
        
        result = await loop.run_in_executor(None, fetch)
        events = result.get("items", [])
        
        if not events:
            return None
        
        event = events[0]
        start = event.get("start", {})
        end = event.get("end", {})
        
        return {
            "id": event.get("id"),
            "title": event.get("summary", "Untitled"),
            "start": start.get("dateTime") or start.get("date"),
            "end": end.get("dateTime") or end.get("date"),
            "location": event.get("location"),
            "all_day": "date" in start,
        }

    async def search_events(
        self,
        user_id: str,
        query: str,
        start_time: Optional[datetime] = None,
        end_time: Optional[datetime] = None,
        max_results: int = 10
    ) -> List[Dict[str, Any]]:
        """
        Search events by text query across ALL synced calendars.
        """
        creds = await self.get_valid_credentials(user_id)
        if not creds:
            raise Exception("User not connected to Google Calendar")
        
        # Get all synced calendars
        calendar_ids = await calendar_db_service.get_synced_calendars(user_id)
        if not calendar_ids:
            calendar_ids = ["primary"]
        
        # Build calendar ID to name mapping
        all_calendars = await calendar_db_service.get_calendars(user_id)
        calendar_name_map = {}
        for cal in all_calendars:
            calendar_name_map[cal["google_calendar_id"]] = cal.get("calendar_name", cal["google_calendar_id"])
        
        service = self._build_service(creds["access_token"])
        
        import asyncio
        loop = asyncio.get_event_loop()
        
        # Default time range
        if start_time is None:
            start_time = datetime.now(timezone.utc) - timedelta(days=365)
        if end_time is None:
            end_time = datetime.now(timezone.utc) + timedelta(days=365)
        
        def fetch_for_calendar(cal_id: str):
            try:
                return service.events().list(
                    calendarId=cal_id,
                    q=query,
                    timeMin=start_time.isoformat(),
                    timeMax=end_time.isoformat(),
                    maxResults=max_results,
                    singleEvents=True,
                    orderBy="startTime"
                ).execute().get("items", [])
            except Exception as e:
                logger.error(f"Search failed for calendar {cal_id}: {e}")
                return []
        
        # Search all calendars
        all_events = []
        for cal_id in calendar_ids:
            events = await loop.run_in_executor(None, fetch_for_calendar, cal_id)
            cal_name = calendar_name_map.get(cal_id, cal_id)
            for event in events:
                start = event.get("start", {})
                end = event.get("end", {})
                all_events.append({
                    "id": event.get("id"),
                    "title": event.get("summary", "Untitled"),
                    "start": start.get("dateTime") or start.get("date"),
                    "end": end.get("dateTime") or end.get("date"),
                    "location": event.get("location"),
                    "calendar": cal_name,
                    "calendar_id": cal_id,
                })
        
        # Sort by start time and limit results
        all_events.sort(key=lambda e: e.get("start", ""))
        return all_events[:max_results]

    async def find_free_slots(
        self,
        user_id: str,
        start_time: datetime,
        end_time: datetime,
        duration_minutes: int = 60,
        working_hours_start: int = 9,
        working_hours_end: int = 17
    ) -> List[Dict[str, Any]]:
        """
        Find free time slots of specified duration within a time range.
        Respects working hours.
        """
        creds = await self.get_valid_credentials(user_id)
        if not creds:
            raise Exception("User not connected to Google Calendar")
        
        service = self._build_service(creds["access_token"])
        
        import asyncio
        loop = asyncio.get_event_loop()
        
        # Get busy times using freebusy API
        def fetch_busy():
            body = {
                "timeMin": start_time.isoformat(),
                "timeMax": end_time.isoformat(),
                "items": [{"id": "primary"}]
            }
            return service.freebusy().query(body=body).execute()
        
        result = await loop.run_in_executor(None, fetch_busy)
        busy_periods = result.get("calendars", {}).get("primary", {}).get("busy", [])
        
        # Convert busy periods to datetime objects
        busy_slots = []
        for period in busy_periods:
            busy_start = datetime.fromisoformat(period["start"].replace("Z", "+00:00"))
            busy_end = datetime.fromisoformat(period["end"].replace("Z", "+00:00"))
            busy_slots.append((busy_start, busy_end))
        
        # Find free slots
        free_slots = []
        current = start_time
        duration = timedelta(minutes=duration_minutes)
        
        while current + duration <= end_time:
            # Check if within working hours
            if current.hour >= working_hours_start and (current.hour + duration_minutes // 60) <= working_hours_end:
                # Check if slot overlaps with any busy period
                slot_end = current + duration
                is_free = True
                
                for busy_start, busy_end in busy_slots:
                    if not (slot_end <= busy_start or current >= busy_end):
                        is_free = False
                        # Jump to end of this busy period
                        current = busy_end
                        break
                
                if is_free:
                    free_slots.append({
                        "start": current.isoformat(),
                        "end": slot_end.isoformat(),
                        "duration_minutes": duration_minutes
                    })
                    # Move to next potential slot (30 min increments)
                    current += timedelta(minutes=30)
                    
                    # Limit results
                    if len(free_slots) >= 10:
                        break
            else:
                # Move to next day's working hours
                current = current.replace(hour=working_hours_start, minute=0, second=0, microsecond=0)
                if current <= start_time:
                    current += timedelta(days=1)
        
        return free_slots


# Singleton instance
google_calendar_service = GoogleCalendarService()
