import unittest
from app.database import (
    fetch_services,
    search_available_slots,
    create_pending_appointment_record,
    update_appointment_status
)

class TestDatabaseQueries(unittest.TestCase):
    def test_fetch_services(self):
        services = fetch_services()
        self.assertIsInstance(services, list)
        self.assertGreaterEqual(len(services), 1)
        self.assertIn("name", services[0])

    def test_search_available_slots(self):
        slots = search_available_slots("Signature Haircut & Styling")
        self.assertIsInstance(slots, list)
        self.assertGreater(len(slots), 0)

    def test_create_and_update_appointment(self):
        appt = create_pending_appointment_record(
            customer_id="cust-test",
            service_id="11111111-1111-1111-1111-111111111111",
            staff_id="a1111111-1111-1111-1111-111111111111",
            start_iso="2026-07-24T10:00:00",
            end_iso="2026-07-24T10:45:00",
            notes="Unit test appointment"
        )
        self.assertTrue(appt["id"].startswith("appt-"))
        self.assertEqual(appt["status"], "pending")

        updated = update_appointment_status(appt["id"], "approved")
        self.assertEqual(updated["status"], "approved")

if __name__ == "__main__":
    unittest.main()
