"""
Calendar Tools for AI Agent
===========================

Gemini-compatible tool functions for calendar operations.
These are called by the agent when the user asks about their schedule.
"""

import json
import logging
from datetime import datetime, timezone, timedelta
from typing import Optional, List, Dict, Any

from services.google_calendar_service import google_calendar_service
from services.calendar_db_service import calendar_db_service

logger = logging.getLogger(__name__)


# -----------------------------------------------------------------------------
# Tool Definitions (for Gemini/OpenAI format)
# -----------------------------------------------------------------------------
CALENDAR_TOOL_DEFINITIONS = [
    {
        "name": "get_detailed_schedule",
        "description": "Get the user's calendar events for a specific time range. Use this when the user asks about their schedule, meetings, appointments, or what's on their calendar.",
        "parameters": {
            "type": "object",
            "properties": {
                "start_time": {
                    "type": "string",
                    "description": "Start of the time range in ISO 8601 format (e.g., '2024-01-15T00:00:00Z'). Use the current date for 'today'."
                },
                "end_time": {
                    "type": "string",
                    "description": "End of the time range in ISO 8601 format. For a single day, set to end of that day."
                }
            },
            "required": ["start_time", "end_time"]
        }
    },
    {
        "name": "check_calendar_availability",
        "description": "Check if the user is free or busy at a specific time. Use this when the user asks if they have time for something.",
        "parameters": {
            "type": "object",
            "properties": {
                "check_time": {
                    "type": "string",
                    "description": "The time to check availability for in ISO 8601 format."
                },
                "duration_minutes": {
                    "type": "integer",
                    "description": "Duration in minutes to check availability for. Default is 60."
                }
            },
            "required": ["check_time"]
        }
    },
    {
        "name": "list_user_calendars",
        "description": "List all calendars available to the user. Call this FIRST when the user wants to add an event to a specific calendar, so you know which calendars exist and their exact names.",
        "parameters": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "create_calendar_event",
        "description": "Create a new event on the user's calendar. This tool automatically checks for conflicting events. If conflicts exist and force_create is False, it returns the conflicts so you can inform the user professionally (like a secretary) and ask if they want to proceed. Only set force_create=True after user confirmation.",
        "parameters": {
            "type": "object",
            "properties": {
                "title": {
                    "type": "string",
                    "description": "The title or name of the event (e.g., 'Team Meeting', 'TV Time')"
                },
                "start_time": {
                    "type": "string",
                    "description": "Start time of the event in ISO 8601 format (e.g., '2024-01-15T13:00:00Z')"
                },
                "end_time": {
                    "type": "string",
                    "description": "End time of the event in ISO 8601 format (e.g., '2024-01-15T15:00:00Z')"
                },
                "calendar_name": {
                    "type": "string",
                    "description": "The exact name of the calendar to add the event to. Get this from list_user_calendars. If not specified, uses the primary calendar."
                },
                "force_create": {
                    "type": "boolean",
                    "description": "If True, create the event even if conflicts exist. Default is False. Only set to True AFTER informing the user about conflicts and getting their confirmation."
                },
                "description": {
                    "type": "string",
                    "description": "Optional description or notes for the event"
                },
                "location": {
                    "type": "string",
                    "description": "Optional location for the event"
                }
            },
            "required": ["title", "start_time", "end_time"]
        }
    },
    {
        "name": "delete_calendar_event",
        "description": "Delete a calendar event by its ID. Use get_detailed_schedule first to find the event ID, then call this to delete it. The event ID is returned in each event from get_detailed_schedule.",
        "parameters": {
            "type": "object",
            "properties": {
                "event_id": {
                    "type": "string",
                    "description": "The unique ID of the event to delete (from get_detailed_schedule results)"
                },
                "calendar_id": {
                    "type": "string",
                    "description": "The calendar ID where the event is located. Use 'primary' if unsure."
                }
            },
            "required": ["event_id"]
        }
    },
    {
        "name": "update_calendar_event",
        "description": "Update an existing calendar event. You can change the title, time, description, or location. IMPORTANT: For events on secondary calendars (not primary), you MUST provide the calendar_name to avoid 404 errors. First use get_detailed_schedule to find the event ID and calendar name.",
        "parameters": {
            "type": "object",
            "properties": {
                "event_id": {
                    "type": "string",
                    "description": "The unique ID of the event to update"
                },
                "calendar_name": {
                    "type": "string",
                    "description": "Name of the calendar the event is on (e.g., 'Workout', 'Entertainment'). Required for secondary calendars!"
                },
                "title": {
                    "type": "string",
                    "description": "New title for the event (optional)"
                },
                "start_time": {
                    "type": "string",
                    "description": "New start time in ISO 8601 format (optional)"
                },
                "end_time": {
                    "type": "string",
                    "description": "New end time in ISO 8601 format (optional)"
                },
                "description": {
                    "type": "string",
                    "description": "New description (optional)"
                },
                "location": {
                    "type": "string",
                    "description": "New location (optional)"
                }
            },
            "required": ["event_id"]
        }
    },
    {
        "name": "get_next_event",
        "description": "Get the user's next upcoming event. Use when user asks 'What's my next meeting?' or 'When do I need to leave?'",
        "parameters": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "search_events",
        "description": "Search for events by keyword. Searches in event titles, descriptions, locations, and attendees. Use when user asks 'Find all meetings with John' or 'When was my last dentist appointment?'",
        "parameters": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Search query (e.g., person name, event type, location)"
                },
                "start_time": {
                    "type": "string",
                    "description": "Optional start of search range in ISO 8601 format"
                },
                "end_time": {
                    "type": "string",
                    "description": "Optional end of search range in ISO 8601 format"
                }
            },
            "required": ["query"]
        }
    },
    {
        "name": "find_free_slots",
        "description": "Find available time slots for scheduling. Use when user asks 'When am I free tomorrow?' or 'Find a 2-hour slot for a meeting next week'. Returns multiple free time options.",
        "parameters": {
            "type": "object",
            "properties": {
                "start_time": {
                    "type": "string",
                    "description": "Start of range to search in ISO 8601 format"
                },
                "end_time": {
                    "type": "string",
                    "description": "End of range to search in ISO 8601 format"
                },
                "duration_minutes": {
                    "type": "integer",
                    "description": "Required duration in minutes (default: 60)"
                },
                "working_hours_start": {
                    "type": "integer",
                    "description": "Start of working hours (0-23, default: 9)"
                },
                "working_hours_end": {
                    "type": "integer",
                    "description": "End of working hours (0-23, default: 17)"
                }
            },
            "required": ["start_time", "end_time"]
        }
    },
    # Phase 2: Power User Tools
    {
        "name": "reschedule_event",
        "description": "Reschedule an event to a new time. Can move by a relative offset (e.g., '30 minutes later') or to an absolute time. Use when user says 'Push my standup 30 minutes' or 'Move my meeting to 3pm'.",
        "parameters": {
            "type": "object",
            "properties": {
                "event_id": {
                    "type": "string",
                    "description": "ID of the event to reschedule"
                },
                "new_start_time": {
                    "type": "string",
                    "description": "New start time in ISO 8601 format (required)"
                },
                "new_end_time": {
                    "type": "string",
                    "description": "New end time in ISO 8601 format (optional - will maintain original duration if not specified)"
                }
            },
            "required": ["event_id", "new_start_time"]
        }
    },
    {
        "name": "find_conflicts",
        "description": "Find all scheduling conflicts (overlapping events) in a time range. Use when user asks 'Do I have any double-bookings?' or 'Check for conflicts this week'.",
        "parameters": {
            "type": "object",
            "properties": {
                "start_time": {
                    "type": "string",
                    "description": "Start of range to check in ISO 8601 format"
                },
                "end_time": {
                    "type": "string",
                    "description": "End of range to check in ISO 8601 format"
                }
            },
            "required": ["start_time", "end_time"]
        }
    },
    {
        "name": "get_daily_summary",
        "description": "Get a human-readable summary of a day's schedule. Includes total meeting time, number of events, and free time. Use when user asks 'Brief me on today' or 'What's my day look like tomorrow?'.",
        "parameters": {
            "type": "object",
            "properties": {
                "date": {
                    "type": "string",
                    "description": "Date to summarize in YYYY-MM-DD format (defaults to today)"
                }
            },
            "required": []
        }
    },
    # Phase 3: Advanced Tools
    {
        "name": "block_focus_time",
        "description": "Block out time for focused work or personal time. Creates a 'Focus Time' or custom-named event. Use when user says 'Block 2 hours for deep work tomorrow morning'.",
        "parameters": {
            "type": "object",
            "properties": {
                "start_time": {
                    "type": "string",
                    "description": "Start time in ISO 8601 format"
                },
                "duration_minutes": {
                    "type": "integer",
                    "description": "Duration in minutes (default: 60)"
                },
                "title": {
                    "type": "string",
                    "description": "Title for the block (default: 'Focus Time')"
                }
            },
            "required": ["start_time"]
        }
    },
    {
        "name": "cancel_events_in_range",
        "description": "Cancel (delete) multiple events in a time range. Use with caution! For clearing a day for vacation or canceling all meetings. Requires title_filter for safety.",
        "parameters": {
            "type": "object",
            "properties": {
                "start_time": {
                    "type": "string",
                    "description": "Start of range in ISO 8601 format"
                },
                "end_time": {
                    "type": "string",
                    "description": "End of range in ISO 8601 format"
                },
                "title_filter": {
                    "type": "string",
                    "description": "Only cancel events containing this text (optional but recommended for safety)"
                },
                "confirm": {
                    "type": "boolean",
                    "description": "Must be true to proceed with deletion"
                }
            },
            "required": ["start_time", "end_time", "confirm"]
        }
    }
]


