import logging
import os
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict, Any

from app.models import (
    ChatRequest,
    ChatResponse,
    OwnerDecisionRequest,
    OwnerDecisionResponse
)
from app.graph.workflow import booking_graph
from app.database import (
    fetch_services,
    add_service,
    update_service,
    delete_service,
    fetch_7day_slots,
    toggle_slot_availability,
    reserve_slot_atomic,
    search_available_slots,
    update_appointment_status,
    cancel_appointment_record,
    clear_and_reset_database,
    DYNAMIC_APPOINTMENTS
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("agent_service")

app = FastAPI(
    title="Luxe Salon AI Booking Agent",
    description="LangGraph + LangChain + Gemini AI scheduling assistant service for Luxe Salon",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.exists(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")

class ServiceCreateRequest(BaseModel):
    name: str
    description: str
    duration_minutes: int = 60
    price: float

class ServiceUpdateRequest(BaseModel):
    name: str
    description: str
    duration_minutes: int = 60
    price: float
    is_active: bool = True

class SlotBookRequest(BaseModel):
    slot_id: str
    customer_id: str = "demo-customer-1"
    service_name: str = "Signature Haircut & Styling"

class SlotToggleRequest(BaseModel):
    slot_id: str
    is_booked: bool

class AppointmentCancelRequest(BaseModel):
    appointment_id: str
    reason: Optional[str] = "Cancelled by customer"

@app.get("/", response_class=HTMLResponse)
def index_route():
    return """
    <html>
      <head>
        <title>Luxe Aura Salon System</title>
        <style>
          body { font-family: sans-serif; background: #FDFBF7; color: #2D2A26; padding: 40px; text-align: center; }
          .card { background: white; max-width: 500px; margin: 0 auto; padding: 30px; border-radius: 16px; box-shadow: 0 10px 30px rgba(0,0,0,0.06); }
          a { display: block; margin: 16px 0; padding: 14px; background: #D97757; color: white; text-decoration: none; border-radius: 12px; font-weight: bold; }
          a.secondary { background: #E89A82; }
          a.docs { background: #421C11; }
        </style>
      </head>
      <body>
        <div class="card">
          <h2>✨ Luxe Aura Salon & Spa</h2>
          <p>AI Appointment Booking System (LangGraph + Gemini)</p>
          <a href="/customer">📱 Open Customer App</a>
          <a href="/owner" class="secondary">👑 Open Owner App</a>
          <a href="/docs" class="docs">⚡ FastAPI Interactive API Docs</a>
        </div>
      </body>
    </html>
    """

@app.api_route("/customer", methods=["GET", "HEAD"], response_class=HTMLResponse)
def get_customer_app():
    file_path = os.path.join(static_dir, "customer.html")
    if os.path.exists(file_path):
        return FileResponse(file_path)
    return HTMLResponse("<h1>Customer App file not found</h1>")

@app.api_route("/owner", methods=["GET", "HEAD"], response_class=HTMLResponse)
def get_owner_app():
    file_path = os.path.join(static_dir, "owner.html")
    if os.path.exists(file_path):
        return FileResponse(file_path)
    return HTMLResponse("<h1>Owner App file not found</h1>")

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "Luxe Salon AI Booking Agent", "version": "1.0.0"}

# ================= Dynamic Services Endpoints =================
@app.get("/services")
def get_services():
    services = fetch_services()
    return {"services": services}

@app.post("/services")
def create_new_service(req: ServiceCreateRequest):
    srv = add_service(req.name, req.description, req.duration_minutes, req.price)
    return {"status": "success", "service": srv}

@app.put("/services/{service_id}")
def edit_service(service_id: str, req: ServiceUpdateRequest):
    srv = update_service(service_id, req.name, req.description, req.duration_minutes, req.price, req.is_active)
    return {"status": "success", "service": srv}

@app.delete("/services/{service_id}")
def remove_service(service_id: str):
    delete_service(service_id)
    return {"status": "success", "message": f"Service {service_id} deleted."}

# ================= 7-Day Slot Availability & Owner Toggles =================
@app.get("/slots/7days")
def get_7day_slots(date: Optional[str] = None):
    slots = fetch_7day_slots(date)
    return {"slots": slots}

@app.post("/slots/toggle")
def toggle_slot_endpoint(req: SlotToggleRequest):
    try:
        slot = toggle_slot_availability(req.slot_id, req.is_booked)
        return {"status": "success", "slot": slot}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

@app.post("/slots/book")
def book_slot_endpoint(req: SlotBookRequest):
    try:
        res = reserve_slot_atomic(req.slot_id, req.customer_id, req.service_name)
        return {
            "status": "success",
            "message": f"Slot booked successfully! Pending owner approval.",
            "appointment": res["appointment"],
            "slot": res["slot"]
        }
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))

