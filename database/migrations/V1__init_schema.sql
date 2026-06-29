-- Customer Loan Onboarding - Initial Schema
-- PostgreSQL dialect
-- Scope:
-- - Customer lookup and basic customer storage
-- - Loan application draft/processing lifecycle
-- - Asset is intentionally excluded in this version
--
-- Design notes:
-- - loan_application represents the main business record in this module.
-- - loan_application.current_state_id stores the current lifecycle state.
-- - loan_application_state_history stores lifecycle events such as CREATE, SUBMIT, CANCEL.
-- - requested_amount is nullable because a draft application may be created before loan amount is known.
-- - submitted_at, closed_at, created_at, updated_at, deleted_at are intentionally not kept on loan_application in this version.
--   Lifecycle timing is captured through loan_application_state_history.changed_at.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =========================================================
-- 1. Customer
-- =========================================================

CREATE TABLE customer (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_code VARCHAR(50) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20),
    identity_number VARCHAR(20),
    date_of_birth DATE,

    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',

    CONSTRAINT uq_customer_code UNIQUE (customer_code),
    CONSTRAINT uq_customer_phone_number UNIQUE (phone_number),
    CONSTRAINT uq_customer_identity_number UNIQUE (identity_number),
    CONSTRAINT chk_customer_status
        CHECK (status IN ('ACTIVE', 'INACTIVE', 'RESTRICTED'))
);

CREATE INDEX idx_customer_full_name ON customer(full_name);
CREATE INDEX idx_customer_date_of_birth ON customer(date_of_birth);
CREATE INDEX idx_customer_status ON customer(status);

-- =========================================================
-- 2. Loan application lifecycle reference tables
-- =========================================================

CREATE TABLE loan_application_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,

    is_initial BOOLEAN NOT NULL DEFAULT FALSE,
    is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INT NOT NULL,

    CONSTRAINT uq_loan_application_state_code UNIQUE (code)
);

CREATE UNIQUE INDEX uq_loan_application_state_initial
ON loan_application_state(is_initial)
WHERE is_initial = TRUE;

CREATE TABLE loan_application_state_transition (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    from_state_id UUID NOT NULL REFERENCES loan_application_state(id),
    to_state_id UUID NOT NULL REFERENCES loan_application_state(id),

    action_code VARCHAR(50) NOT NULL,
    action_name VARCHAR(100) NOT NULL,
    description TEXT,

    CONSTRAINT uq_loan_application_state_transition
        UNIQUE (from_state_id, to_state_id, action_code),
    CONSTRAINT chk_loan_application_state_transition_not_self
        CHECK (from_state_id <> to_state_id)
);

-- =========================================================
-- 3. Loan application
-- =========================================================

CREATE TABLE loan_application (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    loan_application_code VARCHAR(50) NOT NULL,
    customer_id UUID NOT NULL REFERENCES customer(id),
    current_state_id UUID NOT NULL REFERENCES loan_application_state(id),

    requested_amount NUMERIC(18, 2),
    loan_purpose TEXT,

    CONSTRAINT uq_loan_application_code UNIQUE (loan_application_code),
    CONSTRAINT chk_loan_application_requested_amount
        CHECK (requested_amount IS NULL OR requested_amount > 0)
);

CREATE INDEX idx_loan_application_customer_id ON loan_application(customer_id);
CREATE INDEX idx_loan_application_current_state_id ON loan_application(current_state_id);

-- =========================================================
-- 4. Loan application state history
-- =========================================================

CREATE TABLE loan_application_state_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    loan_application_id UUID NOT NULL REFERENCES loan_application(id),

    from_state_id UUID REFERENCES loan_application_state(id),
    to_state_id UUID NOT NULL REFERENCES loan_application_state(id),

    action_code VARCHAR(50) NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(100),
    note TEXT,

    CONSTRAINT chk_loan_application_state_history_not_self
        CHECK (from_state_id IS NULL OR from_state_id <> to_state_id)
);

CREATE INDEX idx_loan_application_state_history_application_id
ON loan_application_state_history(loan_application_id);

CREATE INDEX idx_loan_application_state_history_changed_at
ON loan_application_state_history(changed_at);

CREATE INDEX idx_loan_application_state_history_to_state_id
ON loan_application_state_history(to_state_id);
