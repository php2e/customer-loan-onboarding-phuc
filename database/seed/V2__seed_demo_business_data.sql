-- Customer Loan Onboarding - Demo Business Data Seed
-- PostgreSQL dialect
--
-- Purpose:
-- Insert demo business data only. This file assumes V1 reference seed
-- has already inserted loan_application_state and loan_application_state_transition.
--
-- Data included:
-- - demo customers
-- - demo vehicle assets
-- - demo loan applications
-- - demo loan application state history
--
-- Notes:
-- - id is the technical primary key used for foreign keys.
-- - *_code is the business code used for lookup/display.
-- - This seed is re-runnable where possible using ON CONFLICT DO NOTHING.

-- =========================================================
-- 1. Demo customers
-- =========================================================
-- Customer status:
-- ACTIVE     : khách hàng đang hoạt động
-- INACTIVE   : khách hàng không còn hoạt động
-- RESTRICTED : khách hàng bị hạn chế, ví dụ nằm trong blacklist/cần kiểm tra

INSERT INTO customer
(id, customer_code, full_name, phone_number, identity_number, date_of_birth, status, created_at, updated_at)
VALUES
(
    '10000000-0000-0000-0000-000000000001',
    'CUS-000001',
    'Nguyễn Văn An',
    '0901000001',
    '001201000001',
    DATE '1995-01-15',
    'ACTIVE',
    TIMESTAMP '2026-06-01 09:00:00',
    TIMESTAMP '2026-06-01 09:00:00'
),
(
    '10000000-0000-0000-0000-000000000002',
    'CUS-000002',
    'Trần Thị Bình',
    '0901000002',
    '001201000002',
    DATE '1992-08-20',
    'ACTIVE',
    TIMESTAMP '2026-06-02 09:00:00',
    TIMESTAMP '2026-06-02 09:00:00'
),
(
    '10000000-0000-0000-0000-000000000003',
    'CUS-000003',
    'Lê Minh Cường',
    '0901000003',
    '001201000003',
    DATE '1988-12-05',
    'RESTRICTED',
    TIMESTAMP '2026-06-03 09:00:00',
    TIMESTAMP '2026-06-03 09:00:00'
),
(
    '10000000-0000-0000-0000-000000000004',
    'CUS-000004',
    'Phạm Thu Dung',
    '0901000004',
    '001201000004',
    DATE '1999-03-11',
    'INACTIVE',
    TIMESTAMP '2026-06-04 09:00:00',
    TIMESTAMP '2026-06-04 09:00:00'
),
(
    '10000000-0000-0000-0000-000000000005',
    'CUS-000005',
    'Hoàng Đức Huy',
    '0901000005',
    '001201000005',
    DATE '1990-10-25',
    'ACTIVE',
    TIMESTAMP '2026-06-05 09:00:00',
    TIMESTAMP '2026-06-05 09:00:00'
),
(
    '10000000-0000-0000-0000-000000000006',
    'CUS-000006',
    'Nguyễn Thị Hạnh',
    '0901000006',
    '001201000006',
    DATE '1997-07-07',
    'ACTIVE',
    TIMESTAMP '2026-06-06 09:00:00',
    TIMESTAMP '2026-06-06 09:00:00'
)
ON CONFLICT (customer_code) DO NOTHING;

-- =========================================================
-- 2. Demo assets
-- =========================================================
-- Asset status:
-- AVAILABLE : tài sản sẵn sàng, chưa bị cầm cố trong hồ sơ đang mở
-- PLEDGED   : tài sản đang được cầm cố trong một hồ sơ đang mở
-- RELEASED  : tài sản đã giải chấp

