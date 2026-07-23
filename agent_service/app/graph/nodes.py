import logging
import json
import httpx
from typing import Dict, Any, Optional
from datetime import date
from app.graph.state import BookingState
from app.graph.tools import (
    tool_find_matching_slots,
    tool_create_pending_appointment,
    tool_finalize_appointment,
    parse_date_and_time_from_text
)
from app.database import fetch_services, DYNAMIC_SLOTS, DYNAMIC_APPOINTMENTS, create_pending_appointment_record, cancel_appointment_record
from app.config import settings

logger = logging.getLogger("agent_service.nodes")

SALON_CONTEXT = """
You are Luxe Aura Salon & Spa's intelligent AI Assistant, powered by Google Gemini.
Salon Details:
- Name: Luxe Aura Salon & Spa
- Location: 123 Beauty Boulevard, Suite 100
- Services & Prices:
  1. Signature Haircut & Styling ($65.00, 60 mins)
  2. Full Hair Coloring & Gloss ($120.00, 60 mins)
  3. Hydrating Facial Spa ($85.00, 60 mins)
  4. Gel Manicure & Hand Care ($45.00, 60 mins)
- Specialists: Elena Rostova (Hair), Marcus Vance (Skincare), Chloe Bennett (Nails)
- Working Hours: Mon-Sat 09:00 AM - 05:00 PM

Guidelines:
1. Answer ANY user question warmly and conversationally as a luxury salon AI host.
2. If asked to check slots, present open slots clearly.
3. If user asks to book/reserve a slot, indicate clearly that the request is being submitted for owner approval.
4. If user asks to cancel an appointment, confirm that the appointment is being cancelled and the time slot is released.
"""

def call_gemini_api_directly(prompt_text: str, api_key: str) -> Optional[str]:
    models = ["gemini-2.5-flash", "gemini-3.5-flash", "gemini-3.5-flash-lite", "gemini-2.0-flash"]
    for model_name in models:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent?key={api_key}"
        payload = {"contents": [{"parts": [{"text": prompt_text}]}]}
        try:
            with httpx.Client(timeout=10.0) as client:
                resp = client.post(url, json=payload)
                if resp.status_code == 200:
                    res_json = resp.json()
                    candidates = res_json.get("candidates", [])
                    if candidates:
                        parts = candidates[0].get("content", {}).get("parts", [])
                        if parts:
                            return parts[0].get("text", "")
        except Exception as e:
            logger.warning(f"Direct Gemini REST API call attempt for {model_name} failed: {e}")
    return None