# -----------------------------------------------------------------------------
# Tool Implementation Functions
# -----------------------------------------------------------------------------
async def get_detailed_schedule(
    user_id: str,
    start_time: str,
    end_time: str
) -> str:
    """
    Fetch user's calendar events across all synced calendars.
    
    Returns:
        JSON string with events including source calendar name
    """
    try:
        # Check if user has calendar connected
        if not await calendar_db_service.has_integration(user_id):
            return json.dumps({
                "error": "not_connected",
                "message": "Google Calendar is not connected. Please ask the user to connect their calendar first."
            })
        
        # Parse times
        try:
            start = datetime.fromisoformat(start_time.replace("Z", "+00:00"))
            end = datetime.fromisoformat(end_time.replace("Z", "+00:00"))
        except ValueError as e:
            return json.dumps({
                "error": "invalid_time",
                "message": f"Could not parse time: {e}"
            })
        
        # Fetch events
        events = await google_calendar_service.get_events(
            user_id=user_id,
            start_time=start,
            end_time=end
        )
        
        if not events:
            return json.dumps({
                "status": "success",
                "message": "No events found in this time range.",
                "events": []
            })
        
        # Format events for AI consumption
        formatted_events = []
        for event in events:
            formatted_events.append({
                "id": event.get("id"),  # Include event ID for deletion
                "title": event["title"],
                "start": event["start"],
                "end": event["end"],
                "location": event["location"] if event["location"] else None,
                "all_day": event["all_day"],
                "calendar": event["source_calendar"],
                "attendees_count": len(event.get("attendees", []))
            })
        
        return json.dumps({
            "status": "success",
            "event_count": len(formatted_events),
            "events": formatted_events
        })
        
    except Exception as e:
        logger.error(f"get_detailed_schedule error: {e}")
        return json.dumps({
            "error": "api_error",
            "message": f"Failed to fetch calendar: {str(e)}"
        })


