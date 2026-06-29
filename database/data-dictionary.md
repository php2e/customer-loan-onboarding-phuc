# Data Dictionary - Customer Loan Onboarding

## 1. Mục đích tài liệu

Tài liệu này mô tả các object, bảng vật lý, field, constraint và quan hệ dữ liệu của schema hiện tại.

Phiên bản này chỉ tập trung vào:

- `customer`: thông tin khách hàng cơ bản;
- `loan_application`: hồ sơ vay;
- lifecycle của `loan_application`.

Bảng `asset` được tạm thời loại khỏi schema ở phiên bản này. Vì vậy `loan_application` chưa có `asset_id`.

---

# 2. Object: Customer

## 2.1. Ý nghĩa

`Customer` đại diện cho khách hàng trong hệ thống. Ở scope hiện tại, khách hàng được lưu để phục vụ tra cứu và tạo hồ sơ vay. Hệ thống chưa quản lý lifecycle riêng cho khách hàng.

## 2.2. Bảng vật lý

`customer`

## 2.3. Field dictionary

| Column | Type | Required | Constraint | Ý nghĩa | Ví dụ |
|---|---|---:|---|---|---|
| `id` | `uuid` | Yes | Primary key, default `gen_random_uuid()` | Khóa kỹ thuật dùng để liên kết trong database. Không dùng làm mã tra cứu nghiệp vụ. | `10000000-0000-0000-0000-000000000001` |
| `customer_code` | `varchar(50)` | Yes | Unique | Mã nghiệp vụ của khách hàng, dùng để hiển thị/tra cứu. | `CUS-2026-000001` |
| `full_name` | `varchar(255)` | Yes | - | Họ tên khách hàng. | `Nguyễn Văn An` |
| `phone_number` | `varchar(20)` | No | Unique | Số điện thoại khách hàng. Có thể dùng để tra cứu khách hàng. | `0901000001` |
| `identity_number` | `varchar(20)` | No | Unique | Số CCCD/CMND. Có thể dùng để tra cứu khách hàng. | `001201000001` |
| `date_of_birth` | `date` | No | - | Ngày sinh khách hàng. Có thể dùng kèm tên để tra cứu. | `1995-01-15` |
| `status` | `varchar(30)` | Yes | Check enum | Trạng thái đơn giản của khách hàng. Không phải lifecycle. | `ACTIVE` |

## 2.4. Giá trị hợp lệ của `customer.status`

| Value | Ý nghĩa |
|---|---|
| `ACTIVE` | Khách hàng đang hoạt động, có thể tạo hồ sơ vay. |
| `INACTIVE` | Khách hàng không còn hoạt động. |
| `RESTRICTED` | Khách hàng bị hạn chế, ví dụ cần kiểm tra blacklist/risk trước khi xử lý. |

## 2.5. Index/constraint quan trọng

| Constraint/Index | Ý nghĩa |
|---|---|
| `uq_customer_code` | Đảm bảo mã khách hàng không trùng. |
| `uq_customer_phone_number` | Đảm bảo số điện thoại không trùng nếu có dữ liệu. |
| `uq_customer_identity_number` | Đảm bảo CCCD/CMND không trùng nếu có dữ liệu. |
| `chk_customer_status` | Chỉ cho phép status nằm trong `ACTIVE`, `INACTIVE`, `RESTRICTED`. |
| `idx_customer_full_name` | Hỗ trợ tra cứu theo tên. |
| `idx_customer_date_of_birth` | Hỗ trợ tra cứu theo ngày sinh. |
| `idx_customer_status` | Hỗ trợ lọc theo trạng thái khách hàng. |

---

# 3. Object: Loan Application

## 3.1. Ý nghĩa

`Loan Application` là hồ sơ vay của khách hàng. Đây là object trung tâm của module hiện tại.

Một khách hàng có thể có nhiều hồ sơ vay:

```text
customer 1 - N loan_application
```

Ở phiên bản này, hồ sơ vay chưa gắn với asset. `requested_amount` có thể chưa có khi hồ sơ mới được tạo ở trạng thái nháp.

## 3.2. Bảng vật lý

`loan_application`

## 3.3. Field dictionary

| Column | Type | Required | Constraint | Ý nghĩa | Ví dụ |
|---|---|---:|---|---|---|
| `id` | `uuid` | Yes | Primary key, default `gen_random_uuid()` | Khóa kỹ thuật của hồ sơ vay. | `30000000-0000-0000-0000-000000000001` |
| `loan_application_code` | `varchar(50)` | Yes | Unique | Mã nghiệp vụ hồ sơ vay, dùng để hiển thị/tra cứu. | `APP-2026-000001` |
| `customer_id` | `uuid` | Yes | FK to `customer.id` | Khách hàng sở hữu hồ sơ vay. | `10000000-0000-0000-0000-000000000001` |
| `current_state_id` | `uuid` | Yes | FK to `loan_application_state.id` | State hiện tại của hồ sơ vay. | `APP_DRAFT` reference id |
| `requested_amount` | `numeric(18,2)` | No | `NULL` or `> 0` | Số tiền khách hàng muốn vay. Có thể để trống lúc tạo nháp. | `50000000.00` |
| `loan_purpose` | `text` | No | - | Mục đích vay hoặc ghi chú nghiệp vụ ngắn. | `Vay phục vụ nhu cầu cá nhân.` |

