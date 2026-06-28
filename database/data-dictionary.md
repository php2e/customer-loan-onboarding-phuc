# Data Dictionary - Customer Loan Onboarding

## 1. Phạm vi thiết kế

Tài liệu này mô tả mô hình dữ liệu mức đơn giản cho module tạo và xử lý hồ sơ vay.

Phạm vi hiện tại không nhằm quản lý đầy đủ vòng đời khách hàng hoặc vòng đời tài sản. Customer và Asset chỉ được lưu ở mức thông tin cần thiết để phục vụ hồ sơ vay. Lifecycle chỉ được thiết kế cho `loan_application`.

Các nhóm bảng chính:

| Nhóm | Bảng | Mục đích |
|---|---|---|
| Thông tin nghiệp vụ chính | `customer`, `asset`, `loan_application` | Lưu khách hàng, tài sản và hồ sơ vay |
| Lifecycle hồ sơ vay | `loan_application_state`, `loan_application_state_transition`, `loan_application_state_history` | Quản lý trạng thái hiện tại, luồng chuyển trạng thái và lịch sử chuyển trạng thái của hồ sơ vay |

Quy ước chung:

- `id` là khóa kỹ thuật, dùng để tham chiếu giữa các bảng.
- `*_code` là mã nghiệp vụ, dùng để hiển thị, tra cứu, debug, đối soát với người dùng/dev. Không dùng `*_code` làm khóa ngoại.
- Tên bảng và tên cột dùng tiếng Anh, dạng `snake_case`.
- Tài liệu mô tả nghiệp vụ dùng tiếng Việt.
- Customer và Asset có `status` đơn giản bằng `CHECK constraint`, không có bảng lifecycle riêng.
- Loan Application dùng bộ bảng lifecycle riêng.

---

## 2. Quan hệ nghiệp vụ đã chốt

| Quan hệ | Mô tả |
|---|---|
| `customer` 1 - N `loan_application` | Một khách hàng có thể có nhiều hồ sơ vay |
| `customer` 1 - N `asset` | Một khách hàng có thể có nhiều tài sản |
| `loan_application` 1 - 1 `asset` | Một hồ sơ vay sử dụng đúng một tài sản làm tài sản đảm bảo |
| `asset` 0/1 - 1 active `loan_application` | Một tài sản không được gắn vào nhiều hồ sơ vay đang mở cùng lúc |

Lưu ý về quan hệ `loan_application` và `asset`:

- Về mặt nghiệp vụ hiện tại, một hồ sơ vay chỉ dùng một tài sản.
- Một tài sản chỉ được dùng cho một hồ sơ vay đang mở nếu tài sản đó đang `AVAILABLE`.
- Sau khi hồ sơ kết thúc và tài sản được giải chấp, tài sản có thể được dùng lại tùy nghiệp vụ.
- Vì vậy SQL dùng partial unique index trên `loan_application(asset_id)` với điều kiện `closed_at IS NULL AND deleted_at IS NULL` để chặn trùng tài sản trên các hồ sơ đang mở.

---

## 3. Bảng `customer`

### Mục đích

Lưu thông tin khách hàng ở mức tối thiểu để tạo và tra cứu hồ sơ vay. Bảng này không quản lý lifecycle khách hàng.

### Cột dữ liệu

| Column | Type | Required | Ý nghĩa | Ví dụ | Ghi chú |
|---|---:|:---:|---|---|---|
| `id` | `uuid` | Yes | Khóa chính kỹ thuật của khách hàng | `7b6b9a9a-...` | Dùng làm FK từ bảng khác |
| `customer_code` | `varchar(50)` | Yes | Mã nghiệp vụ của khách hàng | `CUS-000001` | Unique, dùng để tra cứu/hiển thị |
| `full_name` | `varchar(255)` | Yes | Họ tên khách hàng | `Nguyễn Văn A` |  |
| `phone_number` | `varchar(20)` | Yes | Số điện thoại liên hệ | `0912345678` | Unique trong phạm vi hệ thống hiện tại |
| `identity_number` | `varchar(20)` | No | Số CCCD/CMND/hộ chiếu | `001203004567` | Unique nếu có dữ liệu |
| `date_of_birth` | `date` | No | Ngày sinh khách hàng | `1998-05-20` |  |
| `address` | `text` | No | Địa chỉ liên hệ hiện tại | `Hà Nội` | Chưa tách bảng address vì scope đơn giản |
| `status` | `varchar(30)` | Yes | Trạng thái đơn giản của khách hàng | `ACTIVE` | Enum bằng CHECK constraint |
| `created_at` | `timestamp` | Yes | Thời điểm tạo bản ghi | `2026-06-28 10:00:00` |  |
| `updated_at` | `timestamp` | Yes | Thời điểm cập nhật gần nhất | `2026-06-28 10:10:00` |  |
| `deleted_at` | `timestamp` | No | Thời điểm xóa mềm | `null` | Không xóa vật lý nếu cần giữ lịch sử |