async def check_calendar_availability(
    user_id: str,
    check_time: str,
    duration_minutes: int = 60
) -> str:
    """
    Check if user is free at a specific time.
    
    Returns:
        JSON string with availability status
    """
    try:
        # Check if user has calendar connected
        if not await calendar_db_service.has_integration(user_id):
            return json.dumps({
                "error": "not_connected",
                "message": "Google Calendar is not connected."
            })
        
        # Parse time
        try:
            start = datetime.fromisoformat(check_time.replace("Z", "+00:00"))
            end = start + timedelta(minutes=duration_minutes)
        except ValueError as e:
            return json.dumps({
                "error": "invalid_time",
                "message": f"Could not parse time: {e}"
            })
        
        # Fetch events in this window
        events = await google_calendar_service.get_events(
            user_id=user_id,
            start_time=start,
            end_time=end
        )
        
        if not events:
            return json.dumps({
                "status": "available",
                "message": f"User is free from {start.strftime('%H:%M')} to {end.strftime('%H:%M')}.",
                "conflicting_events": []
            })
        
        # Format conflicts
        conflicts = [
            {"title": e["title"], "start": e["start"], "end": e["end"]}
            for e in events
        ]
        
        return json.dumps({
            "status": "busy",
            "message": f"User has {len(events)} conflicting event(s).",
            "conflicting_events": conflicts
        })
        
    except Exception as e:
        logger.error(f"check_calendar_availability error: {e}")
        return json.dumps({
            "error": "api_error",
            "message": f"Failed to check availability: {str(e)}"
        })