@app.get("/appointments")
def get_all_appointments():
    return {"appointments": list(DYNAMIC_APPOINTMENTS.values())}

@app.post("/appointments/cancel")
def cancel_appointment_endpoint(req: AppointmentCancelRequest):
    try:
        appt = cancel_appointment_record(req.appointment_id, req.reason)
        logger.info(f"Appointment {req.appointment_id} cancelled by customer. Slot released.")
        return {
            "status": "success",
            "message": "Appointment cancelled successfully. Salon owner has been notified and time slot has been released.",
            "appointment": appt
        }
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

@app.post("/appointments/{appointment_id}/cancel")
def cancel_appointment_by_id_endpoint(appointment_id: str, reason: Optional[str] = "Cancelled by customer"):
    try:
        appt = cancel_appointment_record(appointment_id, reason)
        logger.info(f"Appointment {appointment_id} cancelled by customer. Slot released.")
        return {
            "status": "success",
            "message": "Appointment cancelled successfully. Salon owner has been notified and time slot has been released.",
            "appointment": appt
        }
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

@app.post("/admin/reset")
def reset_database_endpoint():
    clear_and_reset_database()
    logger.info("Admin reset executed. Database reset to clean state.")
    return {"status": "success", "message": "All existing test data cleared! System database reset to clean state."}

# ================= AI Agent & Owner Decision Endpoints =================
@app.post("/chat", response_model=ChatResponse)
def chat_endpoint(req: ChatRequest):
    logger.info(f"Received chat request for thread {req.thread_id}: {req.message}")
    config = {"configurable": {"thread_id": req.thread_id}}
    
    current_state = booking_graph.get_state(config)
    state_values = current_state.values if current_state and current_state.values else {}
    
    state_values["thread_id"] = req.thread_id
    state_values["customer_id"] = req.customer_id
    state_values["user_input"] = req.message
    
    history = state_values.get("messages", [])
    history.append({"role": "customer", "content": req.message})
    state_values["messages"] = history

    if req.selected_slot_id:
        slots = state_values.get("candidate_slots", [])
        matched = next((s for s in slots if s.get("id") == req.selected_slot_id), None)
        if matched:
            state_values["selected_slot"] = matched

    result_state = booking_graph.invoke(state_values, config=config)
    
    response_text = result_state.get("agent_response", "Thank you! How else can I assist you with your appointment?")
    history.append({"role": "agent", "content": response_text})

    return ChatResponse(
        thread_id=req.thread_id,
        message=response_text,
        status=result_state.get("status", "conversing"),
        proposed_slots=result_state.get("candidate_slots", []),
        appointment_id=result_state.get("appointment_id")
    )

@app.post("/owner/decision", response_model=OwnerDecisionResponse)
def owner_decision_endpoint(req: OwnerDecisionRequest):
    logger.info(f"Received owner decision for thread {req.thread_id}, appt {req.appointment_id}: {req.decision}")
    
    status_str = "approved" if req.decision.lower() == "approved" else "rejected"
    
    # 1. ALWAYS mutate database & memory state directly first
    updated_appt = update_appointment_status(req.appointment_id, status_str, req.reason)
    
    # 2. Update LangGraph checkpointer state machine
    config = {"configurable": {"thread_id": req.thread_id}}
    current_state = booking_graph.get_state(config)
    if not current_state or not current_state.values:
        state_values = {
            "thread_id": req.thread_id,
            "appointment_id": req.appointment_id,
            "owner_decision": status_str,
            "rejection_reason": req.reason,
            "status": status_str
        }
    else:
        state_values = dict(current_state.values)
        state_values["owner_decision"] = status_str
        state_values["rejection_reason"] = req.reason
        state_values["appointment_id"] = req.appointment_id
        state_values["status"] = status_str

    try:
        result_state = booking_graph.invoke(state_values, config=config)
        agent_msg = result_state.get("agent_response", f"Appointment successfully {status_str}.")
    except Exception as e:
        logger.warning(f"Checkpointer resume notice: {e}")
        agent_msg = f"Appointment successfully {status_str}."

    return OwnerDecisionResponse(
        thread_id=req.thread_id,
        appointment_id=req.appointment_id,
        status=status_str,
        message=agent_msg
    )

if __name__ == "__main__":
    import uvicorn
    from app.config import settings
    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=True)
