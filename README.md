# ✂️ Luxe Salon Appointment Booking System

A two-app salon appointment booking system (**Customer App** & **Owner App**) powered by an **AI Scheduling Agent** built with **LangGraph**, **LangChain**, and **Google Gemini**, backed by **Supabase** (Postgres, Auth, Realtime, Storage).

---

## 🌟 System Architecture

```
                                +-----------------------------+
                                |      Customer App           |
                                | (Flutter / MD3 Design)      |
                                +--------------+--------------+
                                               |
                                    POST /chat | (Natural language requests & proposed slot selection)
                                               v
+-----------------------+              +-------+----------------------+
|                       |              |     AI Agent Service         |
|  Supabase Postgres DB | <----------> | (Python, FastAPI, LangGraph) |
| (Services, Staff,     |              | Gemini 1.5 Flash LLM State   |
| Slots, Appointments,  |              | Machine with Checkpointer    |
| Notifications)        |              +-------+----------------------+
|                       |                      ^
+-----------------------+                      | POST /owner/decision
                                               | (Resumes paused state machine)
                                +--------------+--------------+
                                |        Owner App            |
                                | (Flutter / MD3 Dashboard)   |
                                +-----------------------------+
```

---

## 🚀 Key Features

### 1. 🤖 LangGraph AI Scheduling Agent (`agent_service/`)
- **State Machine Lifecycle**:
  1. `parse_request`: Uses Gemini LLM to extract requested service, date, and preferred time window.
  2. `check_availability`: Queries Supabase `availability_slots` for open slots matching requirements.
  3. `propose_slots`: Formulates friendly response listing candidate options.
  4. `create_pending_appointment`: Writes `pending` appointment to Supabase DB and notifies owner.
  5. `await_owner_decision`: **Human-in-the-loop interrupt node** pausing execution using SQLite/Postgres checkpointer.
  6. `finalize_appointment`: Triggered when owner approves/rejects via HTTP, updates database status, and alerts customer.
  7. `handle_edge_cases`: Handles cancellations or unclear input fallback.

### 2. 📱 Customer App (`apps/customer_app/`)
- **Interactive Chat Booking**: Conversational UI with interactive slot selection chips.
- **Service Catalog**: Browse salon services with prices, descriptions, and duration.
- **My Appointments**: Real-time list of upcoming/past appointments with live status pills (`pending`, `approved`, `rejected`).
- **Appointment Details**: Full schedule breakdown with one-tap cancellation.

### 3. 👑 Owner App (`apps/owner_app/`)
- **Owner Dashboard**: Salon overview metrics, pending request count badge, today's schedule.
- **Pending Request Actions**: One-tap **Approve** and **Reject** buttons (with optional rejection reason prompt).
- **Calendar & Schedule View**: Master calendar view of confirmed bookings.
- **Service & Shift Management**: Manage service pricing/durations and configure weekly working hours.

---

## 🛠️ Project Structure

```
├── supabase/
│   └── migrations/
│       └── 20260722000000_init_salon_schema.sql  # Postgres schema, indexes, RLS, seed data
├── agent_service/
│   ├── app/
│   │   ├── main.py                               # FastAPI application endpoints
│   │   ├── config.py                             # Settings loader (pydantic)
│   │   ├── database.py                           # Supabase client & mock DB tool functions
│   │   ├── models.py                             # API request/response models
│   │   └── graph/
│   │       ├── state.py                          # BookingState schema
│   │       ├── tools.py                          # Supabase query tools
│   │       ├── nodes.py                          # 7 state machine nodes
│   │       └── workflow.py                       # Compiled StateGraph & checkpointer
│   ├── tests/                                    # Unit tests for nodes & database tools
│   ├── requirements.txt
│   └── .env.example
├── packages/
│   └── shared/                                   # Shared Dart package
│       ├── lib/models/                           # Dart entity models
│       ├── lib/theme/                            # Material Design 3 palette & themes
│       ├── lib/services/                         # Supabase & Agent API clients
│       └── lib/widgets/                          # MD3 Cards, Badges, Buttons, Skeletons
├── apps/
│   ├── customer_app/                             # Customer Flutter application
│   └── owner_app/                                # Owner Flutter application
└── README.md
```

---

## ⚡ Quick Start & Setup Instructions

### 1. Database Setup (Supabase)
1. Execute the SQL script in `supabase/migrations/20260722000000_init_salon_schema.sql` inside your Supabase SQL Editor.
2. This creates all 7 tables (`customers`, `owners`, `services`, `staff`, `availability_slots`, `appointments`, `notifications`), configures RLS policies, and inserts demo seed data.

### 2. Python AI Agent Service
```bash
# 1. Navigate to agent service directory
cd agent_service

# 2. Install dependencies
pip install -r requirements.txt

# 3. Create .env file
cp .env.example .env
# Edit .env with your GEMINI_API_KEY and SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY

# 4. Run unit tests
python -m unittest discover -s tests

# 5. Start FastAPI server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 3. Flutter Customer App
```bash
cd apps/customer_app
flutter pub get
flutter run
```

### 4. Flutter Owner App
```bash
cd apps/owner_app
flutter pub get
flutter run
```

---

## 🧪 Testing the Complete Booking Flow End-to-End

1. **Launch Agent Backend**: Ensure `uvicorn app.main:app` is running on `http://localhost:8000`.
2. **Customer App**: Tap **Book with AI Assistant** and type `"Haircut tomorrow afternoon"`.
3. **Agent Proposal**: The AI agent parses your request, checks available slots in Supabase, and returns options.
4. **Reserve Slot**: Tap one of the proposed slot chips. A `pending` appointment is created and sent to the owner.
5. **Owner App**: Open the Owner App. The **Pending Requests** metric increments. Tap **Approve**.
6. **State Finalization**: The Owner App calls `POST /owner/decision`, resuming the paused LangGraph state machine. The customer's status transitions to **APPROVED**!