async def list_user_calendars(user_id: str) -> str:
    """
    List all calendars available to the user.
    
    Returns:
        JSON string with list of calendars
    """
    try:
        # Check if user has calendar connected
        if not await calendar_db_service.has_integration(user_id):
            return json.dumps({
                "error": "not_connected",
                "message": "Google Calendar is not connected. Please ask the user to connect their calendar first."
            })
        
        # Get all calendar sources
        calendars = await calendar_db_service.get_all_calendars(user_id)
        
        if not calendars:
            return json.dumps({
                "status": "success",
                "message": "No calendars found. Try refreshing calendar sources.",
                "calendars": []
            })
        
        # Format for AI
        formatted = []
        for cal in calendars:
            formatted.append({
                "name": cal["calendar_name"],
                "id": cal["google_calendar_id"],
                "access_role": cal["access_role"],
                "sync_enabled": cal["sync_enabled"]
            })
        
        return json.dumps({
            "status": "success",
            "calendar_count": len(formatted),
            "calendars": formatted,
            "hint": "Use the exact 'name' field when creating events on a specific calendar."
        })
        
    except Exception as e:
        logger.error(f"list_user_calendars error: {e}")
        return json.dumps({
            "error": "api_error",
            "message": f"Failed to list calendars: {str(e)}"
        })


async def create_calendar_event(
    user_id: str,
    title: str,
    start_time: str,
    end_time: str,
    calendar_name: str = "",
    force_create: bool = False,
    description: str = "",
    location: str = ""
) -> str:
    """
    Create a new calendar event with conflict detection.
    
    Returns:
        JSON string with created event details, or conflict information if overlapping events exist
    """
    try:
        # Check if user has calendar connected
        if not await calendar_db_service.has_integration(user_id):
            return json.dumps({
                "error": "not_connected",
                "message": "Google Calendar is not connected. Please ask the user to connect their calendar first."
            })
        
        # Parse times
        try:
            start = datetime.fromisoformat(start_time.replace("Z", "+00:00"))
            end = datetime.fromisoformat(end_time.replace("Z", "+00:00"))
        except ValueError as e:
            return json.dumps({
                "error": "invalid_time",
                "message": f"Could not parse time: {e}"
            })
        
        # Look up calendar ID by name if provided
        calendar_id = None
        target_calendar_name = "Primary Calendar"
        if calendar_name:
            calendars = await calendar_db_service.get_all_calendars(user_id)
            for cal in calendars:
                if calendar_name.lower() in cal["calendar_name"].lower():
                    calendar_id = cal["google_calendar_id"]
                    target_calendar_name = cal["calendar_name"]
                    break
            
            if not calendar_id:
                # Return helpful error with available calendars
                available = [c["calendar_name"] for c in calendars]
                return json.dumps({
                    "error": "calendar_not_found",
                    "message": f"Calendar '{calendar_name}' not found.",
                    "available_calendars": available,
                    "hint": "Please use one of the available calendar names or leave empty for primary calendar."
                })
        
        # Check for conflicts across ALL synced calendars
        conflicts = await google_calendar_service.get_events(
            user_id=user_id,
            start_time=start,
            end_time=end
        )
        
        if conflicts and not force_create:
            # Format conflicts professionally for the AI to present
            conflict_details = []
            for event in conflicts:
                conflict_details.append({
                    "title": event["title"],
                    "start": event["start"],
                    "end": event["end"],
                    "calendar": event.get("source_calendar", "Unknown"),
                })
            
            return json.dumps({
                "status": "conflict_detected",
                "message": f"There are {len(conflicts)} existing event(s) during this time slot.",
                "conflicts": conflict_details,
                "proposed_event": {
                    "title": title,
                    "start": start_time,
                    "end": end_time,
                    "calendar": target_calendar_name
                },
                "action_required": "Please inform the user about the conflicts professionally and ask if they still want to create the event. If yes, call this function again with force_create=True.",
                "suggestion": "You may also suggest alternative times if the user prefers."
            })
        
        # Create the event (either no conflicts or force_create=True)
        created_event = await google_calendar_service.create_event(
            user_id=user_id,
            title=title,
            start_time=start,
            end_time=end,
            description=description,
            location=location,
            calendar_id=calendar_id
        )
        
        response_msg = f"Event '{title}' created successfully on {target_calendar_name}!"
        if conflicts:
            response_msg += f" (Note: {len(conflicts)} overlapping event(s) exist)"
        
        return json.dumps({
            "status": "success",
            "message": response_msg,
            "event": created_event
        })
        
    except Exception as e:
        logger.error(f"create_calendar_event error: {e}")
        return json.dumps({
            "error": "api_error",
            "message": f"Failed to create event: {str(e)}"
        })


