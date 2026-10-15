# Báo Cáo Kỹ Thuật: Tự Động Hóa Đóng Gói và Phát Hành Docker Image Khi Gắn Git Tag

## 1. Thông Tin Chung
- **Khóa học:** DevOps Specialist
- **Session:** Session 12 / Bài tập 2 (SS12)
- **Thư mục bài nộp:** `BaiTap2/`
- **Tệp kịch bản:** `.github/workflows/release.yml` (bản sao tại `BaiTap2/release.yml`)
- **Repository Remote:** `https://github.com/IT-Devops-209/Devops-SS12.git`
- **Mục tiêu:**
  - Cấu hình luồng CD (Continuous Delivery) tự động phát hành phiên bản Docker Image chính thức khi có sự kiện gán nhãn Release (Git Tag `v*.*.*`).
  - Tự động sinh Docker Tags tương ứng với số phiên bản Git Tag bằng `docker/metadata-action@v5`.
  - Đóng gói ứng dụng Spring Boot và đẩy Image lên GitHub Container Registry (`ghcr.io`).

---

## 2. Kịch Bản Workflow Hoàn Chỉnh (`release.yml`)

```yaml
name: Release Docker Image

on:
  push:
    tags:
      - 'v*.*.*'

permissions:
  contents: read
  packages: write

jobs:
  release-image:
    name: Build & Push Docker Image to GHCR
    runs-on: ubuntu-latest

    steps:
      - name: Checkout mã nguồn
        uses: actions/checkout@v5

      - name: Chuẩn hóa tên repository sang chữ thường
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

      - name: Trích xuất metadata (tags, labels) cho Docker
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.IMAGE_NAME }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=raw,value=latest

      - name: Đóng gói và Push Docker Image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

---

## 3. Phân Tích Kỹ Thuật Các Thành Phần Trong Quy Trình CD

### 3.1. Sự Kiện Kích Hoạt `on.push.tags`
- Sử dụng mẫu wildcard:
  ```yaml
  on:
    push:
      tags:
        - 'v*.*.*'
  ```
- Workflow **chỉ chạy** khi lập trình viên thực hiện gắn thẻ Git Tag tuân thủ chuẩn Semantic Versioning (ví dụ: `v1.0.0`, `v1.2.3`).
- Các commit thông thường trên nhánh `main` hoặc `dev` sẽ **không** kích hoạt workflow này, giúp phân tách rành mạch giữa luồng CI (kiểm thử liên tục) và luồng CD (phát hành bản release).

### 3.2. Chuẩn Hóa Tên Image Sang Chữ Thường
- **Vấn đề thực tế:** Docker Registry (bao gồm `ghcr.io`) nghiêm cấm ký tự viết hoa trong tên image. Nếu tài khoản GitHub là `IT-Devops-209/Devops-SS12`, lệnh push sẽ báo lỗi `invalid reference format: repository name must be lowercase`.
- **Giải pháp:** Sử dụng cú pháp mở rộng bash `${GITHUB_REPOSITORY,,}` để chuyển toàn bộ thành chữ thường (`it-devops-209/devops-ss12`), đảm bảo tính tương thích 100%.

### 3.3. Tự Động Trích Xuất Tags với `docker/metadata-action@v5`
Khi push Git Tag `v1.0.0`, action tự động sinh ra các Docker Tags chuẩn:
1. `ghcr.io/it-devops-209/devops-ss12:1.0.0` (phiên bản đầy đủ)
2. `ghcr.io/it-devops-209/devops-ss12:1.0` (major.minor)
3. `ghcr.io/it-devops-209/devops-ss12:latest` (bản mới nhất)

### 3.4. Multi-stage Dockerfile Tối Ưu Cho Spring Boot
```dockerfile
# Stage 1: Build Spring Boot JAR with Gradle
FROM gradle:8.5-jdk17-alpine AS builder
WORKDIR /app
COPY build.gradle settings.gradle ./
COPY src ./src
RUN gradle bootJar --no-daemon

# Stage 2: Lightweight Runtime JRE 17
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /app/build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```
- **Builder Stage:** Dùng `gradle:8.5-jdk17-alpine` biên dịch mã nguồn và đóng gói Fat JAR.
- **Runtime Stage:** Dùng `eclipse-temurin:17-jre-alpine` siêu nhẹ (~150MB), loại bỏ toàn bộ mã nguồn và Gradle build tools, tối ưu hóa bảo mật và dung lượng khi đẩy lên GHCR.

---

## 4. Hướng Dẫn Thực Thi và Kiểm Tra (Verification)

### Bước 1: Tạo Git Tag và Đẩy Lên GitHub
Từ terminal máy cá nhân, thực hiện lệnh:
```bash
git tag v1.0.0
git push origin v1.0.0
```

### Bước 2: Kiểm Tra Tab Actions
1. Mở `https://github.com/IT-Devops-209/Devops-SS12/actions`
2. Workflow **"Release Docker Image"** được kích hoạt tự động với nhãn `v1.0.0`.
3. Kiểm tra log của bước **Build và Push Docker Image**:
```text
[+] Building 42.5s (13/13) FINISHED
 => [internal] load build definition from Dockerfile
 => [internal] load .dockerignore
 => [builder 1/5] FROM docker.io/library/gradle:8.5-jdk17-alpine
 => [builder 5/5] RUN gradle bootJar --no-daemon
 => [stage-1 3/3] COPY --from=builder /app/build/libs/*.jar app.jar
 => exporting to image
 => => exporting layers
 => => writing image sha256:d5c2e...
 => => naming to ghcr.io/it-devops-209/devops-ss12:1.0.0
 => => naming to ghcr.io/it-devops-209/devops-ss12:latest
 => => pushing layers
 => => pushing manifest for ghcr.io/it-devops-209/devops-ss12:1.0.0
 => => pushing manifest for ghcr.io/it-devops-209/devops-ss12:latest
```

### Bước 3: Kiểm Tra Mục GitHub Packages
1. Truy cập trang chính của Repository: `https://github.com/IT-Devops-209/Devops-SS12`
2. Ở cột bên phải (Sidebar), mục **Packages** xuất hiện package mới:
   - Tên Package: `devops-ss12`
   - Phiên bản: `v1.0.0` / `latest`
   - Lệnh kéo image:
     ```bash
     docker pull ghcr.io/it-devops-209/devops-ss12:1.0.0
     ```

---

## 5. Hướng Dẫn Chụp Ảnh Màn Hình Nộp Bài

1. **Ảnh 1: GitHub Packages:**
   - Vào `https://github.com/IT-Devops-209/Devops-SS12/pkgs/container/devops-ss12`
   - Chụp ảnh màn hình hiển thị gói Docker Image mang nhãn `1.0.0` và `latest`.
2. **Ảnh 2: Actions Run:**
   - Vào `https://github.com/IT-Devops-209/Devops-SS12/actions`
   - Chụp lần chạy workflow của tag `v1.0.0` với trạng thái tích xanh ✅ thành công.
