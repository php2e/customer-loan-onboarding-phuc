-- Customer Loan Onboarding - Reference Data Seed
-- PostgreSQL dialect
-- This seed inserts loan application lifecycle states and allowed transitions.
-- It does not insert demo business data.

-- =========================================================
-- 1. Loan application states
-- =========================================================

INSERT INTO loan_application_state
(id, code, name, description, is_initial, is_terminal, sort_order)
VALUES
('00000000-0000-0000-0000-000000000101', 'APP_DRAFT', 'Hồ sơ nháp', 'Hồ sơ mới được tạo, chưa nộp vào luồng xử lý.', TRUE, FALSE, 1),
('00000000-0000-0000-0000-000000000102', 'APP_SUBMITTED', 'Đã nộp hồ sơ', 'Hồ sơ đã được gửi vào luồng xử lý.', FALSE, FALSE, 2),
('00000000-0000-0000-0000-000000000103', 'APP_NEEDS_SUPPLEMENT', 'Cần bổ sung hồ sơ', 'Hồ sơ thiếu thông tin hoặc giấy tờ và cần được bổ sung.', FALSE, FALSE, 3),
('00000000-0000-0000-0000-000000000104', 'APP_IN_REVIEW', 'Đang thẩm định/phê duyệt', 'Hồ sơ đang được kiểm tra, thẩm định hoặc phê duyệt.', FALSE, FALSE, 4),
('00000000-0000-0000-0000-000000000105', 'APP_READY_FOR_CONTRACT', 'Sẵn sàng lập hợp đồng', 'Hồ sơ đã đủ điều kiện để tạo hợp đồng.', FALSE, FALSE, 5),
('00000000-0000-0000-0000-000000000106', 'APP_CONTRACTED', 'Đã có hợp đồng', 'Hồ sơ đã được tạo hợp đồng và kết thúc lifecycle trong module hiện tại.', FALSE, TRUE, 6),
('00000000-0000-0000-0000-000000000107', 'APP_CANCELLED', 'Hồ sơ bị hủy', 'Hồ sơ bị hủy và không tiếp tục xử lý.', FALSE, TRUE, 7)
ON CONFLICT (code) DO NOTHING;

-- =========================================================
-- 2. Loan application allowed transitions
-- =========================================================

INSERT INTO loan_application_state_transition
(id, from_state_id, to_state_id, action_code, action_name, description)
VALUES
(
    '00000000-0000-0000-0000-000000000201',
    '00000000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000102',
    'SUBMIT',
    'Nộp hồ sơ',
    'Nộp hồ sơ nháp vào luồng xử lý.'
),
(
    '00000000-0000-0000-0000-000000000202',
    '00000000-0000-0000-0000-000000000101',
    '00000000-0000-0000-0000-000000000107',
    'CANCEL',
    'Hủy hồ sơ',
    'Hủy hồ sơ khi hồ sơ còn ở trạng thái nháp.'
),
(
    '00000000-0000-0000-0000-000000000203',
    '00000000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000104',
    'START_REVIEW',
    'Bắt đầu thẩm định/phê duyệt',
    'Chuyển hồ sơ đã nộp sang bước thẩm định/phê duyệt.'
),
(
    '00000000-0000-0000-0000-000000000204',
    '00000000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000103',
    'REQUEST_SUPPLEMENT',
    'Yêu cầu bổ sung hồ sơ',
    'Yêu cầu bổ sung thông tin hoặc giấy tờ sau khi hồ sơ đã nộp.'
),
(
    '00000000-0000-0000-0000-000000000205',
    '00000000-0000-0000-0000-000000000102',
    '00000000-0000-0000-0000-000000000107',
    'CANCEL',
    'Hủy hồ sơ',
    'Hủy hồ sơ sau khi đã nộp.'
),
(
    '00000000-0000-0000-0000-000000000206',
    '00000000-0000-0000-0000-000000000103',
    '00000000-0000-0000-0000-000000000102',
    'RESUBMIT',
    'Nộp lại hồ sơ',
    'Nộp lại hồ sơ sau khi đã bổ sung thông tin hoặc giấy tờ.'
),
(
    '00000000-0000-0000-0000-000000000207',
    '00000000-0000-0000-0000-000000000104',
    '00000000-0000-0000-0000-000000000103',
    'REQUEST_SUPPLEMENT',
    'Yêu cầu bổ sung hồ sơ',
    'Yêu cầu bổ sung thông tin hoặc giấy tờ trong quá trình thẩm định/phê duyệt.'
),
(
    '00000000-0000-0000-0000-000000000208',
    '00000000-0000-0000-0000-000000000104',
    '00000000-0000-0000-0000-000000000105',
    'DRAFT_CONTRACT',
    'Chuyển sang lập hợp đồng',
    'Hồ sơ đủ điều kiện để chuyển sang bước lập hợp đồng.'
),
(
    '00000000-0000-0000-0000-000000000209',
    '00000000-0000-0000-0000-000000000105',
    '00000000-0000-0000-0000-000000000106',
    'CREATE_CONTRACT',
    'Tạo hợp đồng',
    'Tạo hợp đồng từ hồ sơ vay đã đủ điều kiện.'
),
(
    '00000000-0000-0000-0000-000000000210',
    '00000000-0000-0000-0000-000000000105',
    '00000000-0000-0000-0000-000000000107',
    'CANCEL',
    'Hủy hồ sơ',
    'Hủy hồ sơ trước khi lập hợp đồng.'
)
ON CONFLICT (from_state_id, to_state_id, action_code) DO NOTHING;