# -----------------------------------------------------------------------------
# Tool Executor (for Agent Service integration)
# -----------------------------------------------------------------------------
async def execute_calendar_tool(
    tool_name: str,
    args: Dict[str, Any],
    user_id: str
) -> str:
    """
    Execute a calendar tool by name.
    
    This is called by the agent service when the LLM requests a calendar tool.
    """
    logger.info(f"📅 [CalendarTool] Executing '{tool_name}' for user '{user_id}'")
    logger.info(f"📅 [CalendarTool] Args: {args}")
    if tool_name == "get_detailed_schedule":
        return await get_detailed_schedule(
            user_id=user_id,
            start_time=args.get("start_time", ""),
            end_time=args.get("end_time", "")
        )
    elif tool_name == "check_calendar_availability":
        return await check_calendar_availability(
            user_id=user_id,
            check_time=args.get("check_time", ""),
            duration_minutes=args.get("duration_minutes", 60)
        )
    elif tool_name == "list_user_calendars":
        return await list_user_calendars(user_id=user_id)
    elif tool_name == "create_calendar_event":
        return await create_calendar_event(
            user_id=user_id,
            title=args.get("title", ""),
            start_time=args.get("start_time", ""),
            end_time=args.get("end_time", ""),
            calendar_name=args.get("calendar_name", ""),
            force_create=args.get("force_create", False),
            description=args.get("description", ""),
            location=args.get("location", "")
        )
    elif tool_name == "delete_calendar_event":
        return await delete_calendar_event(
            user_id=user_id,
            event_id=args.get("event_id", ""),
            calendar_id=args.get("calendar_id", "primary")
        )
    elif tool_name == "update_calendar_event":
        return await update_calendar_event(
            user_id=user_id,
            event_id=args.get("event_id", ""),
            calendar_name=args.get("calendar_name"),
            title=args.get("title"),
            start_time=args.get("start_time"),
            end_time=args.get("end_time"),
            description=args.get("description"),
            location=args.get("location")
        )
    elif tool_name == "get_next_event":
        return await get_next_event(user_id=user_id)
    elif tool_name == "search_events":
        return await search_events(
            user_id=user_id,
            query=args.get("query", ""),
            start_time=args.get("start_time"),
            end_time=args.get("end_time")
        )
    elif tool_name == "find_free_slots":
        return await find_free_slots_tool(
            user_id=user_id,
            start_time=args.get("start_time", ""),
            end_time=args.get("end_time", ""),
            duration_minutes=args.get("duration_minutes", 60),
            working_hours_start=args.get("working_hours_start", 9),
            working_hours_end=args.get("working_hours_end", 17)
        )
    elif tool_name == "reschedule_event":
        return await reschedule_event(
            user_id=user_id,
            event_id=args.get("event_id", ""),
            new_start_time=args.get("new_start_time", ""),
            new_end_time=args.get("new_end_time"),
            calendar_name=args.get("calendar_name")
        )
    elif tool_name == "find_conflicts":
        return await find_conflicts(
            user_id=user_id,
            start_time=args.get("start_time", ""),
            end_time=args.get("end_time", "")
        )
    elif tool_name == "get_daily_summary":
        return await get_daily_summary(
            user_id=user_id,
            date=args.get("date")
        )
    elif tool_name == "block_focus_time":
        return await block_focus_time(
            user_id=user_id,
            start_time=args.get("start_time", ""),
            duration_minutes=args.get("duration_minutes", 60),
            title=args.get("title", "Focus Time")
        )
    elif tool_name == "cancel_events_in_range":
        return await cancel_events_in_range(
            user_id=user_id,
            start_time=args.get("start_time", ""),
            end_time=args.get("end_time", ""),
            title_filter=args.get("title_filter"),
            confirm=args.get("confirm", False)
        )
    else:
        return json.dumps({"error": "unknown_tool", "message": f"Unknown tool: {tool_name}"})


async def delete_calendar_event(
    user_id: str,
    event_id: str,
    calendar_id: str = "primary"
) -> str:
    """Delete a calendar event by ID."""
    try:
        if not await calendar_db_service.has_integration(user_id):
            return json.dumps({
                "error": "not_connected",
                "message": "Google Calendar is not connected."
            })
        
        if not event_id:
            return json.dumps({
                "error": "missing_event_id",
                "message": "No event ID provided. Use get_detailed_schedule first."
            })
        
        await google_calendar_service.delete_event(user_id, event_id, calendar_id)
        
        return json.dumps({
            "status": "success",
            "message": "Event deleted successfully!"
        })
        
    except Exception as e:
        logger.error(f"delete_calendar_event error: {e}")
        return json.dumps({"error": "api_error", "message": str(e)})


