-- ========================================================
-- SALON APPOINTMENT BOOKING SYSTEM SCHEMA & MIGRATIONS
-- ========================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. CUSTOMERS TABLE
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. OWNERS TABLE
CREATE TABLE IF NOT EXISTS public.owners (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    salon_name VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. SERVICES TABLE
CREATE TABLE IF NOT EXISTS public.services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    duration_minutes INTEGER NOT NULL DEFAULT 30,
    price NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. STAFF TABLE
CREATE TABLE IF NOT EXISTS public.staff (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    specialties TEXT[],
    working_hours JSONB DEFAULT '{"monday": {"open": "09:00", "close": "18:00"}, "tuesday": {"open": "09:00", "close": "18:00"}, "wednesday": {"open": "09:00", "close": "18:00"}, "thursday": {"open": "09:00", "close": "18:00"}, "friday": {"open": "09:00", "close": "18:00"}, "saturday": {"open": "10:00", "close": "17:00"}, "sunday": {"open": null, "close": null}}'::jsonb,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. AVAILABILITY SLOTS TABLE
CREATE TABLE IF NOT EXISTS public.availability_slots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    staff_id UUID REFERENCES public.staff(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_booked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. APPOINTMENTS TABLE
CREATE TABLE IF NOT EXISTS public.appointments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID REFERENCES public.customers(id) ON DELETE CASCADE,
    service_id UUID REFERENCES public.services(id) ON DELETE CASCADE,
    staff_id UUID REFERENCES public.staff(id) ON DELETE CASCADE,
    requested_start_time TIMESTAMPTZ NOT NULL,
    requested_end_time TIMESTAMPTZ NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled', 'completed')),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    appointment_id UUID REFERENCES public.appointments(id) ON DELETE CASCADE,
    recipient_type VARCHAR(20) NOT NULL CHECK (recipient_type IN ('customer', 'owner')),
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========================================================
-- INDEXES FOR PERFORMANCE
-- ========================================================
CREATE INDEX IF NOT EXISTS idx_availability_slots_date ON public.availability_slots(date);
CREATE INDEX IF NOT EXISTS idx_availability_slots_staff_booked ON public.availability_slots(staff_id, is_booked);
CREATE INDEX IF NOT EXISTS idx_appointments_customer_id ON public.appointments(customer_id);
CREATE INDEX IF NOT EXISTS idx_appointments_status ON public.appointments(status);

-- ========================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ========================================================
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.owners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.availability_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Allow public read access to active services and staff
CREATE POLICY "Allow public read access to services" ON public.services
    FOR SELECT USING (is_active = TRUE);

CREATE POLICY "Allow public read access to staff" ON public.staff
    FOR SELECT USING (is_active = TRUE);

CREATE POLICY "Allow public read access to availability_slots" ON public.availability_slots
    FOR SELECT USING (TRUE);

-- Customers can view & insert their own data
CREATE POLICY "Customers can manage their profile" ON public.customers
    FOR ALL USING (auth.uid() = id);

CREATE POLICY "Customers can view their appointments" ON public.appointments
    FOR SELECT USING (auth.uid() = customer_id);

CREATE POLICY "Customers can create appointments" ON public.appointments
    FOR INSERT WITH CHECK (auth.uid() = customer_id);

-- Owners have full access to everything
CREATE POLICY "Owners have full access to services" ON public.services
    FOR ALL USING (EXISTS (SELECT 1 FROM public.owners WHERE id = auth.uid()));

CREATE POLICY "Owners have full access to staff" ON public.staff
    FOR ALL USING (EXISTS (SELECT 1 FROM public.owners WHERE id = auth.uid()));

CREATE POLICY "Owners have full access to slots" ON public.availability_slots
    FOR ALL USING (EXISTS (SELECT 1 FROM public.owners WHERE id = auth.uid()));

CREATE POLICY "Owners have full access to appointments" ON public.appointments
    FOR ALL USING (EXISTS (SELECT 1 FROM public.owners WHERE id = auth.uid()));

-- Service Role / Agent Service Policy (for API agent backend)
-- (Supabase Service Key bypasses RLS automatically in server environments)

-- ========================================================
-- SEED DATA FOR DEMO & TESTING
-- ========================================================

-- Seed Owner
INSERT INTO public.owners (id, salon_name, phone, email)
VALUES ('00000000-0000-0000-0000-000000000001', 'Luxe Aura Salon & Spa', '+1 555-0199', 'owner@luxeaurasalon.com')
ON CONFLICT (email) DO NOTHING;

-- Seed Services
INSERT INTO public.services (id, name, description, duration_minutes, price, is_active)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'Signature Haircut & Styling', 'Precision haircut including shampoo, scalp massage, and professional blow-dry styling.', 45, 65.00, TRUE),
  ('22222222-2222-2222-2222-222222222222', 'Full Hair Coloring & Gloss', 'Full head color treatment using premium organic dyes, followed by a shine gloss.', 90, 120.00, TRUE),
  ('33333333-3333-3333-3333-333333333333', 'Hydrating Facial Spa', 'Deep cleansing facial with botanical enzymes and hydrating hyaluronic mask.', 60, 85.00, TRUE),
  ('44444444-4444-4444-4444-444444444444', 'Gel Manicure & Hand Care', 'Nail shaping, cuticle treatment, gel polish application, and hand massage.', 45, 45.00, TRUE)
ON CONFLICT DO NOTHING;

-- Seed Staff
INSERT INTO public.staff (id, name, specialties, is_active)
VALUES 
  ('a1111111-1111-1111-1111-111111111111', 'Elena Rostova', ARRAY['Haircut', 'Hair Coloring'], TRUE),
  ('b2222222-2222-2222-2222-222222222222', 'Marcus Vance', ARRAY['Facial', 'Skincare'], TRUE),
  ('c3333333-3333-3333-3333-333333333333', 'Chloe Bennett', ARRAY['Manicure', 'Nail Art'], TRUE)
ON CONFLICT DO NOTHING;

-- Seed Sample Slots for upcoming dates
INSERT INTO public.availability_slots (id, staff_id, date, start_time, end_time, is_booked)
VALUES
  (uuid_generate_v4(), 'a1111111-1111-1111-1111-111111111111', CURRENT_DATE + INTERVAL '1 day', '10:00:00', '10:45:00', FALSE),
  (uuid_generate_v4(), 'a1111111-1111-1111-1111-111111111111', CURRENT_DATE + INTERVAL '1 day', '11:00:00', '11:45:00', FALSE),
  (uuid_generate_v4(), 'a1111111-1111-1111-1111-111111111111', CURRENT_DATE + INTERVAL '1 day', '14:00:00', '14:45:00', FALSE),
  (uuid_generate_v4(), 'b2222222-2222-2222-2222-222222222222', CURRENT_DATE + INTERVAL '1 day', '12:00:00', '13:00:00', FALSE),
  (uuid_generate_v4(), 'b2222222-2222-2222-2222-222222222222', CURRENT_DATE + INTERVAL '1 day', '15:00:00', '16:00:00', FALSE),
  (uuid_generate_v4(), 'c3333333-3333-3333-3333-333333333333', CURRENT_DATE + INTERVAL '1 day', '09:30:00', '10:15:00', FALSE),
  (uuid_generate_v4(), 'c3333333-3333-3333-3333-333333333333', CURRENT_DATE + INTERVAL '1 day', '13:30:00', '14:15:00', FALSE)
ON CONFLICT DO NOTHING;
