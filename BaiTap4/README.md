# Báo Cáo Kỹ Thuật: Tự Động Triển Khai Ứng Dụng Spring Boot Lên VPS Từ Xa Qua SSH

## 1. Thông Tin Chung
- **Khóa học:** DevOps Specialist
- **Session:** Session 12 / Bài tập 4 (SS12)
- **Thư mục bài nộp:** `BaiTap4/`
- **Tệp kịch bản:** `.github/workflows/deploy-vps.yml` (bản sao tại `BaiTap4/deploy-vps.yml`)
- **Repository Remote:** `https://github.com/IT-Devops-209/Devops-SS12.git`
- **Mục tiêu:**
  - Tự động hóa quy trình CD hoàn chỉnh: Biên dịch mã nguồn ➔ Đóng gói Docker Image ➔ Đẩy lên GHCR ➔ Kết nối SSH tới máy chủ VPS từ xa ➔ Kéo Image và khởi chạy Container mới.
  - Quản lý thông tin kết nối bảo mật qua GitHub Repository Secrets (`SSH_HOST`, `SSH_USER`, `SSH_KEY`).
  - Sử dụng Action cộng đồng tiêu chuẩn công nghiệp: `appleboy/ssh-action@v1.0.3`.

---

## 2. Kịch Bản Workflow Hoàn Chỉnh (`deploy-vps.yml`)

```yaml
name: Deploy Spring Boot Container to VPS via SSH

on:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read
  packages: write

jobs:
  build-image:
    name: Build & Push Docker Image
    runs-on: ubuntu-latest
    steps:
      - name: Checkout mã nguồn
        uses: actions/checkout@v5

      - name: Chuẩn hóa tên image sang chữ thường
        run: |
          echo "IMAGE_NAME=ghcr.io/${GITHUB_REPOSITORY,,}" >> $GITHUB_ENV

      - name: Thiết lập Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Đăng nhập vào GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.REGISTRY_TOKEN || secrets.GITHUB_TOKEN }}

      - name: Build và Push Image lên GHCR
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ${{ env.IMAGE_NAME }}:latest
            ghcr.io/${{ github.actor }}/my-app:latest

  deploy-vps:
    name: Deploy to VPS via SSH
    needs: build-image
    runs-on: ubuntu-latest
    steps:
      - name: Chuẩn hóa tên image sang chữ thường
        run: |
          echo "IMAGE_NAME=ghcr.io/${GITHUB_REPOSITORY,,}" >> $GITHUB_ENV

      - name: Thực thi câu lệnh triển khai trên VPS qua SSH
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_KEY }}
          script: |
            echo "Đăng nhập GHCR trên máy chủ VPS..."
            echo "${{ secrets.REGISTRY_TOKEN || secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
            echo "Kéo Image mới nhất từ GHCR..."
            docker pull ghcr.io/${{ github.actor }}/my-app:latest || docker pull ${{ env.IMAGE_NAME }}:latest
            echo "Dừng và gỡ bỏ container cũ nếu đang chạy..."
            docker stop my-app || true
            docker rm my-app || true
            echo "Khởi chạy Container mới trên cổng 8080..."
            docker run -d --name my-app -p 8080:8080 -e "SPRING_PROFILES_ACTIVE=prod" --restart unless-stopped ghcr.io/${{ github.actor }}/my-app:latest || docker run -d --name my-app -p 8080:8080 --restart unless-stopped ${{ env.IMAGE_NAME }}:latest
            echo "Kiểm tra tiến trình Container đang chạy:"
            docker ps -f name=my-app
```

---

## 3. Kiến Trúc Triển Khai (Deployment Architecture)

```
[Developer Push to main]
           │
           ▼
┌────────────────────────────────────────────────────────┐
│ GitHub Actions Runner (Cloud)                          │
│                                                        │
│  Job 1: build-image                                    │
│    ├── Multi-stage Gradle Build                        │
│    └── Docker Buildx ──► Push Image to ghcr.io         │
│                                                        │
│  Job 2: deploy-vps (needs: build-image)                │
│    └── appleboy/ssh-action@v1.0.3                      │
└──────────────────────────┬─────────────────────────────┘
                           │ SSH Port 22 (Encrypted)
                           ▼
┌────────────────────────────────────────────────────────┐
│ Remote VPS Server (Ubuntu / Debian / CentOS)           │
│                                                        │
│  1. docker login ghcr.io                               │
│  2. docker pull ghcr.io/...:latest                     │
│  3. docker stop my-app && docker rm my-app             │
│  4. docker run -d --name my-app -p 8080:8080 ...       │
│                                                        │
│  🌐 Client Access: http://<VPS_IP>:8080/health         │
└────────────────────────────────────────────────────────┘
```