async def update_calendar_event(
    user_id: str,
    event_id: str,
    calendar_name: Optional[str] = None,
    title: Optional[str] = None,
    start_time: Optional[str] = None,
    end_time: Optional[str] = None,
    description: Optional[str] = None,
    location: Optional[str] = None
) -> str:
    """Update an existing calendar event."""
    try:
        if not await calendar_db_service.has_integration(user_id):
            return json.dumps({
                "error": "not_connected",
                "message": "Google Calendar is not connected."
            })
        
        if not event_id:
            return json.dumps({
                "error": "missing_event_id",
                "message": "No event ID provided."
            })
        
        # Resolve calendar_name to calendar_id
        calendar_id = None
        if calendar_name:
            calendars = await calendar_db_service.get_all_calendars(user_id)
            for cal in calendars:
                if calendar_name.lower() in cal["calendar_name"].lower():
                    calendar_id = cal["google_calendar_id"]
                    break
        
        # Parse times if provided
        parsed_start = None
        parsed_end = None
        if start_time:
            parsed_start = datetime.fromisoformat(start_time.replace("Z", "+00:00"))
        if end_time:
            parsed_end = datetime.fromisoformat(end_time.replace("Z", "+00:00"))
        
        updated = await google_calendar_service.update_event(
            user_id=user_id,
            event_id=event_id,
            calendar_id=calendar_id,
            title=title,
            start_time=parsed_start,
            end_time=parsed_end,
            description=description,
            location=location
        )
        
        return json.dumps({
            "status": "success",
            "message": "Event updated successfully!",
            "event": updated
        })
        
    except Exception as e:
        logger.error(f"update_calendar_event error: {e}")
        return json.dumps({"error": "api_error", "message": str(e)})


async def get_next_event(user_id: str) -> str:
    """Get the user's next upcoming event."""
    try:
        if not await calendar_db_service.has_integration(user_id):
            return json.dumps({
                "error": "not_connected",
                "message": "Google Calendar is not connected."
            })
        
        event = await google_calendar_service.get_next_event(user_id)
        
        if not event:
            return json.dumps({
                "status": "success",
                "message": "No upcoming events found.",
                "event": None
            })
        
        return json.dumps({
            "status": "success",
            "message": f"Next event: {event['title']}",
            "event": event
        })
        
    except Exception as e:
        logger.error(f"get_next_event error: {e}")
        return json.dumps({"error": "api_error", "message": str(e)})


async def search_events(
    user_id: str,
    query: str,
    start_time: Optional[str] = None,
    end_time: Optional[str] = None
) -> str:
    """Search events by keyword."""
    try:
        if not await calendar_db_service.has_integration(user_id):
            return json.dumps({
                "error": "not_connected",
                "message": "Google Calendar is not connected."
            })
        
        if not query:
            return json.dumps({
                "error": "missing_query",
                "message": "Please provide a search query."
            })
        
        parsed_start = None
        parsed_end = None
        if start_time:
            parsed_start = datetime.fromisoformat(start_time.replace("Z", "+00:00"))
        if end_time:
            parsed_end = datetime.fromisoformat(end_time.replace("Z", "+00:00"))
        
        events = await google_calendar_service.search_events(
            user_id=user_id,
            query=query,
            start_time=parsed_start,
            end_time=parsed_end
        )
        
        return json.dumps({
            "status": "success",
            "query": query,
            "result_count": len(events),
            "events": events
        })
        
    except Exception as e:
        logger.error(f"search_events error: {e}")
        return json.dumps({"error": "api_error", "message": str(e)})


