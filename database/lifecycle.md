# Loan Application Lifecycle

## 1. Mục tiêu thiết kế

Lifecycle của `loan_application` được thiết kế để trả lời các câu hỏi sau:

- Hồ sơ vay hiện tại đang ở state nào?
- State nào là state bắt đầu?
- State nào là state kết thúc?
- Từ state hiện tại, hồ sơ được phép chuyển sang state nào?
- Hồ sơ đã chuyển state lúc nào, bởi ai, với hành động gì?

Thiết kế hiện tại dùng 4 bảng:

| Bảng | Vai trò |
|---|---|
| `loan_application` | Lưu hồ sơ vay và state hiện tại. |
| `loan_application_state` | Lưu danh mục state hợp lệ. |
| `loan_application_state_transition` | Lưu các transition hợp lệ giữa các state. |
| `loan_application_state_history` | Lưu lịch sử chuyển state của từng hồ sơ. |

---

## 2. Nguyên tắc thiết kế

### 2.1. State hiện tại nằm trong `loan_application`

`loan_application.current_state_id` là nguồn chính để biết hồ sơ hiện đang ở đâu.

Ví dụ:

```text
APP-2026-000001 -> current_state = APP_IN_REVIEW
```

### 2.2. Danh mục state không thay đổi theo từng hồ sơ

`loan_application_state` là bảng reference/master data. Khi tạo hồ sơ mới, hệ thống không insert thêm state mới vào bảng này.

Bảng này chỉ thay đổi khi thay đổi thiết kế lifecycle của hệ thống, ví dụ thêm state mới.

### 2.3. Transition là cấu hình đường đi hợp lệ

`loan_application_state_transition` không ghi nhận sự kiện thực tế. Bảng này chỉ định nghĩa từ state nào có thể đi sang state nào.

Ví dụ:

```text
APP_DRAFT -> APP_SUBMITTED bằng action SUBMIT
APP_DRAFT -> APP_CANCELLED bằng action CANCEL
```

### 2.4. History là audit lifecycle

`loan_application_state_history` ghi lại sự kiện thực tế đã xảy ra với từng hồ sơ.

Ví dụ:

```text
APP-2026-000001: NULL -> APP_DRAFT, action CREATE, 2026-06-10 10:00:00
APP-2026-000001: APP_DRAFT -> APP_SUBMITTED, action SUBMIT, 2026-06-10 10:30:00
```

---

## 3. Danh sách state

| Code | Tên | Initial | Terminal | Ý nghĩa |
|---|---|---:|---:|---|
| `APP_DRAFT` | Hồ sơ nháp | Yes | No | Hồ sơ mới được tạo, chưa nộp vào luồng xử lý. |
| `APP_SUBMITTED` | Đã nộp hồ sơ | No | No | Hồ sơ đã được gửi vào luồng xử lý. |
| `APP_NEEDS_SUPPLEMENT` | Cần bổ sung hồ sơ | No | No | Hồ sơ thiếu thông tin hoặc giấy tờ và cần bổ sung. |
| `APP_IN_REVIEW` | Đang thẩm định/phê duyệt | No | No | Hồ sơ đang được kiểm tra, thẩm định hoặc phê duyệt. |
| `APP_READY_FOR_CONTRACT` | Sẵn sàng lập hợp đồng | No | No | Hồ sơ đủ điều kiện để chuyển sang bước lập hợp đồng. |
| `APP_CONTRACTED` | Đã có hợp đồng | No | Yes | Hồ sơ đã được tạo hợp đồng, kết thúc lifecycle trong module hiện tại. |
| `APP_CANCELLED` | Hồ sơ bị hủy | No | Yes | Hồ sơ bị hủy và không tiếp tục xử lý. |

---

## 4. Transition hợp lệ

