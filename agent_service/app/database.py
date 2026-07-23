import os
import json
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime, date, timedelta
from app.config import settings

logger = logging.getLogger("agent_service.database")

# Initialize Supabase Client
supabase = None
if settings.SUPABASE_URL and settings.SUPABASE_SERVICE_ROLE_KEY and not settings.SUPABASE_URL.startswith("https://demo"):
    try:
        from supabase import create_client
        supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)
        logger.info(f"⚡ Supabase Client initialized and connected to {settings.SUPABASE_URL}")
    except Exception as e:
        logger.warning(f"Could not initialize Supabase Client: {e}")

DB_FILE_PATH = os.path.join(os.path.dirname(__file__), "..", "salon_db.json")

def generate_7day_slots() -> List[Dict[str, Any]]:
    today = date.today()
    slots = []
    hours = ["09:00", "10:00", "11:00", "12:00", "14:00", "15:00", "16:00", "17:00"]
    staff_list = [
        {"id": "a1111111-1111-1111-1111-111111111111", "name": "Elena Rostova"},
        {"id": "a2222222-2222-2222-2222-222222222222", "name": "Marcus Vance"},
        {"id": "a3333333-3333-3333-3333-333333333333", "name": "Chloe Bennett"}
    ]
    
    for day_offset in range(7):
        target_date = today + timedelta(days=day_offset)
        date_str = target_date.isoformat()
        
        for h in hours:
            start_h = int(h.split(":")[0])
            end_h = start_h + 1
            end_time = f"{end_h:02d}:00:00"
            start_time = f"{h}:00"
            staff = staff_list[day_offset % len(staff_list)]
            
            slot_id = f"slot-{date_str}-{start_h:02d}"
            slots.append({
                "id": slot_id,
                "date": date_str,
                "start_time": start_time,
                "end_time": end_time,
                "staff_id": staff["id"],
                "staff_name": staff["name"],
                "is_booked": False
            })
    return slots

DEFAULT_SERVICES = [
    {
        "id": "11111111-1111-1111-1111-111111111111",
        "name": "Signature Haircut & Styling",
        "description": "Precision haircut, wash, scalp massage, and professional blow-dry styling.",
        "duration_minutes": 60,
        "price": 65.0,
        "category": "Hair",
        "is_popular": True
    },
    {
        "id": "22222222-2222-2222-2222-222222222222",
        "name": "Full Hair Coloring & Gloss",
        "description": "Custom color treatment with premium organic pigments and shine-enhancing gloss.",
        "duration_minutes": 60,
        "price": 120.0,
        "category": "Hair",
        "is_popular": True
    },
    {
        "id": "33333333-3333-3333-3333-333333333333",
        "name": "Hydrating Facial Spa",
        "description": "Deep cleansing, gentle exfoliation, hydrating botanical mask, and facial massage.",
        "duration_minutes": 60,
        "price": 85.0,
        "category": "Facial",
        "is_popular": True
    },
    {
        "id": "44444444-4444-4444-4444-444444444444",
        "name": "Gel Manicure & Hand Care",
        "description": "Long-lasting gel polish, nail shaping, cuticle treatment, and hand massage.",
        "duration_minutes": 60,
        "price": 45.0,
        "category": "Nails",
        "is_popular": False
    }
]

DYNAMIC_SERVICES: List[Dict[str, Any]] = list(DEFAULT_SERVICES)
DYNAMIC_SLOTS: List[Dict[str, Any]] = generate_7day_slots()
DYNAMIC_APPOINTMENTS: Dict[str, Dict[str, Any]] = {}