async def find_free_slots_tool(
    user_id: str,
    start_time: str,
    end_time: str,
    duration_minutes: int = 60,
    working_hours_start: int = 9,
    working_hours_end: int = 17
) -> str:
    """Find available time slots."""
    try:
        if not await calendar_db_service.has_integration(user_id):
            return json.dumps({
                "error": "not_connected",
                "message": "Google Calendar is not connected."
            })
        
        parsed_start = datetime.fromisoformat(start_time.replace("Z", "+00:00"))
        parsed_end = datetime.fromisoformat(end_time.replace("Z", "+00:00"))
        
        slots = await google_calendar_service.find_free_slots(
            user_id=user_id,
            start_time=parsed_start,
            end_time=parsed_end,
            duration_minutes=duration_minutes,
            working_hours_start=working_hours_start,
            working_hours_end=working_hours_end
        )
        
        if not slots:
            return json.dumps({
                "status": "success",
                "message": "No free slots found in the specified range.",
                "slots": []
            })
        
        return json.dumps({
            "status": "success",
            "message": f"Found {len(slots)} available time slot(s).",
            "duration_requested": duration_minutes,
            "slots": slots
        })
        
    except Exception as e:
        logger.error(f"find_free_slots error: {e}")
        return json.dumps({"error": "api_error", "message": str(e)})


# Phase 2-3 Implementation Functions

async def reschedule_event(
    user_id: str,
    event_id: str,
    new_start_time: str,
    new_end_time: Optional[str] = None,
    calendar_name: Optional[str] = None
) -> str:
    """Reschedule an event to a new time."""
    try:
        if not await calendar_db_service.has_integration(user_id):
            return json.dumps({"error": "not_connected", "message": "Calendar not connected."})
        
        if not event_id or not new_start_time:
            return json.dumps({"error": "missing_params", "message": "Event ID and new start time required."})
        
        # Resolve calendar_name to calendar_id
        calendar_id = None
        if calendar_name:
            calendars = await calendar_db_service.get_all_calendars(user_id)
            for cal in calendars:
                if calendar_name.lower() in cal["calendar_name"].lower():
                    calendar_id = cal["google_calendar_id"]
                    break
        
        parsed_start = datetime.fromisoformat(new_start_time.replace("Z", "+00:00"))
        parsed_end = None
        if new_end_time:
            parsed_end = datetime.fromisoformat(new_end_time.replace("Z", "+00:00"))
        
        updated = await google_calendar_service.update_event(
            user_id=user_id,
            event_id=event_id,
            calendar_id=calendar_id,
            start_time=parsed_start,
            end_time=parsed_end
        )
        
        return json.dumps({
            "status": "success",
            "message": f"Event rescheduled to {new_start_time}",
            "event": updated
        })
        
    except Exception as e:
        logger.error(f"reschedule_event error: {e}")
        return json.dumps({"error": "api_error", "message": str(e)})


async def find_conflicts(
    user_id: str,
    start_time: str,
    end_time: str
) -> str:
    """Find overlapping events (conflicts) in a time range."""
    try:
        if not await calendar_db_service.has_integration(user_id):
            return json.dumps({"error": "not_connected", "message": "Calendar not connected."})
        
        parsed_start = datetime.fromisoformat(start_time.replace("Z", "+00:00"))
        parsed_end = datetime.fromisoformat(end_time.replace("Z", "+00:00"))
        
        # Get all events in range
        events = await google_calendar_service.get_events(
            user_id=user_id,
            start_time=parsed_start,
            end_time=parsed_end
        )
        
        # Find overlaps
        conflicts = []
        for i, ev1 in enumerate(events):
            ev1_start = datetime.fromisoformat(ev1["start"].replace("Z", "+00:00")) if ev1.get("start") else None
            ev1_end = datetime.fromisoformat(ev1["end"].replace("Z", "+00:00")) if ev1.get("end") else None
            if not ev1_start or not ev1_end:
                continue
                
            for ev2 in events[i+1:]:
                ev2_start = datetime.fromisoformat(ev2["start"].replace("Z", "+00:00")) if ev2.get("start") else None
                ev2_end = datetime.fromisoformat(ev2["end"].replace("Z", "+00:00")) if ev2.get("end") else None
                if not ev2_start or not ev2_end:
                    continue
                
                # Check overlap
                if ev1_start < ev2_end and ev2_start < ev1_end:
                    conflicts.append({
                        "event1": {"id": ev1.get("id"), "title": ev1["title"], "start": ev1["start"], "end": ev1["end"]},
                        "event2": {"id": ev2.get("id"), "title": ev2["title"], "start": ev2["start"], "end": ev2["end"]}
                    })
        
        if not conflicts:
            return json.dumps({
                "status": "success",
                "message": "No scheduling conflicts found!",
                "conflicts": []
            })
        
        return json.dumps({
            "status": "success",
            "message": f"Found {len(conflicts)} conflict(s)",
            "conflicts": conflicts
        })
        
    except Exception as e:
        logger.error(f"find_conflicts error: {e}")
        return json.dumps({"error": "api_error", "message": str(e)})


