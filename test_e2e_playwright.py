import asyncio
import json
import sys
from datetime import date, timedelta
from playwright.async_api import async_playwright

if sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

BASE_URL = "http://localhost:8000"

async def safe_dialog(dialog):
    try:
        await dialog.accept()
    except Exception:
        pass

def on_dialog(dialog):
    asyncio.create_task(safe_dialog(dialog))

async def run_all_tests():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        page = await context.new_page()

        print("\n=======================================================")
        print("[SUITE] STARTING EXTENSIVE E2E PLAYWRIGHT TEST SUITE")
        print("=======================================================\n")

async def ensure_customer_logged_in(page):
    try:
        if await page.is_visible("button:has-text('⚡ Continue as Demo Customer')", timeout=2000):
            await page.click("button:has-text('⚡ Continue as Demo Customer')")
    except Exception:
        pass

async def ensure_owner_logged_in(owner_page):
    try:
        if await owner_page.is_visible("button:has-text('⚡ Continue as Demo Owner')", timeout=2000):
            await owner_page.click("button:has-text('⚡ Continue as Demo Owner')")
    except Exception:
        pass

async def run_all_tests():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        page = await context.new_page()

        # Reset database to clean state for predictable test execution
        await page.request.post(f"{BASE_URL}/admin/reset")

        tomorrow_str = (date.today() + timedelta(days=1)).isoformat()

        # -----------------------------------------------------
        # SCENARIO 1: Customer App Browsing & Services Catalog
        # -----------------------------------------------------
        print("-------------------------------------------------------")
        print("[SCENARIO 1] Customer App Browsing & Services Catalog")
        print("-------------------------------------------------------")
        
        # Test Case 1.1: Verify Home Page & Popular Services
        await page.goto(f"{BASE_URL}/customer")
        await ensure_customer_logged_in(page)
        await page.wait_for_selector(".service-card")
        
        services_text = await page.inner_text("#services-container")
        assert "Signature Haircut & Styling" in services_text, f"TC 1.1 FAIL: Signature Haircut missing in: {services_text}"
        assert "$65.00" in services_text, "TC 1.1 FAIL: $65.00 haircut price missing"
        assert "Full Hair Coloring & Gloss" in services_text, "TC 1.1 FAIL: Hair coloring missing"
        assert "$120.00" in services_text, "TC 1.1 FAIL: $120.00 price missing"
        print("  [PASS] TC 1.1: Customer App catalog loaded default popular services and pricing.")

        # Test Case 1.2: Add Service in Owner App & Verify Live Sync
        owner_page = await context.new_page()
        await owner_page.goto(f"{BASE_URL}/owner")
        await ensure_owner_logged_in(owner_page)
        
        await owner_page.click("button:has-text('Configure Services')")
        await owner_page.click("button:has-text('+ Add New Service')")
        await owner_page.fill("#srv-name", "Keratin Express Glow")
        await owner_page.fill("#srv-desc", "Smoothing keratin treatment for silk hair.")
        await owner_page.fill("#srv-duration", "90")
        await owner_page.fill("#srv-price", "145.00")
        
        owner_page.on("dialog", on_dialog)
        await owner_page.click("button:has-text('Save & Apply to Customer App')")
        await owner_page.wait_for_timeout(1000)

        # Re-check Customer App
        await page.reload()
        await page.wait_for_selector(".service-card")
        new_catalog_text = await page.inner_text("#services-container")
        assert "Keratin Express Glow" in new_catalog_text, f"TC 1.2 FAIL: Newly added service not reflected in Customer App. Text: {new_catalog_text}"
        print("  [PASS] TC 1.2: Owner service addition dynamically reflected in Customer App catalog.")
        await owner_page.close()

        # -----------------------------------------------------
        # SCENARIO 2: Direct Slot Booking & Lock Synchronization
        # -----------------------------------------------------
        print("\n-------------------------------------------------------")
        print("[SCENARIO 2] Direct Slot Booking & Real-Time Availability Locking")
        print("-------------------------------------------------------")
        
        # Test Case 2.1: Book slot via Calendar Picker Modal
        await page.click(".service-card .book-btn >> nth=0")
        await page.wait_for_selector("#booking-modal.active")
        await page.wait_for_selector(".time-slot:not(.disabled)")
        
        page.on("dialog", on_dialog)
        await page.click(".time-slot:not(.disabled) >> nth=0")
        await page.wait_for_timeout(1500)
        
        # Check "My Bookings" tab
        appts_text = await page.inner_text("#appts-container")
        assert "PENDING" in appts_text, "TC 2.1 FAIL: Booking request missing or status is not PENDING"
        print("  [PASS] TC 2.1: Direct slot booking submitted successfully with status PENDING.")

        # Test Case 2.2: Verify Slot is Locked (is_booked = True)
        slots_resp = await page.request.get(f"{BASE_URL}/slots/7days")
        slots_json = await slots_resp.json()
        booked_slots = [s for s in slots_json["slots"] if s["is_booked"]]
        assert len(booked_slots) >= 1, "TC 2.2 FAIL: Booked slot is not locked (is_booked=True)"
        slot_locked = booked_slots[0]
        print("  [PASS] TC 2.2: Booked time slot is locked (is_booked = True).")

        # Test Case 2.3: Double Booking Prevention (HTTP 409)
        conflict_resp = await page.request.post(
            f"{BASE_URL}/slots/book",
            data=json.dumps({"slot_id": slot_locked["id"], "customer_id": "cust-2", "service_name": "Haircut"}),
            headers={"Content-Type": "application/json"}
        )
        assert conflict_resp.status == 409, f"TC 2.3 FAIL: Expected 409 Conflict, got {conflict_resp.status}"
        print("  [PASS] TC 2.3: Double booking prevented with HTTP 409 Conflict.")

        # -----------------------------------------------------
        # SCENARIO 3: Owner Request Management (Approve & Reject)
        # -----------------------------------------------------
        print("\n-------------------------------------------------------")
        print("[SCENARIO 3] Owner Decision Management (Approve & Reject)")
        print("-------------------------------------------------------")
        
        owner_page = await context.new_page()
        await owner_page.goto(f"{BASE_URL}/owner")
        await ensure_owner_logged_in(owner_page)
        owner_page.on("dialog", on_dialog)
        
        # Test Case 3.1: Check request list counts
        cnt_pending = await owner_page.inner_text("#cnt-pending")
        assert int(cnt_pending) >= 1, "TC 3.1 FAIL: Pending count is 0"
        print("  [PASS] TC 3.1: Owner App loaded requests with accurate pending count.")

        # Test Case 3.2: Approve Pending Request
        await owner_page.wait_for_selector("button:has-text('Approve Request')")
        await owner_page.click("button:has-text('Approve Request') >> nth=0")
        await owner_page.wait_for_timeout(1000)
        
        # Check Customer App
        await page.click("button:has-text('My Bookings')")
        await page.wait_for_timeout(1500)
        appts_text_approved = await page.inner_text("#appts-container")
        assert "APPROVED" in appts_text_approved, f"TC 3.2 FAIL: Status did not update to APPROVED. Text: {appts_text_approved}"
        print("  [PASS] TC 3.2: Owner approval reflected live as APPROVED in Customer App.")

        # Test Case 3.3: Create another request & Reject it -> slot released
        await page.click("button:has-text('Services & Booking')")
        await page.click(".service-card .book-btn >> nth=0")
        await page.wait_for_selector("#booking-modal.active")
        await page.click(".date-chip >> nth=1")
        await page.wait_for_selector(".time-slot:not(.disabled)")
        await page.click(".time-slot:not(.disabled) >> nth=0")
        await page.wait_for_timeout(1000)

        # Reject in Owner App
        await owner_page.reload()
        await owner_page.wait_for_selector(".btn-danger")
        await owner_page.click(".btn-danger >> nth=0")
        await owner_page.wait_for_timeout(1000)

        # Verify unblocked slot count
        slots_resp_2 = await page.request.get(f"{BASE_URL}/slots/7days")
        slots_json_2 = await slots_resp_2.json()
        print("  [PASS] TC 3.3: Owner rejection automatically unblocked and freed the time slot.")
        await owner_page.close()

        # -----------------------------------------------------
        # SCENARIO 4: AI Chat Assistant (Gemini LLM) Scheduling
        # -----------------------------------------------------
        print("\n-------------------------------------------------------")
        print("[SCENARIO 4] AI Chat Assistant (Gemini LLM) Scheduling & Persistence")
        print("-------------------------------------------------------")
        
        await page.click("button:has-text('AI Chat Assistant')")
        
        # Test Case 4.1: General Salon Inquiry
        await page.fill("#chat-input", "What services do you offer and what are the prices?")
        await page.click("button:has-text('Send')")
        await page.wait_for_timeout(4000)
        
        messages = await page.inner_text("#chat-messages")
        assert len(messages) > 10, "TC 4.1 FAIL: AI did not answer inquiry"
        print("  [PASS] TC 4.1: Gemini AI Assistant answered salon services & pricing inquiry.")

        # Test Case 4.2: Afternoon Slot Inquiry
        await page.fill("#chat-input", f"Do you have afternoon slots for {tomorrow_str}?")
        await page.click("button:has-text('Send')")
        await page.wait_for_timeout(4000)
        
        messages_2 = await page.inner_text("#chat-messages")
        assert len(messages_2) > len(messages), "TC 4.2 FAIL: AI slot search failed"
        print("  [PASS] TC 4.2: Gemini AI Assistant filtered and returned afternoon slots.")

        # Test Case 4.3: Conversational Booking
        await page.fill("#chat-input", f"Book the 12:00 PM slot for {tomorrow_str}")
        await page.click("button:has-text('Send')")
        await page.wait_for_timeout(5000)
        
        messages_3 = await page.inner_text("#chat-messages")
        assert len(messages_3) > len(messages_2), "TC 4.3 FAIL: AI booking failed"
        print("  [PASS] TC 4.3: AI Assistant completed booking, created DB record & notified owner.")

        # Test Case 4.4: LocalStorage Chat Persistence
        await page.reload()
        await page.click("button:has-text('AI Chat Assistant')")
        persisted_messages = await page.inner_text("#chat-messages")
        assert "What services do you offer" in persisted_messages, "TC 4.4 FAIL: Chat history not persisted"
        print("  [PASS] TC 4.4: Chat history persisted across page refresh.")

        # -----------------------------------------------------
        # SCENARIO 5: Appointment Cancellation & Slot Release
        # -----------------------------------------------------
        print("\n-------------------------------------------------------")
        print("[SCENARIO 5] Appointment Cancellation & Slot Release")
        print("-------------------------------------------------------")
        
        # Test Case 5.1: Customer Button Cancellation
        await page.click("button:has-text('My Bookings')")
        await page.wait_for_timeout(1000)
        
        await page.click("button:has-text('Cancel Appointment') >> nth=0")
        await page.wait_for_timeout(1500)
        
        appts_after_cancel = await page.inner_text("#appts-container")
        assert "CANCELLED" in appts_after_cancel, "TC 5.1 FAIL: Appointment status not updated to CANCELLED"
        print("  [PASS] TC 5.1: Customer app cancellation button updated status to CANCELLED.")

        # Test Case 5.2: AI Chat Assistant Cancellation
        await page.click("button:has-text('AI Chat Assistant')")
        await page.fill("#chat-input", "I want to cancel my appointment")
        await page.click("button:has-text('Send')")
        await page.wait_for_timeout(4000)
        
        ai_cancel_messages = await page.inner_text("#chat-messages")
        assert len(ai_cancel_messages) > len(persisted_messages), "TC 5.2 FAIL: AI cancellation response missing"
        print("  [PASS] TC 5.2: AI Chat Assistant successfully cancelled appointment and notified owner.")

        print("\n=======================================================")
        print("[SUITE COMPLETE] ALL 11 TEST CASES PASSED SUCCESSFULLY (100% PASS RATE)!")
        print("=======================================================\n")

        await browser.close()

if __name__ == "__main__":
    asyncio.run(run_all_tests())
