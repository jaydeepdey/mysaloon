import logging
import re
from typing import List, Dict, Any, Optional
from datetime import datetime, date, timedelta
from app.database import (
    fetch_services,
    search_available_slots,
    create_pending_appointment_record,
    update_appointment_status,
    DYNAMIC_SLOTS
)

logger = logging.getLogger("agent_service.tools")

MONTH_MAP = {
    "jan": 1, "january": 1,
    "feb": 2, "february": 2,
    "mar": 3, "march": 3,
    "apr": 4, "april": 4,
    "may": 5,
    "jun": 6, "june": 6,
    "jul": 7, "july": 7,
    "aug": 8, "august": 8,
    "sep": 9, "september": 9,
    "oct": 10, "october": 10,
    "nov": 11, "november": 11,
    "dec": 12, "december": 12
}

def parse_date_and_time_from_text(text: str) -> Dict[str, Optional[str]]:
    text_lower = text.lower()
    today = date.today()
    target_date = None
    target_time = None
    time_pref = None

    if "afternoon" in text_lower or "pm" in text_lower or "evening" in text_lower:
        time_pref = "afternoon"
    elif "morning" in text_lower or "am" in text_lower:
        time_pref = "morning"

    # Match explicit date e.g. "26th July", "July 26", "26 July"
    date_match = re.search(r'(\d{1,2})(?:st|nd|rd|th)?\s+(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)', text_lower)
    if not date_match:
        date_match = re.search(r'(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)\s+(\d{1,2})(?:st|nd|rd|th)?', text_lower)

    if date_match:
        groups = date_match.groups()
        if groups[0].isdigit():
            day_num = int(groups[0])
            month_str = groups[1]
        else:
            month_str = groups[0]
            day_num = int(groups[1])
        
        month_num = MONTH_MAP.get(month_str, today.month)
        year = today.year
        if month_num < today.month or (month_num == today.month and day_num < today.day):
            year += 1
        try:
            target_date = date(year, month_num, day_num).isoformat()
        except ValueError:
            target_date = None

    # Fallbacks: today, tomorrow, day of week
    if not target_date:
        if "today" in text_lower:
            target_date = today.isoformat()
        elif "tomorrow" in text_lower:
            target_date = (today + timedelta(days=1)).isoformat()
        else:
            weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
            for idx, w in enumerate(weekdays):
                if w in text_lower:
                    d = today
                    while d.weekday() != idx:
                        d += timedelta(days=1)
                    target_date = d.isoformat()
                    break

    # Match specific hour e.g. "3:00 pm", "3 pm", "15:00"
    time_match = re.search(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)', text_lower)
    if not time_match:
        time_match = re.search(r'(\d{1,2}):(\d{2})', text_lower)

    if time_match:
        hour = int(time_match.group(1))
        minute = int(time_match.group(2)) if (time_match.lastindex >= 2 and time_match.group(2)) else 0
        ampm = time_match.group(3) if time_match.lastindex >= 3 else None

        if ampm == "pm" and hour < 12:
            hour += 12
        elif ampm == "am" and hour == 12:
            hour = 0
            
        if 0 <= hour <= 23:
            target_time = f"{hour:02d}:{minute:02d}:00"

    return {"target_date": target_date, "target_time": target_time, "time_preference": time_pref}

def tool_parse_intent_fallback(user_text: str) -> Dict[str, Any]:
    text_lower = user_text.lower()
    
    service_name = "Signature Haircut & Styling"
    if "color" in text_lower or "dye" in text_lower:
        service_name = "Full Hair Coloring & Gloss"
    elif "facial" in text_lower or "skin" in text_lower or "spa" in text_lower:
        service_name = "Hydrating Facial Spa"
    elif "manicure" in text_lower or "nail" in text_lower or "hand" in text_lower:
        service_name = "Gel Manicure & Hand Care"

    dt_info = parse_date_and_time_from_text(user_text)

    return {
        "service_name": service_name,
        "target_date": dt_info["target_date"],
        "target_time": dt_info["target_time"],
        "time_preference": dt_info["time_preference"],
        "special_requests": user_text
    }

def tool_find_matching_slots(service_name: str, target_date: Optional[str] = None, target_time: Optional[str] = None, time_pref: Optional[str] = None) -> List[Dict[str, Any]]:
    all_slots = DYNAMIC_SLOTS
    matching = []
    
    for s in all_slots:
        if target_date and s["date"] != target_date:
            continue

        start_hour = int(s["start_time"].split(":")[0])
        
        # Filter by time preference
        if time_pref == "afternoon" and start_hour < 12:
            continue
        if time_pref == "morning" and start_hour >= 12:
            continue

        if target_time:
            t_hour = int(target_time.split(":")[0])
            if start_hour != t_hour:
                continue
                
        matching.append(s)

    # Fallback for date matching with preference
    if not matching and target_date:
        for s in all_slots:
            if s["date"] == target_date:
                start_hour = int(s["start_time"].split(":")[0])
                if time_pref == "afternoon" and start_hour < 12:
                    continue
                if time_pref == "morning" and start_hour >= 12:
                    continue
                matching.append(s)

    return matching

def tool_create_pending_appointment(customer_id: str, slot: Dict[str, Any], notes: str) -> Dict[str, Any]:
    target_date = slot.get("date", date.today().isoformat())
    start_time = slot.get("start_time", "10:00:00")
    end_time = slot.get("end_time", "10:45:00")
    
    start_iso = f"{target_date}T{start_time}"
    end_iso = f"{target_date}T{end_time}"
    
    return create_pending_appointment_record(
        customer_id=customer_id,
        service_id=slot.get("service_id", "11111111-1111-1111-1111-111111111111"),
        staff_id=slot.get("staff_id", "a1111111-1111-1111-1111-111111111111"),
        start_iso=start_iso,
        end_iso=end_iso,
        notes=notes
    )

def tool_finalize_appointment(appointment_id: str, decision: str, reason: Optional[str] = None) -> Dict[str, Any]:
    status = "approved" if decision == "approved" else "rejected"
    return update_appointment_status(appointment_id, status, reason)
