# Lifecycle hồ sơ vay

## 1. Mục tiêu thiết kế

Lifecycle trong phạm vi này chỉ áp dụng cho `loan_application`.

Customer và Asset có `status` riêng nhưng không có lifecycle history. Lý do là module hiện tại xoay quanh hồ sơ vay, không phải hệ thống quản lý khách hàng hoặc quản lý tài sản đầy đủ.

Thiết kế lifecycle cần trả lời bốn câu hỏi:

1. Hồ sơ vay hiện tại đang ở state nào?
2. State nào là state bắt đầu?
3. State nào là state kết thúc?
4. Hồ sơ đã chuyển từ state nào sang state nào, vào thời điểm nào?

Để trả lời các câu hỏi này, hệ thống dùng bốn điểm lưu trữ:

| Nhu cầu | Nơi lưu |
|---|---|
| State hiện tại của hồ sơ | `loan_application.current_state_id` |
| Danh sách state hợp lệ | `loan_application_state` |
| State nào được phép chuyển sang state nào | `loan_application_state_transition` |
| Lịch sử chuyển state thực tế | `loan_application_state_history` |

---

## 2. Lý do không dùng bảng state chung toàn hệ thống

Không dùng bảng `state_master` chung cho Customer, Asset và Loan Application ở giai đoạn này.

Customer và Asset chỉ cần status đơn giản:

- `customer.status`: `ACTIVE`, `INACTIVE`, `RESTRICTED`
- `asset.status`: `AVAILABLE`, `PLEDGED`, `RELEASED`

Các status này không cần history, không cần transition, không cần xác định initial/terminal. Nếu đưa tất cả vào một bảng state chung, thiết kế sẽ phải thêm `object_type`, `domain`, `is_initial`, `is_terminal`, `sort_order`, transition theo từng object. Điều đó làm mô hình lớn hơn nhu cầu hiện tại.

Vì vậy, chỉ `loan_application` có bộ bảng lifecycle riêng.

---

## 3. Danh sách state của hồ sơ vay

| Code | Tên nghiệp vụ | Loại state | Mô tả |
|---|---|---|---|
| `APP_DRAFT` | Hồ sơ nháp | Initial | Hồ sơ mới được tạo, chưa nộp vào luồng xử lý |
| `APP_SUBMITTED` | Đã nộp hồ sơ | Intermediate | Hồ sơ đã được gửi để xử lý |
| `APP_NEEDS_SUPPLEMENT` | Cần bổ sung hồ sơ | Intermediate | Hồ sơ thiếu thông tin hoặc giấy tờ |
| `APP_IN_REVIEW` | Đang thẩm định/phê duyệt | Intermediate | Hồ sơ đang được kiểm tra, đánh giá |
| `APP_READY_FOR_CONTRACT` | Sẵn sàng lập hợp đồng | Intermediate | Hồ sơ đã đủ điều kiện để tạo hợp đồng |
| `APP_CONTRACTED` | Đã có hợp đồng | Terminal | Hồ sơ đã tạo hợp đồng, kết thúc lifecycle hồ sơ vay trong module hiện tại |
| `APP_CANCELLED` | Hồ sơ bị hủy | Terminal | Hồ sơ bị hủy và không tiếp tục xử lý |

Quy ước:

- Initial state là state đầu tiên khi tạo hồ sơ.
- Terminal state là state kết thúc. Khi hồ sơ đã vào terminal state, không nên chuyển tiếp sang state khác trong phạm vi hiện tại.

---

## 4. Luồng chuyển state hợp lệ

```text
APP_DRAFT
  ├── SUBMIT ───────────────> APP_SUBMITTED
  └── CANCEL ───────────────> APP_CANCELLED

APP_SUBMITTED
  ├── START_REVIEW ─────────> APP_IN_REVIEW
  ├── REQUEST_SUPPLEMENT ───> APP_NEEDS_SUPPLEMENT
  └── CANCEL ───────────────> APP_CANCELLED

APP_NEEDS_SUPPLEMENT
  └── RESUBMIT ─────────────> APP_SUBMITTED

APP_IN_REVIEW
  ├── REQUEST_SUPPLEMENT ───> APP_NEEDS_SUPPLEMENT
  └── APPROVE_FOR_CONTRACT ─> APP_READY_FOR_CONTRACT

APP_READY_FOR_CONTRACT
  ├── CREATE_CONTRACT ──────> APP_CONTRACTED
  └── CANCEL ───────────────> APP_CANCELLED
```

---

## 5. Vai trò của từng bảng trong lifecycle

### 5.1. `loan_application.current_state_id`

