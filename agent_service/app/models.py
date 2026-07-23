from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional

class ChatRequest(BaseModel):
    thread_id: str = Field(..., description="Unique conversation thread ID")
    customer_id: str = Field(default="demo-customer-1", description="Customer UUID")
    message: str = Field(..., description="Natural language customer request")
    selected_slot_id: Optional[str] = Field(default=None, description="Optional slot ID if user selected a suggested slot")

class ProposedSlot(BaseModel):
    id: str
    staff_id: str
    staff_name: str
    date: str
    start_time: str
    end_time: str

class ChatResponse(BaseModel):
    thread_id: str
    message: str
    status: str
    proposed_slots: List[Dict[str, Any]] = []
    appointment_id: Optional[str] = None

class OwnerDecisionRequest(BaseModel):
    thread_id: Optional[str] = Field(default="thread-demo-1", description="Unique conversation thread ID")
    appointment_id: str
    decision: str = Field(..., description="'approved' or 'rejected'")
    reason: Optional[str] = Field(default=None, description="Optional rejection reason")

class OwnerDecisionResponse(BaseModel):
    thread_id: str
    appointment_id: str
    status: str
    message: str