def gemini_agent_node(state: BookingState) -> Dict[str, Any]:
    user_text = state.get("user_input", "").strip()
    customer_id = state.get("customer_id", "cust-1")
    today_str = date.today().isoformat()
    
    dt_info = parse_date_and_time_from_text(user_text)
    target_date = dt_info["target_date"] or today_str
    target_time = dt_info["target_time"]
    time_pref = dt_info["time_preference"]

    matching_slots = tool_find_matching_slots("all", target_date, target_time, time_pref)
    unbooked_slots = [s for s in matching_slots if not s.get("is_booked")]
    
    slots_summary = []
    for s in unbooked_slots[:5]:
        slots_summary.append(f"Date: {s['date']}, Time: {s['start_time'][:5]}, Specialist: {s['staff_name']}, SlotID: {s['id']}")
    
    slots_context_str = "\n".join(slots_summary) if slots_summary else "No unbooked slots available for that date/time."

    user_lower = user_text.lower()
    cancel_triggers = ["cancel", "cancellation", "drop appointment", "remove booking", "cancel booking", "cancel my", "dont want appointment", "cancel appt"]
    is_explicit_cancel_request = any(kw in user_lower for kw in cancel_triggers)

    booking_confirmation_triggers = [
        "book", "reserve", "confirm", "go ahead", "yes", "schedule", "lock", "take it", "please book", "book slot"
    ]
    
    is_explicit_book_request = not is_explicit_cancel_request and (any(kw in user_lower for kw in booking_confirmation_triggers) or state.get("selected_slot") is not None)

    agent_response = ""
    action_type = "chat"
    selected_slot_to_book = None
    created_appt_id = None

    if settings.GEMINI_API_KEY and not settings.GEMINI_API_KEY.startswith("demo"):
        prompt = f"""{SALON_CONTEXT}

Today's Date: {today_str}
Current Real-Time Available Slots:
{slots_context_str}

User Question: "{user_text}"
Is user explicitly asking to CANCEL an appointment? {"YES" if is_explicit_cancel_request else "NO"}
Is user explicitly asking to finalize/confirm a booking? {"YES" if is_explicit_book_request else "NO"}

Respond naturally as Gemini. Return valid JSON only:
{{
  "response": "Your complete conversational response to the user's question",
  "should_cancel": boolean,
  "should_book": boolean,
  "slot_id_to_book": string or null
}}
"""
        raw_text = call_gemini_api_directly(prompt, settings.GEMINI_API_KEY)
        if raw_text:
            try:
                clean_json_str = raw_text.strip()
                if clean_json_str.startswith("```"):
                    clean_json_str = clean_json_str.split("\n", 1)[1].rsplit("```", 1)[0].strip()
                data = json.loads(clean_json_str)
                agent_response = data.get("response", "")
                if data.get("should_cancel"):
                    is_explicit_cancel_request = True
                elif data.get("should_book"):
                    is_explicit_book_request = True
                    slot_id = data.get("slot_id_to_book")
                    if unbooked_slots:
                        selected_slot_to_book = next((s for s in unbooked_slots if s["id"] == slot_id), unbooked_slots[0])
            except Exception as parse_err:
                logger.warning(f"Error parsing Gemini response: {parse_err}")

    # If user requests cancellation, execute DB cancellation & release slot
    if is_explicit_cancel_request:
        action_type = "cancel"
        active_appts = [
            a for a in DYNAMIC_APPOINTMENTS.values()
            if a.get("status") in ["pending", "approved"]
        ]
        
        if active_appts:
            target_appt = None
            if dt_info["target_date"]:
                target_appt = next((a for a in active_appts if a.get("requested_start_time", "").startswith(dt_info["target_date"])), None)
            if not target_appt:
                target_appt = active_appts[-1]
                
            cancelled_record = cancel_appointment_record(target_appt["id"], f"Cancelled via AI Chat Assistant ({user_text})")
            created_appt_id = target_appt["id"]
            
            start_iso = target_appt.get("requested_start_time", "")
            start_date = start_iso.split("T")[0] if "T" in start_iso else start_iso
            start_time = start_iso.split("T")[1][:5] if "T" in start_iso else ""
            
            agent_response = (
                f"🚫 Your appointment for {target_appt.get('service_name', 'Salon Service')} on {start_date} "
                f"{('at ' + start_time) if start_time else ''} has been cancelled successfully. "
                f"The salon owner has been notified and the time slot is now available again for booking!"
            )
        else:
            agent_response = "I checked our records, but couldn't find any active or pending appointment to cancel for you."

    # If the user is asking to book, GUARANTEE database creation
    elif is_explicit_book_request and unbooked_slots:
        action_type = "book"
        if not selected_slot_to_book:
            selected_slot_to_book = unbooked_slots[0]
            
        # Create record directly in DYNAMIC_APPOINTMENTS database
        appt_record = tool_create_pending_appointment(customer_id, selected_slot_to_book, f"Booked via AI Assistant ({user_text})")
        created_appt_id = appt_record.get("id")
        
        agent_response = (
            f"🎉 Your appointment request for {selected_slot_to_book['date']} at {selected_slot_to_book['start_time'][:5]} "
            f"with {selected_slot_to_book['staff_name']} has been submitted! We have notified the salon owner for approval."
        )

    if not agent_response:
        if any(w in user_lower for w in ["slot", "available", "open", "timing", "july"]):
            time_lbl = f" {time_pref}" if time_pref else ""
            if unbooked_slots:
                formatted = [f"• {s['date']} @ {s['start_time'][:5]} ({s['staff_name']})" for s in unbooked_slots[:3]]
                agent_response = f"Here are available{time_lbl} slots for {target_date}:\n" + "\n".join(formatted) + "\n\nWould you like me to book any of these for you?"
            else:
                agent_response = f"I checked our calendar for {target_date}, but no open{time_lbl} slots were found."
        elif any(w in user_lower for w in ["hi", "hello", "hey", "how are you", "how's it going"]):
            agent_response = "Hello! 👋 I am doing great, thank you! I'm your Gemini AI assistant. How can I help you today?"
        elif any(w in user_lower for w in ["price", "cost", "service", "menu", "what do you offer"]):
            agent_response = "We offer Haircuts ($65), Hair Coloring ($120), Hydrating Facials ($85), and Gel Manicures ($45). What service are you interested in?"
        else:
            agent_response = f"Hello! As Luxe Aura Salon's Gemini AI Assistant, I can assist you with salon services, pricing, appointments, and answering your questions about '{user_text}'. How can I help you today?"

    return {
        "agent_response": agent_response,
        "action_type": action_type,
        "selected_slot": selected_slot_to_book if action_type == "book" else None,
        "appointment_id": created_appt_id,
        "candidate_slots": unbooked_slots,
        "status": "pending_owner_approval" if action_type == "book" else "conversing"
    }

