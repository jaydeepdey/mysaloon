import logging
from langgraph.graph import StateGraph, END
from langgraph.checkpoint.memory import MemorySaver

from app.graph.state import BookingState
from app.graph.nodes import (
    gemini_agent_node,
    create_pending_appointment_node,
    await_owner_decision_node,
    finalize_appointment_node,
    handle_edge_cases_node
)

logger = logging.getLogger("agent_service.workflow")

def route_after_gemini(state: BookingState) -> str:
    action_type = state.get("action_type", "chat")
    if action_type == "book" and state.get("selected_slot"):
        return "create_pending_appointment"
    return END

def build_booking_graph():
    builder = StateGraph(BookingState)

    builder.add_node("gemini_agent", gemini_agent_node)
    builder.add_node("create_pending_appointment", create_pending_appointment_node)
    builder.add_node("await_owner_decision", await_owner_decision_node)
    builder.add_node("finalize_appointment", finalize_appointment_node)
    builder.add_node("handle_edge_cases", handle_edge_cases_node)

    builder.set_entry_point("gemini_agent")

    builder.add_conditional_edges("gemini_agent", route_after_gemini, {
        "create_pending_appointment": "create_pending_appointment",
        END: END
    })

    builder.add_edge("create_pending_appointment", "await_owner_decision")
    builder.add_edge("await_owner_decision", "finalize_appointment")
    builder.add_edge("finalize_appointment", END)
    builder.add_edge("handle_edge_cases", END)

    checkpointer = MemorySaver()
    
    graph = builder.compile(
        checkpointer=checkpointer,
        interrupt_before=["await_owner_decision"]
    )
    return graph

booking_graph = build_booking_graph()