### Giá trị hợp lệ của `customer.status`

| Value | Ý nghĩa |
|---|---|
| `ACTIVE` | Khách hàng đang hoạt động, có thể tạo hồ sơ vay |
| `INACTIVE` | Khách hàng không còn hoạt động hoặc tạm ngưng |
| `RESTRICTED` | Khách hàng bị hạn chế, ví dụ nằm trong blacklist hoặc cần kiểm tra thêm |

---

## 4. Bảng `asset`

### Mục đích

Lưu thông tin tài sản của khách hàng. Trong phạm vi hiện tại, asset được hiểu là phương tiện/xe dùng làm tài sản đảm bảo cho hồ sơ vay.

Bảng này không quản lý lifecycle tài sản chi tiết. Chỉ lưu `status` đơn giản để biết tài sản có thể dùng cho hồ sơ vay hay không.

### Cột dữ liệu

| Column | Type | Required | Ý nghĩa | Ví dụ | Ghi chú |
|---|---:|:---:|---|---|---|
| `id` | `uuid` | Yes | Khóa chính kỹ thuật của tài sản | `a8f4...` | Dùng làm FK từ `loan_application` |
| `asset_code` | `varchar(50)` | Yes | Mã nghiệp vụ của tài sản | `AST-000001` | Unique, dùng để tra cứu/hiển thị |
| `customer_id` | `uuid` | Yes | Khách hàng sở hữu/đăng ký tài sản trong hệ thống | `customer.id` | FK tới `customer` |
| `license_plate` | `varchar(20)` | Yes | Biển số xe | `30A-12345` | Unique trong phạm vi hệ thống hiện tại |
| `vehicle_brand` | `varchar(100)` | Yes | Hãng xe | `Toyota` |  |
| `vehicle_model` | `varchar(100)` | Yes | Dòng xe | `Vios` |  |
| `vehicle_version` | `varchar(100)` | No | Phiên bản xe | `1.5G CVT` |  |
| `manufacture_year` | `int` | No | Năm sản xuất | `2021` | Có CHECK cơ bản |
| `status` | `varchar(30)` | Yes | Trạng thái đơn giản của tài sản | `AVAILABLE` | Enum bằng CHECK constraint |
| `created_at` | `timestamp` | Yes | Thời điểm tạo bản ghi | `2026-06-28 10:00:00` |  |
| `updated_at` | `timestamp` | Yes | Thời điểm cập nhật gần nhất | `2026-06-28 10:10:00` |  |
| `deleted_at` | `timestamp` | No | Thời điểm xóa mềm | `null` |  |

### Giá trị hợp lệ của `asset.status`

| Value | Ý nghĩa |
|---|---|
| `AVAILABLE` | Tài sản sẵn sàng, chưa bị cầm cố trong hồ sơ vay đang mở |
| `PLEDGED` | Tài sản đang được cầm cố |
| `RELEASED` | Tài sản đã được giải chấp |

### Ghi chú nghiệp vụ

Khi tạo hoặc submit hồ sơ vay, backend cần kiểm tra:

1. `asset.customer_id` phải khớp với `loan_application.customer_id`.
2. `asset.status` nên là `AVAILABLE` tại thời điểm gắn vào hồ sơ.
3. Không tồn tại hồ sơ vay đang mở khác dùng cùng `asset_id`.

Ràng buộc số 3 được hỗ trợ bằng partial unique index trong SQL.

---

## 5. Bảng `loan_application`

### Mục đích

Lưu thông tin chính của hồ sơ vay. Đây là object trung tâm của module hiện tại.

Bảng này lưu trạng thái hiện tại thông qua `current_state_id`. Lịch sử chuyển trạng thái không lưu trực tiếp trong bảng này mà lưu ở `loan_application_state_history`.

### Cột dữ liệu

