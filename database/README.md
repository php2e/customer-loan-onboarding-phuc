# Customer Loan Onboarding Database

Tài liệu này mô tả schema database hiện tại cho module Customer Loan Onboarding.

## Phạm vi hiện tại

Schema hiện tại chỉ tập trung vào:

- lưu thông tin khách hàng cơ bản để tra cứu;
- tạo và quản lý hồ sơ vay;
- quản lý lifecycle của hồ sơ vay.

Trong phiên bản này, **asset được tạm thời loại khỏi schema**. Các phần định giá tài sản, eligibility check, approval case và quản lý tài sản chi tiết sẽ được xem xét ở phase sau khi flow nghiệp vụ rõ hơn.

## Danh sách file

```text
.
├── data-dictionary.md
├── erd.dbml
├── lifecycle.md
├── migrations
│   └── V1__init_schema.sql
└── seed
    ├── V1__seed_reference_data.sql
    └── V2__seed_demo_business_data.sql
```

## Bảng chính

| Bảng | Vai trò |
|---|---|
| `customer` | Lưu thông tin khách hàng cơ bản phục vụ tra cứu và tạo hồ sơ vay. |
| `loan_application` | Lưu hồ sơ vay. Đây là object trung tâm của module. |
| `loan_application_state` | Danh mục state hợp lệ của hồ sơ vay. |
| `loan_application_state_transition` | Cấu hình state nào được phép chuyển sang state nào. |
| `loan_application_state_history` | Nhật ký lifecycle của từng hồ sơ vay. |

## Ghi chú thiết kế

- `loan_application.requested_amount` cho phép `NULL` vì hồ sơ có thể được tạo ở trạng thái nháp khi chưa xác định số tiền vay.
- `loan_application` không lưu `submitted_at`, `closed_at`, `created_at`, `updated_at`, `deleted_at` trong phiên bản này.
- Các mốc thời gian lifecycle được ghi nhận trong `loan_application_state_history.changed_at`.
- `loan_application_state` và `loan_application_state_transition` là dữ liệu cấu hình, được seed bằng `V1__seed_reference_data.sql`.
- `V2__seed_demo_business_data.sql` chỉ dùng để tạo dữ liệu demo cho việc kiểm tra backend và database.

## Cách chạy SQL bằng Docker

Nếu PostgreSQL container tên là `clo-postgres`:

```bash
docker exec -i clo-postgres psql -U clo -d clo_onboarding < database/migrations/V1__init_schema.sql
docker exec -i clo-postgres psql -U clo -d clo_onboarding < database/seed/V1__seed_reference_data.sql
docker exec -i clo-postgres psql -U clo -d clo_onboarding < database/seed/V2__seed_demo_business_data.sql
```
