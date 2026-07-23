-- =======================================================
-- LUXE AURA SALON & SPA - SUPABASE POSTGRESQL SCHEMA WITH AUTH
-- Execute this SQL in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/payazqyiyuapunwhhwop/sql
-- =======================================================

-- 1. Drop existing tables if re-initializing
DROP TABLE IF EXISTS public.appointments CASCADE;
DROP TABLE IF EXISTS public.slots CASCADE;
DROP TABLE IF EXISTS public.services CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- 2. User Profiles Table (Role-Based Access Control)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    role TEXT CHECK (role IN ('customer', 'owner')) NOT NULL DEFAULT 'customer',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Automatic Profile Creation Trigger on Sign-Up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, avatar_url, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', SPLIT_PART(NEW.email, '@', 1)),
        NEW.raw_user_meta_data->>'avatar_url',
        COALESCE(NEW.raw_user_meta_data->>'role', 'customer')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. Services Catalog Table
CREATE TABLE public.services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    duration_minutes INTEGER DEFAULT 60,
    price NUMERIC(10, 2) NOT NULL,
    category TEXT DEFAULT 'General',
    is_popular BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. 7-Day Slot Availability Table
CREATE TABLE public.slots (
    id TEXT PRIMARY KEY,
    date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    staff_id TEXT,
    staff_name TEXT,
    is_booked BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Customer Appointments Table
CREATE TABLE public.appointments (
    id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL,
    customer_name TEXT DEFAULT 'Customer',
    service_id UUID,
    service_name TEXT NOT NULL,
    staff_id TEXT,
    staff_name TEXT,
    requested_start_time TIMESTAMPTZ NOT NULL,
    requested_end_time TIMESTAMPTZ NOT NULL,
    status TEXT DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Enable Row Level Security (RLS) & Public Access Policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public profile access" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Allow public read/write services" ON public.services FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/write slots" ON public.slots FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow public read/write appointments" ON public.appointments FOR ALL USING (true) WITH CHECK (true);

-- 8. Seed Baseline Services
INSERT INTO public.services (id, name, description, duration_minutes, price, category, is_popular) VALUES
('11111111-1111-1111-1111-111111111111', 'Signature Haircut & Styling', 'Precision haircut, wash, scalp massage, and professional blow-dry styling.', 60, 65.00, 'Hair', true),
('22222222-2222-2222-2222-222222222222', 'Full Hair Coloring & Gloss', 'Custom color treatment with premium organic pigments and shine-enhancing gloss.', 60, 120.00, 'Hair', true),
('33333333-3333-3333-3333-333333333333', 'Hydrating Facial Spa', 'Deep cleansing, gentle exfoliation, hydrating botanical mask, and facial massage.', 60, 85.00, 'Facial', true),
('44444444-4444-4444-4444-444444444444', 'Gel Manicure & Hand Care', 'Long-lasting gel polish, nail shaping, cuticle treatment, and hand massage.', 60, 45.00, 'Nails', false);