INSERT INTO asset
(id, asset_code, customer_id, license_plate, vehicle_brand, vehicle_model, vehicle_version, manufacture_year, status, created_at, updated_at)
VALUES
(
    '20000000-0000-0000-0000-000000000001',
    'AST-000001',
    '10000000-0000-0000-0000-000000000001',
    '30A-12345',
    'Toyota',
    'Vios',
    '1.5G CVT',
    2020,
    'PLEDGED',
    TIMESTAMP '2026-06-01 09:10:00',
    TIMESTAMP '2026-06-10 10:30:00'
),
(
    '20000000-0000-0000-0000-000000000002',
    'AST-000002',
    '10000000-0000-0000-0000-000000000001',
    '29B-67890',
    'Honda',
    'SH',
    '150i ABS',
    2022,
    'AVAILABLE',
    TIMESTAMP '2026-06-01 09:15:00',
    TIMESTAMP '2026-06-01 09:15:00'
),
(
    '20000000-0000-0000-0000-000000000003',
    'AST-000003',
    '10000000-0000-0000-0000-000000000002',
    '30G-24680',
    'Hyundai',
    'Accent',
    '1.4 AT',
    2021,
    'RELEASED',
    TIMESTAMP '2026-06-02 09:10:00',
    TIMESTAMP '2026-06-13 16:30:00'
),
(
    '20000000-0000-0000-0000-000000000004',
    'AST-000004',
    '10000000-0000-0000-0000-000000000005',
    '30H-13579',
    'Mazda',
    'CX-5',
    '2.0 Luxury',
    2019,
    'PLEDGED',
    TIMESTAMP '2026-06-05 09:10:00',
    TIMESTAMP '2026-06-15 13:20:00'
),
(
    '20000000-0000-0000-0000-000000000005',
    'AST-000005',
    '10000000-0000-0000-0000-000000000005',
    '29C-11223',
    'Yamaha',
    'Exciter',
    '155 VVA',
    2023,
    'RELEASED',
    TIMESTAMP '2026-06-05 09:20:00',
    TIMESTAMP '2026-06-14 10:30:00'
),
(
    '20000000-0000-0000-0000-000000000006',
    'AST-000006',
    '10000000-0000-0000-0000-000000000006',
    '30K-88888',
    'Kia',
    'Morning',
    '1.25 AT',
    2018,
    'AVAILABLE',
    TIMESTAMP '2026-06-06 09:10:00',
    TIMESTAMP '2026-06-06 09:10:00'
)
ON CONFLICT (asset_code) DO NOTHING;

-- =========================================================
-- 3. Demo loan applications
-- =========================================================
-- current_state_id stores the current lifecycle state of the application.
-- closed_at is set when the application reaches a terminal state.
--
-- Demo cases:
-- LA-000001: active application in review, asset is pledged.
-- LA-000002: draft application, asset is selected but still available.
-- LA-000003: contracted application, closed.
-- LA-000004: cancelled application, closed.
-- LA-000005: application needs supplement.

INSERT INTO loan_application
(
    id,
    loan_application_code,
    customer_id,
    asset_id,
    current_state_id,
    requested_amount,
    loan_purpose,
    submitted_at,
    closed_at,
    created_at,
    updated_at
)
VALUES
(
    '30000000-0000-0000-0000-000000000001',
    'LA-000001',
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000104', -- APP_IN_REVIEW
    50000000.00,
    'Vay cầm cố xe ô tô phục vụ nhu cầu cá nhân.',
    TIMESTAMP '2026-06-10 10:30:00',
    NULL,
    TIMESTAMP '2026-06-10 10:00:00',
    TIMESTAMP '2026-06-10 11:00:00'
),
(
    '30000000-0000-0000-0000-000000000002',
    'LA-000002',
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000101', -- APP_DRAFT
    20000000.00,
    'Hồ sơ nháp cho khoản vay cầm cố xe máy.',
    NULL,
    NULL,
    TIMESTAMP '2026-06-11 11:00:00',
    TIMESTAMP '2026-06-11 11:00:00'
),
(
    '30000000-0000-0000-0000-000000000003',
    'LA-000003',
    '10000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000106', -- APP_CONTRACTED
    70000000.00,
    'Hồ sơ đã hoàn tất hợp đồng.',
    TIMESTAMP '2026-06-12 14:15:00',
    TIMESTAMP '2026-06-13 16:30:00',
    TIMESTAMP '2026-06-12 14:00:00',
    TIMESTAMP '2026-06-13 16:30:00'
),
(
    '30000000-0000-0000-0000-000000000004',
    'LA-000004',
    '10000000-0000-0000-0000-000000000005',
    '20000000-0000-0000-0000-000000000005',
    '00000000-0000-0000-0000-000000000107', -- APP_CANCELLED
    15000000.00,
    'Hồ sơ bị hủy trước khi lập hợp đồng.',
    TIMESTAMP '2026-06-14 09:30:00',
    TIMESTAMP '2026-06-14 10:30:00',
    TIMESTAMP '2026-06-14 09:00:00',
    TIMESTAMP '2026-06-14 10:30:00'
),
(
    '30000000-0000-0000-0000-000000000005',
    'LA-000005',
    '10000000-0000-0000-0000-000000000005',
    '20000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000103', -- APP_NEEDS_SUPPLEMENT
    90000000.00,
    'Hồ sơ cần bổ sung giấy tờ.',
    TIMESTAMP '2026-06-15 13:20:00',
    NULL,
    TIMESTAMP '2026-06-15 13:00:00',
    TIMESTAMP '2026-06-15 14:00:00'
)
ON CONFLICT (loan_application_code) DO NOTHING;

-- =========================================================
-- 4. Demo loan application state history
-- =========================================================
-- This table records actual state movements of each loan application.
-- It is used for lifecycle audit and timeline display.