| Column | Type | Required | Ý nghĩa | Ví dụ | Ghi chú |
|---|---:|:---:|---|---|---|
| `id` | `uuid` | Yes | Khóa chính kỹ thuật của hồ sơ vay | `d1f2...` |  |
| `loan_application_code` | `varchar(50)` | Yes | Mã nghiệp vụ của hồ sơ vay | `LA-000001` | Unique, dùng để tra cứu/hiển thị |
| `customer_id` | `uuid` | Yes | Khách hàng tạo hồ sơ vay | `customer.id` | FK tới `customer` |
| `asset_id` | `uuid` | Yes | Tài sản được dùng trong hồ sơ vay | `asset.id` | FK tới `asset` |
| `current_state_id` | `uuid` | Yes | State hiện tại của hồ sơ vay | `loan_application_state.id` | FK tới bảng state |
| `requested_amount` | `numeric(18,2)` | Yes | Số tiền khách hàng đề nghị vay | `50000000.00` | Phải lớn hơn 0 |
| `loan_purpose` | `text` | No | Mục đích vay | `Bổ sung vốn kinh doanh` |  |
| `submitted_at` | `timestamp` | No | Thời điểm nộp hồ sơ | `2026-06-28 10:30:00` | Null nếu chưa nộp |
| `closed_at` | `timestamp` | No | Thời điểm hồ sơ kết thúc | `2026-06-30 15:00:00` | Set khi hồ sơ vào terminal state |
| `created_at` | `timestamp` | Yes | Thời điểm tạo hồ sơ | `2026-06-28 10:00:00` |  |
| `updated_at` | `timestamp` | Yes | Thời điểm cập nhật gần nhất | `2026-06-28 10:10:00` |  |
| `deleted_at` | `timestamp` | No | Thời điểm xóa mềm | `null` |  |

### Ghi chú nghiệp vụ

- `loan_application_code` là mã nghiệp vụ, không dùng làm khóa ngoại.
- `current_state_id` là state hiện tại để truy vấn nhanh.
- `loan_application_state_history` là nguồn dữ liệu để xem hồ sơ đã đi qua những state nào.
- Một hồ sơ vay dùng đúng một tài sản.
- Một tài sản không được dùng cho nhiều hồ sơ vay đang mở cùng lúc.

---

## 6. Bảng `loan_application_state`

### Mục đích

Lưu danh sách state hợp lệ của hồ sơ vay. Bảng này chỉ dùng cho `loan_application`, không dùng chung cho customer hoặc asset.

### Cột dữ liệu

| Column | Type | Required | Ý nghĩa | Ví dụ | Ghi chú |
|---|---:|:---:|---|---|---|
| `id` | `uuid` | Yes | Khóa chính kỹ thuật của state | `...` |  |
| `code` | `varchar(50)` | Yes | Mã state | `APP_DRAFT` | Unique |
| `name` | `varchar(100)` | Yes | Tên hiển thị của state | `Hồ sơ nháp` | Có thể hiển thị trên UI |
| `description` | `text` | No | Mô tả ý nghĩa state | `Hồ sơ mới được tạo, chưa nộp` |  |
| `is_initial` | `boolean` | Yes | Có phải state khởi tạo không | `true` | Chỉ nên có 1 initial state |
| `is_terminal` | `boolean` | Yes | Có phải state kết thúc không | `false` | Terminal state không nên chuyển tiếp tiếp |
| `sort_order` | `int` | Yes | Thứ tự hiển thị | `1` |  |
| `created_at` | `timestamp` | Yes | Thời điểm tạo bản ghi | `2026-06-28 10:00:00` |  |

### Danh sách state hiện tại

| Code | Tên | Initial | Terminal | Ý nghĩa |
|---|---|:---:|:---:|---|
| `APP_DRAFT` | Hồ sơ nháp | Yes | No | Hồ sơ mới được tạo, chưa nộp |
| `APP_SUBMITTED` | Đã nộp hồ sơ | No | No | Hồ sơ đã được gửi vào luồng xử lý |
| `APP_NEEDS_SUPPLEMENT` | Cần bổ sung hồ sơ | No | No | Hồ sơ thiếu thông tin hoặc giấy tờ |
| `APP_IN_REVIEW` | Đang thẩm định/phê duyệt | No | No | Hồ sơ đang được kiểm tra, đánh giá |
| `APP_READY_FOR_CONTRACT` | Sẵn sàng lập hợp đồng | No | No | Hồ sơ đã đủ điều kiện tạo hợp đồng |
| `APP_CONTRACTED` | Đã có hợp đồng | No | Yes | Hồ sơ đã tạo hợp đồng, kết thúc vòng đời hồ sơ vay trong module hiện tại |
| `APP_CANCELLED` | Hồ sơ bị hủy | No | Yes | Hồ sơ bị hủy, không tiếp tục xử lý |

---

## 7. Bảng `loan_application_state_transition`

### Mục đích

Định nghĩa các cặp state được phép chuyển đổi. Backend dùng bảng này để kiểm tra một yêu cầu chuyển trạng thái có hợp lệ không.

### Cột dữ liệu