Cột này lưu state hiện tại của hồ sơ vay.

Ví dụ:

| loan_application_code | current_state |
|---|---|
| `LA-000001` | `APP_DRAFT` |
| `LA-000002` | `APP_IN_REVIEW` |
| `LA-000003` | `APP_CONTRACTED` |

Đây là nơi backend dùng để truy vấn nhanh danh sách hồ sơ theo trạng thái hiện tại.

Ví dụ:

```sql
SELECT la.*
FROM loan_application la
JOIN loan_application_state s ON s.id = la.current_state_id
WHERE s.code = 'APP_IN_REVIEW';
```

### 5.2. `loan_application_state`

Bảng này là danh mục state hợp lệ của hồ sơ vay.

Bảng này không lưu lịch sử. Nó chỉ trả lời: hệ thống có những state nào, state nào là state đầu, state nào là state cuối.

### 5.3. `loan_application_state_transition`

Bảng này định nghĩa state nào được phép chuyển sang state nào.

Khi nhận yêu cầu chuyển trạng thái, backend không nên update trực tiếp `current_state_id` theo ý client. Backend cần kiểm tra transition có tồn tại hay không.

Ví dụ yêu cầu hợp lệ:

```text
APP_DRAFT -> APP_SUBMITTED
```

Ví dụ yêu cầu không hợp lệ:

```text
APP_DRAFT -> APP_CONTRACTED
```

Vì không có transition này trong bảng `loan_application_state_transition`, backend phải từ chối.

### 5.4. `loan_application_state_history`

Bảng này lưu sự kiện chuyển state đã xảy ra.

Mỗi lần state thay đổi, hệ thống insert một dòng history. Dòng history ghi lại:

- hồ sơ nào được chuyển
- từ state nào
- sang state nào
- action nào gây ra chuyển state
- chuyển lúc nào
- ai thực hiện hoặc hệ thống nào thực hiện
- ghi chú nếu có

---

## 6. Quy trình chuyển state khuyến nghị cho backend

Backend nên xử lý chuyển state trong một database transaction.

Quy trình:

1. Lock hoặc đọc hồ sơ vay cần chuyển state.
2. Lấy `current_state_id` hiện tại của hồ sơ.
3. Tìm transition trong `loan_application_state_transition` theo `from_state_id`, `to_state_id`, `action_code`.
4. Nếu không có transition, từ chối yêu cầu.
5. Update `loan_application.current_state_id` sang state mới.
6. Nếu state mới là terminal state, update `loan_application.closed_at = now()`.
7. Insert một dòng vào `loan_application_state_history`.
8. Commit transaction.

Pseudo flow:

```text
current_state = loan_application.current_state_id
requested_state = input.to_state_id
action = input.action_code

if transition(current_state, requested_state, action) does not exist:
    reject

update loan_application.current_state_id = requested_state
insert loan_application_state_history
```

---

## 7. Liên hệ giữa lifecycle hồ sơ vay và trạng thái tài sản

Asset không có lifecycle riêng, nhưng trạng thái asset có liên quan đến hồ sơ vay.

Quy tắc cơ bản:

- Khi gắn asset vào hồ sơ vay, asset nên đang ở `AVAILABLE`.
- Khi hồ sơ vay được đưa vào quá trình cầm cố/hợp đồng, asset có thể chuyển sang `PLEDGED`.
- Khi hồ sơ kết thúc và tài sản được giải chấp, asset có thể chuyển sang `RELEASED` hoặc `AVAILABLE` tùy cách định nghĩa nghiệp vụ sau này.

Trong thiết kế hiện tại, database hỗ trợ kiểm soát việc một asset không được nằm trong nhiều hồ sơ vay đang mở bằng partial unique index:

```sql
CREATE UNIQUE INDEX uq_active_loan_application_asset
ON loan_application(asset_id)
WHERE closed_at IS NULL AND deleted_at IS NULL;
```

Điều này có nghĩa là một `asset_id` chỉ được xuất hiện một lần trong các hồ sơ chưa đóng.

---

## 8. Ghi chú triển khai

Thiết kế hiện tại cố ý giữ đơn giản:

- Không có `stage`.
- Không có state dùng chung cho toàn hệ thống.
- Không có lifecycle cho Customer.
- Không có lifecycle cho Asset.
- Không có bảng audit tổng quát.

Nếu sau này nghiệp vụ lớn hơn, có thể mở rộng thêm:

- `asset_state_history`
- `customer_status_history`
- `loan_application_stage`
- rule engine để validate transition
- bảng actor/user riêng thay cho `changed_by` dạng text