INSERT INTO loan_application_state_history
(
    id,
    loan_application_id,
    from_state_id,
    to_state_id,
    action_code,
    changed_at,
    changed_by,
    note
)
VALUES
-- LA-000001: DRAFT -> SUBMITTED -> IN_REVIEW
(
    '40000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    NULL,
    '00000000-0000-0000-0000-000000000101',
    'CREATE',
    TIMESTAMP '2026-06-10 10:00:00',
    'staff_001',
    'Tạo hồ sơ vay nháp.'
),
(
    '40000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000102',
    'SUBMIT',
    TIMESTAMP '2026-06-10 10:30:00',
    'staff_001',
    'Nộp hồ sơ vào luồng xử lý.'
),
(
    '40000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000104',
    'START_REVIEW',
    TIMESTAMP '2026-06-10 11:00:00',
    'staff_002',
    'Bắt đầu thẩm định/phê duyệt.'
),

-- LA-000002: DRAFT only
(
    '40000000-0000-0000-0000-000000000004',
    '30000000-0000-0000-0000-000000000002',
    NULL,
    '00000000-0000-0000-0000-000000000101',
    'CREATE',
    TIMESTAMP '2026-06-11 11:00:00',
    'staff_001',
    'Tạo hồ sơ nháp.'
),

-- LA-000003: DRAFT -> SUBMITTED -> IN_REVIEW -> READY_FOR_CONTRACT -> CONTRACTED
(
    '40000000-0000-0000-0000-000000000005',
    '30000000-0000-0000-0000-000000000003',
    NULL,
    '00000000-0000-0000-0000-000000000101',
    'CREATE',
    TIMESTAMP '2026-06-12 14:00:00',
    'staff_003',
    'Tạo hồ sơ vay nháp.'
),
(
    '40000000-0000-0000-0000-000000000006',
    '30000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000102',
    'SUBMIT',
    TIMESTAMP '2026-06-12 14:15:00',
    'staff_003',
    'Nộp hồ sơ.'
),
(
    '40000000-0000-0000-0000-000000000007',
    '30000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000104',
    'START_REVIEW',
    TIMESTAMP '2026-06-12 15:00:00',
    'staff_004',
    'Bắt đầu thẩm định/phê duyệt.'
),
(
    '40000000-0000-0000-0000-000000000008',
    '30000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000104',
    '00000000-0000-0000-0000-000000000105',
    'APPROVE_FOR_CONTRACT',
    TIMESTAMP '2026-06-13 09:00:00',
    'staff_004',
    'Duyệt lập hợp đồng.'
),
(
    '40000000-0000-0000-0000-000000000009',
    '30000000-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000105',
    '00000000-0000-0000-0000-000000000106',
    'CREATE_CONTRACT',
    TIMESTAMP '2026-06-13 16:30:00',
    'staff_005',
    'Tạo hợp đồng thành công.'
),

-- LA-000004: DRAFT -> SUBMITTED -> CANCELLED
(
    '40000000-0000-0000-0000-000000000010',
    '30000000-0000-0000-0000-000000000004',
    NULL,
    '00000000-0000-0000-0000-000000000101',
    'CREATE',
    TIMESTAMP '2026-06-14 09:00:00',
    'staff_001',
    'Tạo hồ sơ.'
),
(
    '40000000-0000-0000-0000-000000000011',
    '30000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000102',
    'SUBMIT',
    TIMESTAMP '2026-06-14 09:30:00',
    'staff_001',
    'Nộp hồ sơ.'
),
(
    '40000000-0000-0000-0000-000000000012',
    '30000000-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000107',
    'CANCEL',
    TIMESTAMP '2026-06-14 10:30:00',
    'staff_001',
    'Khách hàng không tiếp tục nhu cầu vay.'
),

-- LA-000005: DRAFT -> SUBMITTED -> NEEDS_SUPPLEMENT
(
    '40000000-0000-0000-0000-000000000013',
    '30000000-0000-0000-0000-000000000005',
    NULL,
    '00000000-0000-0000-0000-000000000101',
    'CREATE',
    TIMESTAMP '2026-06-15 13:00:00',
    'staff_006',
    'Tạo hồ sơ.'
),
(
    '40000000-0000-0000-0000-000000000014',
    '30000000-0000-0000-0000-000000000005',
    '00000000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000102',
    'SUBMIT',
    TIMESTAMP '2026-06-15 13:20:00',
    'staff_006',
    'Nộp hồ sơ.'
),
(
    '40000000-0000-0000-0000-000000000015',
    '30000000-0000-0000-0000-000000000005',
    '00000000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000103',
    'REQUEST_SUPPLEMENT',
    TIMESTAMP '2026-06-15 14:00:00',
    'staff_007',
    'Thiếu giấy tờ xác minh thông tin xe.'
)
ON CONFLICT (id) DO NOTHING;
