# Salon Appointment Booking System — Build Prompt for Antigravity

## Project Overview
Build a two-app salon appointment booking system:
1. **Customer App** — lets salon customers browse services, check availability, and request appointments.
2. **Owner App** — lets the salon owner view, approve, or reject appointment requests, and manage services/availability.

An AI scheduling assistant (built with LangGraph + LangChain, powered by Google Gemini) sits in the middle: it interprets customer requests, checks real-time availability against Supabase, proposes valid slots, and only finalizes a booking after the owner approves it in their app.

---

## Tech Stack
- **Frontend (both apps):** Flutter (Dart), Material Design 3, single shared codebase with two build targets/flavors (`customer` and `owner`)
- **Backend / Database / Auth / Storage:** Supabase (Postgres, Supabase Auth, Supabase Storage for profile/salon photos, Supabase Realtime for live status updates)
- **AI Agent Layer:** Python service using LangGraph + LangChain, calling the Gemini API, exposed to the Flutter apps via a lightweight REST/HTTP endpoint (FastAPI) that both apps call
- **Push Notifications:** Firebase Cloud Messaging (free) for appointment status alerts (request received, approved, rejected, reminder)
- **Version Control:** GitHub — initialize repo, meaningful commit messages, `.gitignore` for Flutter/Python secrets
- **Environment Secrets:** `.env` files (never hardcoded) for Supabase URL/key, Gemini API key, FCM keys — provide a `.env.example`

---

## Data Model (Supabase / Postgres)

Create these tables with appropriate foreign keys, indexes, and Row Level Security (RLS) policies:

- `customers` — id, name, phone, email, created_at
- `owners` — id, salon_name, phone, email (only one row expected, but keep it a table for extensibility)
- `services` — id, name, description, duration_minutes, price, is_active
- `staff` (optional but recommended) — id, name, specialties, working_hours (JSON: per-day open/close)
- `availability_slots` — id, staff_id, date, start_time, end_time, is_booked
- `appointments` — id, customer_id, service_id, staff_id, requested_start_time, requested_end_time, status (`pending`, `approved`, `rejected`, `cancelled`, `completed`), notes, created_at, updated_at
- `notifications` — id, appointment_id, recipient_type (`customer`/`owner`), message, is_read, created_at

RLS: customers can only read/write their own rows; owners have full read/write on all appointment and service data.

---

## LangGraph Agent Architecture

Build a Python service (FastAPI + LangGraph + LangChain, Gemini as the LLM) with a graph that models the booking flow as a state machine:

**State object:** customer request text, extracted intent (service, preferred date/time, staff preference), candidate slots, selected slot, appointment status, conversation history.

**Nodes:**
1. `parse_request` — LLM node: extract service type, preferred date/time window, and any special requests from the customer's natural-language input
2. `check_availability` — tool node: query Supabase `availability_slots` / `appointments` for open slots matching the request
3. `propose_slots` — LLM node: if multiple slots match, generate a friendly response listing 2–3 options; if none match, suggest the nearest alternatives
4. `create_pending_appointment` — tool node: once customer confirms a slot, write a `pending` row to `appointments` and trigger a notification to the owner
5. `await_owner_decision` — **interrupt node** (human-in-the-loop): graph pauses here until the owner app calls the approve/reject endpoint
6. `finalize_appointment` — tool node: on approval, mark slot as booked and notify the customer; on rejection, free the slot, notify the customer, and loop back to `propose_slots` for alternatives
7. `handle_edge_cases` — fallback node for cancellations, rescheduling requests, or unclear input — routes back to `parse_request` or escalates to a "contact salon directly" message

Use LangGraph's **checkpointing** (e.g. SQLite or Postgres checkpointer, matching Supabase) so a conversation can be paused at `await_owner_decision` and resumed later without losing state — this is the core reason to use LangGraph over a plain chain.

Expose two HTTP endpoints for the Flutter apps to call:
- `POST /chat` — customer app sends natural language input, gets back agent response + any proposed slots
- `POST /owner/decision` — owner app sends `{appointment_id, decision: "approved"|"rejected"}`, which resumes the paused graph

---

## Customer App — Screens & Features
1. **Onboarding/Auth** — phone or email sign-up/login via Supabase Auth
2. **Home** — salon branding, list of services with price/duration, "Book Appointment" CTA
3. **Chat-style booking screen** — conversational UI where the customer types/taps what they want (e.g. "haircut this Saturday afternoon"); the LangGraph agent responds with options
4. **My Appointments** — list of upcoming/past appointments with live status (pending/approved/rejected), pull-to-refresh via Supabase Realtime
5. **Appointment detail** — date, time, service, staff, status, cancel button (if still pending or with enough notice)
6. **Push notifications** — booking confirmed, approved, rejected, or reminder 1 hour before

## Owner App — Screens & Features
1. **Auth** — simple owner login (Supabase Auth, single owner account or staff logins)
2. **Dashboard** — today's appointments at a glance, pending requests needing action badge count
3. **Pending Requests** — list of `pending` appointments with one-tap **Approve** / **Reject** buttons (reject optionally prompts for a reason, which gets sent to the customer)
4. **Calendar view** — day/week view of all approved appointments
5. **Manage Services** — add/edit/deactivate services, prices, durations
6. **Manage Availability** — set working hours, block off days/times
7. **Push notifications** — new booking request alert

---

## Design Requirements
- Material Design 3 throughout, with a custom color scheme (warm, inviting tones suitable for a salon — let the agent propose a palette, e.g. soft rose/terracotta primary with neutral secondary tones)
- Consistent typography scale, rounded card-based layouts, smooth transitions between screens
- Empty states, loading skeletons, and error states designed thoughtfully (not just spinners/blank screens)
- Fully responsive across common Android screen sizes
- Dark mode support for both apps

---

## Non-Functional Requirements
- Clean project structure: separate Flutter app for customer (`/apps/customer_app`), Flutter app for owner (`/apps/owner_app`), Python agent service (`/agent_service`), and shared Dart package for common models/widgets (`/packages/shared`)
- All secrets in `.env`, loaded via `flutter_dotenv` (Flutter) and `python-dotenv` (Python) — never committed
- Basic unit tests for the LangGraph node logic and Supabase query functions
- README with setup instructions: how to run Supabase locally/connect to cloud project, how to run the agent service, how to run both Flutter apps
- Initialize a GitHub repository, commit incrementally with clear messages as each major piece is completed (data model → agent service → customer app → owner app)

---

## Deliverables
1. Supabase schema migration files (SQL)
2. Python `agent_service/` with the LangGraph graph, FastAPI endpoints, and a `.env.example`
3. Flutter `customer_app/` and `owner_app/` fully functional against the schema above
4. Shared Flutter package for common models/theme/widgets
5. README covering local setup, environment variables needed, and how to run everything end-to-end
6. All code pushed to the GitHub repository, organized with a logical commit history

Build this step by step: schema first, then the agent service, then the two Flutter apps, testing the booking flow end-to-end (customer requests → agent proposes slot → owner approves → customer notified) before polishing the UI.