| From state | Action | To state | Ý nghĩa |
|---|---|---|---|
| `APP_DRAFT` | `SUBMIT` | `APP_SUBMITTED` | Nộp hồ sơ nháp vào luồng xử lý. |
| `APP_DRAFT` | `CANCEL` | `APP_CANCELLED` | Hủy hồ sơ khi còn nháp. |
| `APP_SUBMITTED` | `START_REVIEW` | `APP_IN_REVIEW` | Bắt đầu thẩm định/phê duyệt. |
| `APP_SUBMITTED` | `REQUEST_SUPPLEMENT` | `APP_NEEDS_SUPPLEMENT` | Yêu cầu bổ sung sau khi hồ sơ đã nộp. |
| `APP_SUBMITTED` | `CANCEL` | `APP_CANCELLED` | Hủy hồ sơ sau khi đã nộp. |
| `APP_NEEDS_SUPPLEMENT` | `RESUBMIT` | `APP_SUBMITTED` | Nộp lại sau khi bổ sung. |
| `APP_IN_REVIEW` | `REQUEST_SUPPLEMENT` | `APP_NEEDS_SUPPLEMENT` | Yêu cầu bổ sung trong quá trình review. |
| `APP_IN_REVIEW` | `DRAFT_CONTRACT` | `APP_READY_FOR_CONTRACT` | Chuyển sang bước lập hợp đồng. |
| `APP_READY_FOR_CONTRACT` | `CREATE_CONTRACT` | `APP_CONTRACTED` | Tạo hợp đồng từ hồ sơ vay. |
| `APP_READY_FOR_CONTRACT` | `CANCEL` | `APP_CANCELLED` | Hủy hồ sơ trước khi lập hợp đồng. |

---

## 5. Tạo hồ sơ vay lần đầu

Khi tạo hồ sơ vay mới, backend thực hiện các bước sau:

1. Tìm state khởi tạo trong `loan_application_state`:

```sql
SELECT id
FROM loan_application_state
WHERE is_initial = TRUE;
```

2. Insert record vào `loan_application` với:

```text
current_state_id = APP_DRAFT
requested_amount = NULL hoặc giá trị do người dùng nhập
```

3. Insert một record vào `loan_application_state_history`:

```text
from_state_id = NULL
to_state_id = APP_DRAFT
action_code = CREATE
changed_at = thời điểm tạo hồ sơ
changed_by = nhân viên tạo hồ sơ
```

Lưu ý: khi tạo hồ sơ mới, không insert dữ liệu vào `loan_application_state` và `loan_application_state_transition` vì hai bảng này là dữ liệu cấu hình đã seed sẵn.

---

## 6. Chuyển state sau khi hồ sơ đã tồn tại

Khi người dùng thực hiện một hành động như `SUBMIT`, backend nên xử lý theo quy trình:

1. Đọc `loan_application.current_state_id` để biết state hiện tại.
2. Kiểm tra trong `loan_application_state_transition` xem transition có hợp lệ không.
3. Nếu hợp lệ:
   - update `loan_application.current_state_id` sang state mới;
   - insert một dòng vào `loan_application_state_history`.
4. Nếu không hợp lệ:
   - từ chối thao tác và trả lỗi nghiệp vụ.

Ví dụ với action `SUBMIT`:

```text
Current state: APP_DRAFT
Action: SUBMIT
Allowed transition: APP_DRAFT -> APP_SUBMITTED
```

Sau khi xử lý:

```text
loan_application.current_state_id = APP_SUBMITTED
history: APP_DRAFT -> APP_SUBMITTED, action SUBMIT
```

---

## 7. Ghi chú về audit

Phiên bản này dùng `loan_application_state_history` để audit lifecycle event, bao gồm:

- thời điểm tạo hồ sơ;
- thời điểm nộp hồ sơ;
- thời điểm yêu cầu bổ sung;
- thời điểm bắt đầu review;
- thời điểm hủy hoặc tạo hợp đồng.

Bảng history này không audit mọi thay đổi field trong `loan_application`. Nếu sau này cần biết ai thay đổi `requested_amount` hoặc `loan_purpose`, cần bổ sung cơ chế audit riêng.