def save_db_to_disk():
    try:
        data = {
            "services": DYNAMIC_SERVICES,
            "slots": DYNAMIC_SLOTS,
            "appointments": DYNAMIC_APPOINTMENTS
        }
        with open(DB_FILE_PATH, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        logger.warning(f"Failed to save DB to disk: {e}")

def load_db_from_disk():
    global DYNAMIC_SERVICES, DYNAMIC_SLOTS, DYNAMIC_APPOINTMENTS
    if os.path.exists(DB_FILE_PATH):
        try:
            with open(DB_FILE_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                if "services" in data and len(data["services"]) > 0:
                    DYNAMIC_SERVICES = data["services"]
                if "slots" in data and len(data["slots"]) > 0:
                    DYNAMIC_SLOTS = data["slots"]
                if "appointments" in data:
                    DYNAMIC_APPOINTMENTS = data["appointments"]
            logger.info("Persistent database loaded from salon_db.json")
        except Exception as e:
            logger.warning(f"Failed to load DB from disk: {e}")

def clear_and_reset_database():
    global DYNAMIC_SERVICES, DYNAMIC_SLOTS, DYNAMIC_APPOINTMENTS
    logger.info("Cleaning all existing data and resetting to clean state...")
    
    DYNAMIC_SERVICES = list(DEFAULT_SERVICES)
    DYNAMIC_SLOTS = generate_7day_slots()
    DYNAMIC_APPOINTMENTS.clear()
    
    save_db_to_disk()

    if supabase:
        try:
            supabase.table("appointments").delete().neq("id", "none").execute()
            supabase.table("services").delete().neq("id", "none").execute()
            for s in DYNAMIC_SERVICES:
                supabase.table("services").insert(s).execute()
        except Exception as e:
            logger.debug(f"Supabase reset notice: {e}")

# Perform clean reset of existing test data
clear_and_reset_database()

def fetch_services() -> List[Dict[str, Any]]:
    if supabase:
        try:
            res = supabase.table("services").select("*").execute()
            if res.data and len(res.data) > 0:
                return res.data
        except Exception as e:
            logger.debug(f"Supabase services read notice: {e}")
    return DYNAMIC_SERVICES

def add_service(name: str, description: str, price: float, duration_minutes: int = 60, category: str = "General", is_popular: bool = True) -> Dict[str, Any]:
    import uuid
    new_id = str(uuid.uuid4())
    new_service = {
        "id": new_id,
        "name": name,
        "description": description,
        "price": price,
        "duration_minutes": duration_minutes,
        "category": category,
        "is_popular": is_popular
    }
    
    if supabase:
        try:
            supabase.table("services").insert(new_service).execute()
        except Exception as e:
            logger.debug(f"Supabase service insert notice: {e}")
            
    DYNAMIC_SERVICES.append(new_service)
    save_db_to_disk()
    return new_service

def update_service(service_id: str, name: str, description: str, price: float) -> Dict[str, Any]:
    if supabase:
        try:
            supabase.table("services").update({"name": name, "description": description, "price": price}).eq("id", service_id).execute()
        except Exception as e:
            logger.debug(f"Supabase service update notice: {e}")

    for s in DYNAMIC_SERVICES:
        if s["id"] == service_id:
            s["name"] = name
            s["description"] = description
            s["price"] = price
            save_db_to_disk()
            return s
    raise ValueError(f"Service {service_id} not found")

def delete_service(service_id: str) -> bool:
    global DYNAMIC_SERVICES
    if supabase:
        try:
            supabase.table("services").delete().eq("id", service_id).execute()
        except Exception as e:
            logger.debug(f"Supabase service delete notice: {e}")

    DYNAMIC_SERVICES = [s for s in DYNAMIC_SERVICES if s["id"] != service_id]
    save_db_to_disk()
    return True

def get_7day_slots(target_date: Optional[str] = None) -> List[Dict[str, Any]]:
    if supabase:
        try:
            query = supabase.table("slots").select("*")
            if target_date:
                query = query.eq("date", target_date)
            res = query.execute()
            if res.data and len(res.data) > 0:
                return res.data
        except Exception as e:
            logger.debug(f"Supabase slots read notice: {e}")

    if target_date:
        return [s for s in DYNAMIC_SLOTS if s["date"] == target_date]
    return DYNAMIC_SLOTS

fetch_7day_slots = get_7day_slots

def toggle_slot_availability(slot_id: str, is_booked: bool) -> Dict[str, Any]:
    if supabase:
        try:
            supabase.table("slots").update({"is_booked": is_booked}).eq("id", slot_id).execute()
        except Exception as e:
            logger.debug(f"Supabase slot toggle notice: {e}")

    for s in DYNAMIC_SLOTS:
        if s["id"] == slot_id:
            s["is_booked"] = is_booked
            save_db_to_disk()
            return s
    raise ValueError(f"Slot {slot_id} not found")

def search_available_slots(service_name: Optional[str] = None, target_date: Optional[str] = None) -> List[Dict[str, Any]]:
    slots = get_7day_slots(target_date)
    return [s for s in slots if not s.get("is_booked")]

def reserve_slot_atomic(slot_id: str, customer_id: str, service_name: str) -> Dict[str, Any]:
    matched_slot = None
    for s in DYNAMIC_SLOTS:
        if s["id"] == slot_id:
            matched_slot = s
            break

    if not matched_slot:
        for s in DYNAMIC_SLOTS:
            if not s["is_booked"]:
                matched_slot = s
                break

    if not matched_slot or matched_slot.get("is_booked"):
        raise ValueError("Your slot is already full - try other slot")

    matched_slot["is_booked"] = True
    toggle_slot_availability(matched_slot["id"], True)
    
    appt_id = f"appt-{int(datetime.now().timestamp())}"
    start_iso = f"{matched_slot['date']}T{matched_slot['start_time']}"
    end_iso = f"{matched_slot['date']}T{matched_slot['end_time']}"
    
    appt = {
        "id": appt_id,
        "customer_id": customer_id or "demo-customer-id",
        "customer_name": "Customer",
        "service_name": service_name or "Signature Haircut & Styling",
        "staff_name": matched_slot.get("staff_name", "Elena Rostova"),
        "requested_start_time": start_iso,
        "requested_end_time": end_iso,
        "status": "pending",
        "notes": f"Booked 1-hour slot for {service_name}",
        "created_at": datetime.now().isoformat()
    }
    
    if supabase:
        try:
            supabase.table("appointments").insert(appt).execute()
        except Exception as e:
            logger.debug(f"Supabase appointment insert notice: {e}")

    DYNAMIC_APPOINTMENTS[appt_id] = appt
    save_db_to_disk()
    return {"appointment": appt, "slot": matched_slot}

def create_pending_appointment_record(customer_id: str, service_id: str, staff_id: str, start_iso: str, end_iso: str, notes: str = "") -> Dict[str, Any]:
    appt_id = f"appt-{int(datetime.now().timestamp())}"
    appt = {
        "id": appt_id,
        "customer_id": customer_id or "demo-customer-id",
        "service_id": service_id or DYNAMIC_SERVICES[0]["id"],
        "service_name": notes or DYNAMIC_SERVICES[0]["name"],
        "staff_id": staff_id or "a1111111-1111-1111-1111-111111111111",
        "staff_name": "Elena Rostova",
        "requested_start_time": start_iso,
        "requested_end_time": end_iso,
        "status": "pending",
        "notes": notes,
        "created_at": datetime.now().isoformat()
    }

    if supabase:
        try:
            supabase.table("appointments").insert(appt).execute()
        except Exception as e:
            logger.debug(f"Supabase appointment insert notice: {e}")

    DYNAMIC_APPOINTMENTS[appt_id] = appt

    # Lock matching slot in DYNAMIC_SLOTS & Supabase
    if "T" in start_iso:
        slot_date, slot_time = start_iso.split("T")
        for s in DYNAMIC_SLOTS:
            if s["date"] == slot_date and s["start_time"] == slot_time:
                s["is_booked"] = True
                toggle_slot_availability(s["id"], True)
                break

    save_db_to_disk()
    return appt

def update_appointment_status(appointment_id: str, status: str, reason: Optional[str] = None) -> Dict[str, Any]:
    if supabase:
        try:
            supabase.table("appointments").update({"status": status, "notes": reason}).eq("id", appointment_id).execute()
        except Exception as e:
            logger.debug(f"Supabase appointment update notice: {e}")

    if appointment_id in DYNAMIC_APPOINTMENTS:
        appt = DYNAMIC_APPOINTMENTS[appointment_id]
        appt["status"] = status
        if reason:
            appt["notes"] = reason
            
        start_iso = appt.get("requested_start_time", "")
        if "T" in start_iso:
            slot_date, slot_time = start_iso.split("T")
            for s in DYNAMIC_SLOTS:
                if s["date"] == slot_date and s["start_time"] == slot_time:
                    is_full = status not in ["rejected", "cancelled"]
                    s["is_booked"] = is_full
                    toggle_slot_availability(s["id"], is_full)
                    break
        save_db_to_disk()
        return appt
    return {"id": appointment_id, "status": status, "notes": reason or ""}

def cancel_appointment_record(appointment_id: str, reason: Optional[str] = None) -> Dict[str, Any]:
    if appointment_id not in DYNAMIC_APPOINTMENTS:
        raise ValueError(f"Appointment {appointment_id} not found")
    return update_appointment_status(appointment_id, "cancelled", reason or "Cancelled by customer")
