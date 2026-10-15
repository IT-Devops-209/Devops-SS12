# Báo Cáo Kỹ Thuật: Tách Biệt Luồng CI/CD Đa Môi Trường với GitHub Environments

## 1. Thông Tin Chung
- **Khóa học:** DevOps Specialist
- **Session:** Session 12 / Bài tập 3 (SS12)
- **Thư mục bài nộp:** `BaiTap3/`
- **Tệp kịch bản:** `.github/workflows/cd-multi-env.yml` (bản sao tại `BaiTap3/cd-multi-env.yml`)
- **Repository Remote:** `https://github.com/IT-Devops-209/Devops-SS12.git`
- **Mục tiêu:**
  - Quản lý hạ tầng triển khai đa môi trường (**Staging** vs **Production**) thông qua tính năng GitHub Environments.
  - Cấu hình **Environment Protection Rules** với chính sách **Required reviewers** yêu cầu phê duyệt thủ công trước khi kích hoạt deploy lên Production.
  - Tự động hóa điều hướng luồng triển khai dựa theo nhánh (`develop` ➔ Staging, `main` ➔ Production).

---

## 2. Kịch Bản Workflow Hoàn Chỉnh (`cd-multi-env.yml`)

```yaml
name: Multi-Environment CD Pipeline

on:
  push:
    branches:
      - main
      - develop

jobs:
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    if: github.ref_name == 'develop'
    environment:
      name: staging
      url: https://staging.example.com
    steps:
      - name: Checkout mã nguồn
        uses: actions/checkout@v5

      - name: Mô phỏng triển khai lên môi trường Staging
        run: |
          echo "=========================================="
          echo "Triển khai ứng dụng lên môi trường Staging"
          echo "Environment: staging"
          echo "Branch: ${{ github.ref_name }}"
          echo "Commit: ${{ github.sha }}"
          echo "Deploy URL: https://staging.example.com"
          echo "Triển khai Staging hoàn tất thành công!"
          echo "=========================================="

  deploy-prod:
    name: Deploy to Production
    runs-on: ubuntu-latest
    if: github.ref_name == 'main'
    environment:
      name: production
      url: https://api.prod.example.com
    steps:
      - name: Checkout mã nguồn
        uses: actions/checkout@v5

      - name: Mô phỏng triển khai lên môi trường Production
        run: |
          echo "=========================================="
          echo "Triển khai ứng dụng lên môi trường Production"
          echo "Environment: production"
          echo "Branch: ${{ github.ref_name }}"
          echo "Commit: ${{ github.sha }}"
          echo "Deploy URL: https://api.prod.example.com"
          echo "Triển khai Production hoàn tất thành công!"
          echo "=========================================="
```

---

## 3. Phân Tích Kỹ Thuật: Cơ Chế GitHub Environments & Protection Rules

### 3.1. GitHub Environments Là Gì?
**GitHub Environments** là tính năng cao cấp của GitHub Actions cho phép mô hình hóa các môi trường đích trong vòng đời phần mềm (Dev, Staging, QA, UAT, Production):
- **Gắn URL triển khai (`url`):** Hiển thị nút "View deployment" trực tiếp trên GitHub UI dẫn đến hệ thống sau khi deploy.
- **Biến và Bí mật độc lập (Environment Secrets & Variables):** Giúp môi trường Staging sử dụng DB Staging, trong khi Production dùng DB Production an toàn tuyệt đối.
- **Lịch sử triển khai (Deployment History):** Theo dõi chi tiết ai deploy phiên bản nào lên môi trường nào vào thời gian nào.

### 3.2. Quy Tắc Bảo Vệ Môi Trường (Environment Protection Rules)
Đối với môi trường **Production**, tính năng **Required reviewers** đóng vai trò là "chốt chặn an toàn" (Manual Approval Gate):
1. Khi có commit mới vào `main`, Job `deploy-prod` bắt đầu nhưng **không thực thi ngay**.
2. GitHub tạm dừng Job và chuyển sang trạng thái **Waiting for review**.
3. Người được chỉ định (Lead / DevOps Engineer) nhận được thông báo yêu cầu kiểm tra thay đổi.
4. Chỉ khi người duyệt bấm **Approve and deploy**, các bước triển khai production thực tế mới bắt đầu.

```
Push to main ──► Job: deploy-prod ──► [Environment: production]
                                             │
                                     (Approval Gate)
                                     Waiting for review ⏳
                                             │
                             [Lead bấm Approve and deploy] ✅
                                             │
                                             ▼
                                  Execute Deployment Steps
                                  Deploy to Production URL
```

---

## 4. Hướng Dẫn Cấu Hình Từng Bước Trên Giao Diện GitHub

### Bước 4.1: Tạo Môi Trường `staging`
1. Truy cập Repository: `https://github.com/IT-Devops-209/Devops-SS12`
2. Nhấn vào tab **Settings** ➔ Menu bên trái chọn **Environments**.
3. Nhấn nút xanh **New environment**.
4. Nhập tên: `staging` ➔ Nhấn **Configure environment**.
5. Nhấn **Save protection rules** (đối với Staging ta để tự động, không cần người duyệt).

---

### Bước 4.2: Tạo Môi Trường `production` & Bật Required Reviewers
1. Tại trang **Environments**, tiếp tục nhấn **New environment**.
2. Nhập tên: `production` ➔ Nhấn **Configure environment**.
3. Tại mục **Environment protection rules**:
   - Tích chọn ô vuông: ✅ **Required reviewers**.
   - Tại ô tìm kiếm người duyệt, gõ và chọn tài khoản GitHub của bạn (`IT-Devops-209`).
   - Có thể tích chọn *"Prevent self-review"* nếu làm việc nhóm, hoặc bỏ tích để tự mình phê duyệt cho bài tập.
4. Nhấn **Save protection rules**.

---

## 5. Quy Trình Kiểm Tra & Phê Duyệt (Verification Workflow)

### Bước 5.1: Kích hoạt triển khai lên Production
Khi đẩy code lên nhánh `main`, mở tab **Actions**:
`https://github.com/IT-Devops-209/Devops-SS12/actions`

1. Chọn lần chạy của workflow **Multi-Environment CD Pipeline**.
2. Tại sơ đồ Job `deploy-prod`, trạng thái hiển thị:
   - 🟡 **Waiting for review**
   - Thông báo: *"Waiting for review by IT-Devops-209 to deploy to production"*.

### Bước 5.2: Thực hiện phê duyệt (Approval)
1. Nhấn nút **Review deployments** (màu vàng) trên trang run.
2. Cửa sổ modal bật lên:
   - Tích chọn: `[x] production`
   - Nhập bình luận (tùy chọn): *"Approved for production release"*.
3. Nhấn nút xanh **Approve and deploy**.
4. Job ngay lập tức chuyển trạng thái sang chạy thực thi và tích xanh ✅:
   - **Status:** `Success`
   - **Environment:** `production`
   - **URL:** `https://api.prod.example.com`

---

## 6. Hướng Dẫn Chụp Ảnh Màn Hình Nộp Bài

Để hoàn thành yêu cầu nộp bài, bạn chụp 2 ảnh màn hình:
1. **Ảnh 1 (Cửa sổ phê duyệt):** Chụp hộp thoại modal **"Review deployments"** hiển thị mục `production` kèm nút **Approve and deploy**.
2. **Ảnh 2 (Kết quả hoàn tất):** Chụp màn hình trang Actions sau khi đã approve hiển thị Job `Deploy to Production` tích xanh ✅ kèm đường link môi trường `production`.