def create_pending_appointment_node(state: BookingState) -> Dict[str, Any]:
    selected_slot = state.get("selected_slot")
    customer_id = state.get("customer_id", "demo-customer-1")
    intent = state.get("extracted_intent", {})
    notes = intent.get("special_requests", "Booked via Gemini AI Assistant")
    
    if not selected_slot and state.get("candidate_slots"):
        selected_slot = state["candidate_slots"][0]
        
    if not selected_slot:
        return {
            "agent_response": "That slot is no longer available. Please select another slot.",
            "status": "conversing"
        }
        
    appt = tool_create_pending_appointment(customer_id, selected_slot, notes)
    message = (
        f"Your appointment request for {selected_slot.get('date')} at {selected_slot.get('start_time')[:5]} "
        f"has been submitted! We have notified the salon owner for approval."
    )
    
    return {
        "selected_slot": selected_slot,
        "appointment_id": appt.get("id"),
        "agent_response": message,
        "status": "pending_owner_approval"
    }

def await_owner_decision_node(state: BookingState) -> Dict[str, Any]:
    return {"status": "pending_owner_approval"}

def finalize_appointment_node(state: BookingState) -> Dict[str, Any]:
    appt_id = state.get("appointment_id")
    decision = state.get("owner_decision", "none")
    reason = state.get("rejection_reason", "")
    
    if appt_id and decision in ["approved", "rejected"]:
        tool_finalize_appointment(appt_id, decision, reason)
        
    if decision == "approved":
        msg = "🎉 Great news! The salon owner has APPROVED your appointment request. See you soon at Luxe Aura Salon!"
        final_status = "approved"
    elif decision == "rejected":
        msg = f"The salon owner was unable to confirm your request." + (f" Note: {reason}" if reason else "") + " Would you like to check alternative available times?"
        final_status = "rejected"
    else:
        msg = "Your appointment is currently awaiting salon owner review."
        final_status = "pending_owner_approval"
        
    return {
        "agent_response": msg,
        "status": final_status
    }

def handle_edge_cases_node(state: BookingState) -> Dict[str, Any]:
    return {
        "agent_response": "I am here to assist with any questions about Luxe Aura Salon or help you check available appointment slots!",
        "status": "conversing"
    }
