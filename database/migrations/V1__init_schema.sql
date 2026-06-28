-- Customer Loan Onboarding - Initial Schema
-- PostgreSQL dialect
-- Scope:
--   - Simple customer storage
--   - Simple vehicle asset storage
--   - Loan application storage
--   - Lifecycle management only for loan_application

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =========================================================
-- 1. Customer
-- =========================================================

CREATE TABLE customer (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_code VARCHAR(50) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    identity_number VARCHAR(20),
    date_of_birth DATE,
    address TEXT,

    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,

    CONSTRAINT uq_customer_code UNIQUE (customer_code),
    CONSTRAINT uq_customer_phone_number UNIQUE (phone_number),
    CONSTRAINT uq_customer_identity_number UNIQUE (identity_number),
    CONSTRAINT chk_customer_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'RESTRICTED'))
);

-- =========================================================
-- 2. Asset
-- =========================================================

CREATE TABLE asset (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    asset_code VARCHAR(50) NOT NULL,
    customer_id UUID NOT NULL,

    license_plate VARCHAR(20) NOT NULL,
    vehicle_brand VARCHAR(100) NOT NULL,
    vehicle_model VARCHAR(100) NOT NULL,
    vehicle_version VARCHAR(100),
    manufacture_year INT,

    status VARCHAR(30) NOT NULL DEFAULT 'AVAILABLE',

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,

    CONSTRAINT uq_asset_code UNIQUE (asset_code),
    CONSTRAINT uq_asset_license_plate UNIQUE (license_plate),
    CONSTRAINT fk_asset_customer FOREIGN KEY (customer_id) REFERENCES customer(id),
    CONSTRAINT chk_asset_status CHECK (status IN ('AVAILABLE', 'PLEDGED', 'RELEASED')),
    CONSTRAINT chk_asset_manufacture_year CHECK (
        manufacture_year IS NULL OR (manufacture_year >= 1900 AND manufacture_year <= 2100)
    )
);

CREATE INDEX idx_asset_customer_id ON asset(customer_id);
CREATE INDEX idx_asset_status ON asset(status);

-- =========================================================
-- 3. Loan application state master
-- =========================================================

CREATE TABLE loan_application_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    code VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,

    is_initial BOOLEAN NOT NULL DEFAULT FALSE,
    is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order INT NOT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_loan_application_state_code UNIQUE (code),
    CONSTRAINT chk_loan_application_state_sort_order CHECK (sort_order > 0)
);

-- Only one initial state should exist.
CREATE UNIQUE INDEX uq_loan_application_initial_state
ON loan_application_state(is_initial)
WHERE is_initial = TRUE;

-- =========================================================
-- 4. Loan application
-- =========================================================

CREATE TABLE loan_application (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    loan_application_code VARCHAR(50) NOT NULL,
    customer_id UUID NOT NULL,
    asset_id UUID NOT NULL,
    current_state_id UUID NOT NULL,

    requested_amount NUMERIC(18, 2) NOT NULL,
    loan_purpose TEXT,

    submitted_at TIMESTAMP,
    closed_at TIMESTAMP,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,

    CONSTRAINT uq_loan_application_code UNIQUE (loan_application_code),
    CONSTRAINT fk_loan_application_customer FOREIGN KEY (customer_id) REFERENCES customer(id),
    CONSTRAINT fk_loan_application_asset FOREIGN KEY (asset_id) REFERENCES asset(id),
    CONSTRAINT fk_loan_application_current_state FOREIGN KEY (current_state_id) REFERENCES loan_application_state(id),
    CONSTRAINT chk_loan_application_requested_amount CHECK (requested_amount > 0)
);

CREATE INDEX idx_loan_application_customer_id ON loan_application(customer_id);
CREATE INDEX idx_loan_application_asset_id ON loan_application(asset_id);
CREATE INDEX idx_loan_application_current_state_id ON loan_application(current_state_id);

-- Business rule:
-- One asset must not be used by more than one open loan application at the same time.
-- A loan application is considered open when closed_at IS NULL and deleted_at IS NULL.
CREATE UNIQUE INDEX uq_active_loan_application_asset
ON loan_application(asset_id)
WHERE closed_at IS NULL AND deleted_at IS NULL;

-- =========================================================
-- 5. Loan application state transition
-- =========================================================

CREATE TABLE loan_application_state_transition (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    from_state_id UUID NOT NULL,
    to_state_id UUID NOT NULL,

    action_code VARCHAR(50) NOT NULL,
    action_name VARCHAR(100) NOT NULL,
    description TEXT,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_loan_application_transition_from_state FOREIGN KEY (from_state_id) REFERENCES loan_application_state(id),
    CONSTRAINT fk_loan_application_transition_to_state FOREIGN KEY (to_state_id) REFERENCES loan_application_state(id),
    CONSTRAINT uq_loan_application_state_transition UNIQUE (from_state_id, to_state_id, action_code),
    CONSTRAINT chk_loan_application_transition_not_self CHECK (from_state_id <> to_state_id)
);

CREATE INDEX idx_loan_application_transition_from_state ON loan_application_state_transition(from_state_id);
CREATE INDEX idx_loan_application_transition_to_state ON loan_application_state_transition(to_state_id);

-- =========================================================
-- 6. Loan application state history
-- =========================================================

CREATE TABLE loan_application_state_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    loan_application_id UUID NOT NULL,
    from_state_id UUID,
    to_state_id UUID NOT NULL,

    action_code VARCHAR(50) NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(100),
    note TEXT,

    CONSTRAINT fk_loan_application_history_application FOREIGN KEY (loan_application_id) REFERENCES loan_application(id),
    CONSTRAINT fk_loan_application_history_from_state FOREIGN KEY (from_state_id) REFERENCES loan_application_state(id),
    CONSTRAINT fk_loan_application_history_to_state FOREIGN KEY (to_state_id) REFERENCES loan_application_state(id),
    CONSTRAINT chk_loan_application_history_not_self CHECK (
        from_state_id IS NULL OR from_state_id <> to_state_id
    )
);

CREATE INDEX idx_loan_application_history_application_changed_at
ON loan_application_state_history(loan_application_id, changed_at);

CREATE INDEX idx_loan_application_history_from_state ON loan_application_state_history(from_state_id);
CREATE INDEX idx_loan_application_history_to_state ON loan_application_state_history(to_state_id);
