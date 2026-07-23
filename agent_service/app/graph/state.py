from typing import TypedDict, List, Dict, Any, Optional

class BookingState(TypedDict, total=False):
    thread_id: str
    customer_id: str
    messages: List[Dict[str, str]]
    user_input: str
    extracted_intent: Dict[str, Any]
    candidate_slots: List[Dict[str, Any]]
    selected_slot: Optional[Dict[str, Any]]
    appointment_id: Optional[str]
    owner_decision: Optional[str] # "approved", "rejected", "none"
    rejection_reason: Optional[str]
    status: str # "conversing", "slots_proposed", "pending_owner_approval", "approved", "rejected", "escalated"
    agent_response: str