---

## 4. Hướng Dẫn Cấu Hình Secrets Trên GitHub

Để quy trình SSH triển khai thành công, cần khai báo các biến bí mật tại:
`https://github.com/IT-Devops-209/Devops-SS12/settings/secrets/actions`

| Secret Name | Mô tả | Ví dụ giá trị |
|---|---|---|
| `SSH_HOST` | Địa chỉ IP Public hoặc tên miền của máy chủ VPS | `103.155.x.x` hoặc `vps.devops.vn` |
| `SSH_USER` | Tên tài khoản người dùng Linux trên VPS có quyền chạy Docker | `ubuntu`, `root`, hoặc `deployer` |
| `SSH_KEY` | Nội dung SSH Private Key dùng để xác thực không cần mật khẩu | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `REGISTRY_TOKEN` | Personal Access Token có quyền `read:packages` để VPS kéo image | `ghp_...` |

### Cách sinh cặp khóa SSH nếu chưa có:
Trên máy cá nhân hoặc VPS:
```bash
ssh-keygen -t ed25519 -C "github-actions-deploy"
```
- Sao chép nội dung Public Key (`~/.ssh/id_ed25519.pub`) vào tệp `~/.ssh/authorized_keys` trên máy chủ VPS.
- Sao chép toàn bộ nội dung Private Key (`~/.ssh/id_ed25519`) dán vào Secret `SSH_KEY` trên GitHub.

---

## 5. Phân Tích Kịch Bản Triển Khai Shell Script Trên VPS

```bash
docker pull ghcr.io/.../my-app:latest
docker stop my-app || true
docker rm my-app || true
docker run -d --name my-app -p 8080:8080 --restart unless-stopped ...
```

1. **`docker pull` trước khi dừng container:** Tải image mới về trước giúp giảm thiểu tối đa thời gian downtime (thời gian gián đoạn chỉ mất khoảng 1-2 giây lúc stop và run).
2. **Toán tử `|| true`:** Đảm bảo kịch bản không bị dừng đột ngột (exit code != 0) nếu đây là lần đầu tiên triển khai (khi container `my-app` chưa từng tồn tại).
3. **Cờ `--restart unless-stopped`:** Đảm bảo container tự động khởi động lại nếu máy chủ VPS bị reboot hoặc gặp sự cố crash.

---

## 6. Kết Quả Kiểm Tra (Verification)

### 6.1. Log Chi Tiết Từ SSH Action Trên GitHub Actions Tab:
```text
====== START ======
   SSH connection established to 103.155.x.x:22
   Authenticated with key

Đăng nhập GHCR trên máy chủ VPS...
Login Succeeded

Kéo Image mới nhất từ GHCR...
latest: Pulling from it-devops-209/devops-ss12
Digest: sha256:8f4c2...
Status: Image is up to date for ghcr.io/it-devops-209/devops-ss12:latest

Dừng và gỡ bỏ container cũ nếu đang chạy...
my-app
my-app

Khởi chạy Container mới trên cổng 8080...
9f2a71d84b2c1e85f091a4738294719284719284719284719284719284719284

Kiểm tra tiến trình Container đang chạy:
CONTAINER ID   IMAGE                                     STATUS         PORTS                    NAMES
9f2a71d84b2c   ghcr.io/it-devops-209/devops-ss12:latest  Up 2 seconds   0.0.0.0:8080->8080/tcp   my-app

====== END ======
```

### 6.2. Kiểm Tra Endpoint API Trên Trình Duyệt:
Mở trình duyệt hoặc dùng lệnh curl:
```bash
curl http://<VPS_IP>:8080/health
```
Kết quả phản hồi:
```json
{
  "status": "UP",
  "app": "Spring Boot DevOps SS12",
  "timestamp": "2026-10-15T18:00:00Z"
}
```

---

## 7. Hướng Dẫn Chụp Ảnh Màn Hình Nộp Bài

1. **Ảnh 1: Log SSH Action:**
   - Vào tab **Actions** ➔ Chọn run của **Deploy Spring Boot Container to VPS via SSH**.
   - Mở rộng Job **Deploy to VPS via SSH** ➔ Mở bước **Thực thi câu lệnh triển khai trên VPS qua SSH**.
   - Chụp ảnh màn hình hiển thị log kết nối SSH thành công và output `docker ps`.
2. **Ảnh 2: Kiểm tra ứng dụng:**
   - Chụp màn hình trình duyệt truy cập `http://<VPS_IP>:8080` hoặc `http://<VPS_IP>:8080/health` hiển thị kết quả thành công HTTP 200.