## 3.4. Constraint/index quan trọng

| Constraint/Index | Ý nghĩa |
|---|---|
| `uq_loan_application_code` | Đảm bảo mã hồ sơ vay không trùng. |
| `chk_loan_application_requested_amount` | Nếu nhập số tiền vay thì số tiền phải lớn hơn 0. |
| `idx_loan_application_customer_id` | Hỗ trợ truy vấn danh sách hồ sơ vay của một khách hàng. |
| `idx_loan_application_current_state_id` | Hỗ trợ lọc hồ sơ vay theo trạng thái hiện tại. |

## 3.5. Ghi chú thiết kế

Các field sau **không được lưu trực tiếp trong `loan_application` ở phiên bản này**:

| Field bị bỏ | Lý do |
|---|---|
| `asset_id` | Asset chưa nằm trong scope hiện tại. |
| `submitted_at` | Thời điểm nộp hồ sơ được lấy từ `loan_application_state_history.changed_at` với action `SUBMIT`. |
| `closed_at` | Thời điểm kết thúc được lấy từ history khi hồ sơ chuyển vào terminal state như `APP_CONTRACTED` hoặc `APP_CANCELLED`. |
| `created_at` | Thời điểm tạo hồ sơ được lấy từ history với action `CREATE`. |
| `updated_at` | Chưa quản lý audit thay đổi field trong phase này. |
| `deleted_at` | Chưa hỗ trợ soft delete trong phase này. |

Điểm cần lưu ý: `loan_application_state_history` audit được **lifecycle event**, không audit toàn bộ thay đổi dữ liệu field. Nếu sau này cần audit chi tiết field-level change, cần thiết kế thêm cơ chế audit riêng.

---

# 4. Lifecycle tables của Loan Application

## 4.1. Bảng `loan_application_state`

### Ý nghĩa

Lưu danh mục state hợp lệ của hồ sơ vay. Đây là bảng reference/master data.

### Field dictionary

| Column | Type | Required | Constraint | Ý nghĩa |
|---|---|---:|---|---|
| `id` | `uuid` | Yes | Primary key | Khóa kỹ thuật của state. |
| `code` | `varchar(50)` | Yes | Unique | Mã state dùng trong hệ thống. |
| `name` | `varchar(100)` | Yes | - | Tên hiển thị của state. |
| `description` | `text` | No | - | Mô tả nghiệp vụ của state. |
| `is_initial` | `boolean` | Yes | Unique partial index when true | Đánh dấu state khởi tạo của hồ sơ. |
| `is_terminal` | `boolean` | Yes | - | Đánh dấu state kết thúc lifecycle. |
| `sort_order` | `int` | Yes | - | Thứ tự hiển thị state. |

## 4.2. Bảng `loan_application_state_transition`

### Ý nghĩa

Lưu cấu hình state nào được phép chuyển sang state nào. Backend dùng bảng này để kiểm tra chuyển trạng thái hợp lệ.

### Field dictionary

| Column | Type | Required | Constraint | Ý nghĩa |
|---|---|---:|---|---|
| `id` | `uuid` | Yes | Primary key | Khóa kỹ thuật của transition. |
| `from_state_id` | `uuid` | Yes | FK to `loan_application_state.id` | State nguồn. |
| `to_state_id` | `uuid` | Yes | FK to `loan_application_state.id` | State đích. |
| `action_code` | `varchar(50)` | Yes | Unique with from/to | Mã hành động gây ra chuyển state. |
| `action_name` | `varchar(100)` | Yes | - | Tên hành động hiển thị cho người dùng/dev. |
| `description` | `text` | No | - | Mô tả nghiệp vụ của transition. |

## 4.3. Bảng `loan_application_state_history`

### Ý nghĩa

Lưu nhật ký các lần hồ sơ vay chuyển state. Đây là bảng audit lifecycle chính của `loan_application`.

### Field dictionary

| Column | Type | Required | Constraint | Ý nghĩa |
|---|---|---:|---|---|
| `id` | `uuid` | Yes | Primary key | Khóa kỹ thuật của history event. |
| `loan_application_id` | `uuid` | Yes | FK to `loan_application.id` | Hồ sơ vay được ghi nhận event. |
| `from_state_id` | `uuid` | No | FK to `loan_application_state.id` | State trước đó. `NULL` khi action là `CREATE`. |
| `to_state_id` | `uuid` | Yes | FK to `loan_application_state.id` | State sau khi event xảy ra. |
| `action_code` | `varchar(50)` | Yes | - | Hành động đã xảy ra, ví dụ `CREATE`, `SUBMIT`, `CANCEL`. |
| `changed_at` | `timestamp` | Yes | Default `CURRENT_TIMESTAMP` | Thời điểm event xảy ra. |
| `changed_by` | `varchar(100)` | No | - | Người hoặc hệ thống thực hiện event. |
| `note` | `text` | No | - | Ghi chú nghiệp vụ. |
