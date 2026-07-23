import unittest
from app.graph.nodes import gemini_agent_node, create_pending_appointment_node

class TestGeminiConversationalAgent(unittest.TestCase):
    def test_general_greeting(self):
        state = {"user_input": "Hello, How are you ?"}
        res = gemini_agent_node(state)
        self.assertEqual(res["action_type"], "chat")
        self.assertIn("Hello", res["agent_response"])

    def test_check_availability_inquiry_does_not_auto_book(self):
        state = {"user_input": "Do you have any available slots for tomorrow afternoon?"}
        res = gemini_agent_node(state)
        self.assertEqual(res["action_type"], "chat") # Must be chat, NOT auto-book!
        self.assertIn("slots", res["agent_response"].lower())

    def test_explicit_booking_request(self):
        state = {
            "user_input": "Please book slot-2026-07-26-15 for me",
            "selected_slot": {
                "id": "slot-2026-07-26-15",
                "date": "2026-07-26",
                "start_time": "15:00:00",
                "staff_name": "Elena Rostova"
            }
        }
        res = gemini_agent_node(state)
        self.assertEqual(res["action_type"], "book")

if __name__ == "__main__":
    unittest.main()