| Column | Type | Required | Ý nghĩa | Ví dụ | Ghi chú |
|---|---:|:---:|---|---|---|
| `id` | `uuid` | Yes | Khóa chính kỹ thuật của transition | `...` |  |
| `from_state_id` | `uuid` | Yes | State nguồn | `APP_DRAFT` | FK tới `loan_application_state` |
| `to_state_id` | `uuid` | Yes | State đích | `APP_SUBMITTED` | FK tới `loan_application_state` |
| `action_code` | `varchar(50)` | Yes | Mã hành động chuyển trạng thái | `SUBMIT` | Dùng trong service/API |
| `action_name` | `varchar(100)` | Yes | Tên hành động | `Nộp hồ sơ` | Có thể dùng cho UI/log |
| `description` | `text` | No | Mô tả điều kiện/ngữ cảnh chuyển trạng thái | `Tư vấn viên nộp hồ sơ` |  |
| `created_at` | `timestamp` | Yes | Thời điểm tạo bản ghi | `2026-06-28 10:00:00` |  |

### Transition hiện tại

| From | Action | To | Ý nghĩa |
|---|---|---|---|
| `APP_DRAFT` | `SUBMIT` | `APP_SUBMITTED` | Nộp hồ sơ nháp |
| `APP_DRAFT` | `CANCEL` | `APP_CANCELLED` | Hủy hồ sơ khi còn nháp |
| `APP_SUBMITTED` | `START_REVIEW` | `APP_IN_REVIEW` | Bắt đầu thẩm định/phê duyệt |
| `APP_SUBMITTED` | `REQUEST_SUPPLEMENT` | `APP_NEEDS_SUPPLEMENT` | Yêu cầu bổ sung hồ sơ |
| `APP_SUBMITTED` | `CANCEL` | `APP_CANCELLED` | Hủy hồ sơ sau khi đã nộp |
| `APP_NEEDS_SUPPLEMENT` | `RESUBMIT` | `APP_SUBMITTED` | Nộp lại sau khi bổ sung |
| `APP_IN_REVIEW` | `REQUEST_SUPPLEMENT` | `APP_NEEDS_SUPPLEMENT` | Yêu cầu bổ sung trong quá trình review |
| `APP_IN_REVIEW` | `APPROVE_FOR_CONTRACT` | `APP_READY_FOR_CONTRACT` | Hồ sơ đủ điều kiện lập hợp đồng |
| `APP_READY_FOR_CONTRACT` | `CREATE_CONTRACT` | `APP_CONTRACTED` | Tạo hợp đồng từ hồ sơ vay |
| `APP_READY_FOR_CONTRACT` | `CANCEL` | `APP_CANCELLED` | Hủy hồ sơ trước khi lập hợp đồng |

---

## 8. Bảng `loan_application_state_history`

### Mục đích

Lưu lịch sử chuyển state thực tế của từng hồ sơ vay.

Bảng này không định nghĩa state nào được phép chuyển sang state nào. Việc đó thuộc về `loan_application_state_transition`. Bảng history chỉ ghi nhận sự kiện đã xảy ra.

### Cột dữ liệu

| Column | Type | Required | Ý nghĩa | Ví dụ | Ghi chú |
|---|---:|:---:|---|---|---|
| `id` | `uuid` | Yes | Khóa chính kỹ thuật của record lịch sử | `...` |  |
| `loan_application_id` | `uuid` | Yes | Hồ sơ vay được chuyển state | `loan_application.id` | FK tới `loan_application` |
| `from_state_id` | `uuid` | No | State trước khi chuyển | `APP_DRAFT` | Null khi tạo hồ sơ lần đầu |
| `to_state_id` | `uuid` | Yes | State sau khi chuyển | `APP_SUBMITTED` | FK tới `loan_application_state` |
| `action_code` | `varchar(50)` | Yes | Hành động gây ra chuyển trạng thái | `SUBMIT` | Nên khớp với transition |
| `changed_at` | `timestamp` | Yes | Thời điểm chuyển trạng thái | `2026-06-28 10:30:00` |  |
| `changed_by` | `varchar(100)` | No | Người/hệ thống thực hiện chuyển trạng thái | `consultant_01` | Hiện tại lưu text đơn giản |
| `note` | `text` | No | Ghi chú/lý do chuyển trạng thái | `Khách hàng đã cung cấp đủ thông tin` |  |

### Ghi chú sử dụng

Khi chuyển state, backend nên thực hiện trong cùng một transaction:

1. Đọc `loan_application.current_state_id`.
2. Kiểm tra transition hợp lệ trong `loan_application_state_transition`.
3. Update `loan_application.current_state_id`.
4. Insert record vào `loan_application_state_history`.
5. Nếu state đích là terminal state, set `loan_application.closed_at`.