async def get_daily_summary(
    user_id: str,
    date: Optional[str] = None
) -> str:
    """Get a human-readable summary of a day's schedule."""
    try:
        if not await calendar_db_service.has_integration(user_id):
            return json.dumps({"error": "not_connected", "message": "Calendar not connected."})
        
        # Parse date or use today
        if date:
            target_date = datetime.strptime(date, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        else:
            target_date = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
        
        day_start = target_date
        day_end = target_date + timedelta(days=1)
        
        events = await google_calendar_service.get_events(
            user_id=user_id,
            start_time=day_start,
            end_time=day_end
        )
        
        total_meeting_minutes = 0
        for ev in events:
            if ev.get("start") and ev.get("end"):
                try:
                    ev_start = datetime.fromisoformat(ev["start"].replace("Z", "+00:00"))
                    ev_end = datetime.fromisoformat(ev["end"].replace("Z", "+00:00"))
                    total_meeting_minutes += (ev_end - ev_start).total_seconds() / 60
                except:
                    pass
        
        summary = {
            "date": target_date.strftime("%Y-%m-%d"),
            "day_of_week": target_date.strftime("%A"),
            "event_count": len(events),
            "total_meeting_hours": round(total_meeting_minutes / 60, 1),
            "events": [{"title": e["title"], "start": e["start"], "end": e["end"]} for e in events[:10]]
        }
        
        if not events:
            summary["message"] = "Your day is completely free!"
        elif len(events) <= 3:
            summary["message"] = "A light day with just a few events."
        else:
            summary["message"] = f"A busy day with {len(events)} events totaling {summary['total_meeting_hours']} hours."
        
        return json.dumps({"status": "success", **summary})
        
    except Exception as e:
        logger.error(f"get_daily_summary error: {e}")
        return json.dumps({"error": "api_error", "message": str(e)})


async def block_focus_time(
    user_id: str,
    start_time: str,
    duration_minutes: int = 60,
    title: str = "Focus Time"
) -> str:
    """Block out focus/deep work time."""
    try:
        if not await calendar_db_service.has_integration(user_id):
            return json.dumps({"error": "not_connected", "message": "Calendar not connected."})
        
        parsed_start = datetime.fromisoformat(start_time.replace("Z", "+00:00"))
        parsed_end = parsed_start + timedelta(minutes=duration_minutes)
        
        created = await google_calendar_service.create_event(
            user_id=user_id,
            title=f"🎯 {title}",
            start_time=parsed_start,
            end_time=parsed_end,
            description="Focus time - do not disturb"
        )
        
        return json.dumps({
            "status": "success",
            "message": f"Blocked {duration_minutes} minutes for '{title}'",
            "event": created
        })
        
    except Exception as e:
        logger.error(f"block_focus_time error: {e}")
        return json.dumps({"error": "api_error", "message": str(e)})


async def cancel_events_in_range(
    user_id: str,
    start_time: str,
    end_time: str,
    title_filter: Optional[str] = None,
    confirm: bool = False
) -> str:
    """Cancel multiple events in a range (bulk delete)."""
    try:
        if not await calendar_db_service.has_integration(user_id):
            return json.dumps({"error": "not_connected", "message": "Calendar not connected."})
        
        if not confirm:
            return json.dumps({
                "status": "confirmation_required",
                "message": "This action will delete events. Please set confirm=true to proceed."
            })
        
        parsed_start = datetime.fromisoformat(start_time.replace("Z", "+00:00"))
        parsed_end = datetime.fromisoformat(end_time.replace("Z", "+00:00"))
        
        events = await google_calendar_service.get_events(
            user_id=user_id,
            start_time=parsed_start,
            end_time=parsed_end
        )
        
        # Filter by title if specified
        to_delete = []
        for ev in events:
            if title_filter:
                if title_filter.lower() in ev["title"].lower():
                    to_delete.append(ev)
            else:
                to_delete.append(ev)
        
        # Delete events
        deleted_count = 0
        for ev in to_delete:
            if ev.get("id"):
                try:
                    await google_calendar_service.delete_event(user_id, ev["id"])
                    deleted_count += 1
                except:
                    pass
        
        return json.dumps({
            "status": "success",
            "message": f"Cancelled {deleted_count} event(s)",
            "deleted_count": deleted_count
        })
        
    except Exception as e:
        logger.error(f"cancel_events_in_range error: {e}")
        return json.dumps({"error": "api_error", "message": str(e)})
