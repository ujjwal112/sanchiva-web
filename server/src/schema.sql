-- Expense Tracker Schema
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Custom categories per section (user-only custom types)
CREATE TABLE IF NOT EXISTS custom_categories (
  id SERIAL PRIMARY KEY,
  section VARCHAR(50) NOT NULL,
  name VARCHAR(100) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(section, name)
);

-- Daily Expenses
CREATE TABLE IF NOT EXISTS daily_expenses (
  id SERIAL PRIMARY KEY,
  category VARCHAR(100) NOT NULL,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  expense_date DATE NOT NULL,
  item_name VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Loans
CREATE TABLE IF NOT EXISTS loans (
  id SERIAL PRIMARY KEY,
  bank_name VARCHAR(150) NOT NULL,
  emi_deduction_bank VARCHAR(150) NOT NULL,
  emi_deduction_date INTEGER NOT NULL CHECK (emi_deduction_date BETWEEN 1 AND 31),
  emi_close_month INTEGER NOT NULL CHECK (emi_close_month BETWEEN 1 AND 12),
  emi_close_year INTEGER NOT NULL,
  emi_amount NUMERIC(12, 2) NOT NULL CHECK (emi_amount >= 0),
  status VARCHAR(20) NOT NULL DEFAULT 'ongoing' CHECK (status IN ('ongoing', 'closed')),
  start_month INTEGER DEFAULT EXTRACT(MONTH FROM CURRENT_DATE)::INTEGER,
  start_year INTEGER DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Credit Card Spends
CREATE TABLE IF NOT EXISTS credit_card_spends (
  id SERIAL PRIMARY KEY,
  spend_date DATE NOT NULL,
  spend_type VARCHAR(100) NOT NULL,
  credit_card_name VARCHAR(150) NOT NULL,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Credit Card EMIs
CREATE TABLE IF NOT EXISTS credit_card_emis (
  id SERIAL PRIMARY KEY,
  emi_name VARCHAR(150) NOT NULL,
  credit_card_name VARCHAR(150) NOT NULL,
  start_month INTEGER NOT NULL CHECK (start_month BETWEEN 1 AND 12),
  start_year INTEGER NOT NULL,
  end_month INTEGER NOT NULL CHECK (end_month BETWEEN 1 AND 12),
  end_year INTEGER NOT NULL,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Income / Salary sources
CREATE TABLE IF NOT EXISTS income_sources (
  id SERIAL PRIMARY KEY,
  source_name VARCHAR(150) NOT NULL,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
  year INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Other Assets
CREATE TABLE IF NOT EXISTS assets (
  id SERIAL PRIMARY KEY,
  asset_type VARCHAR(100) NOT NULL,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  notes VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Money given to people (receivables / personal loans given)
CREATE TABLE IF NOT EXISTS money_given (
  id SERIAL PRIMARY KEY,
  person_name VARCHAR(150) NOT NULL,
  given_date DATE NOT NULL,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  notes VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Events
CREATE TABLE IF NOT EXISTS events (
  id SERIAL PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  event_type VARCHAR(50) NOT NULL,
  sub_type VARCHAR(100),
  event_date DATE,
  end_date DATE,
  location VARCHAR(255),
  budget NUMERIC(14, 2) DEFAULT 0,
  notes TEXT,
  metadata JSONB DEFAULT '{}',
  status VARCHAR(30) DEFAULT 'planning',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Event todo / booking items
CREATE TABLE IF NOT EXISTS event_items (
  id SERIAL PRIMARY KEY,
  event_id INTEGER NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  category VARCHAR(100),
  planned_amount NUMERIC(12, 2) DEFAULT 0,
  token_paid NUMERIC(12, 2) DEFAULT 0,
  remaining_amount NUMERIC(12, 2) DEFAULT 0,
  due_date DATE,
  is_done BOOLEAN DEFAULT FALSE,
  vendor_name VARCHAR(150),
  notes TEXT,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Event guest list
CREATE TABLE IF NOT EXISTS event_guests (
  id SERIAL PRIMARY KEY,
  event_id INTEGER NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  name VARCHAR(150) NOT NULL,
  side VARCHAR(50),
  rsvp VARCHAR(20) DEFAULT 'pending',
  count INTEGER DEFAULT 1,
  phone VARCHAR(30),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_daily_expenses_date ON daily_expenses(expense_date);
CREATE INDEX IF NOT EXISTS idx_loans_status ON loans(status);
CREATE INDEX IF NOT EXISTS idx_cc_spends_date ON credit_card_spends(spend_date);
CREATE INDEX IF NOT EXISTS idx_income_month ON income_sources(year, month);
CREATE INDEX IF NOT EXISTS idx_event_items_event ON event_items(event_id);
CREATE INDEX IF NOT EXISTS idx_event_guests_event ON event_guests(event_id);
