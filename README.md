# DevOps Session 12 – Advanced GitHub Actions CI/CD

Repository bài tập Session 12 môn DevOps Specialist.

## Danh Sách Bài Tập
- **Bài 1:** Xây dựng quy trình CI đa phiên bản JDK (Matrix Strategy) cho Java Spring Boot Gradle
  - Kịch bản Workflow: `.github/workflows/ci-matrix.yml` (bản sao tại `BaiTap1/ci-matrix.yml`)
  - Báo cáo kỹ thuật: `BaiTap1/README.md`
  - Chiến lược ma trận: Kiểm thử song song trên Java JDK 17 và JDK 21 với caching Gradle.
- **Bài 2:** Tự động hóa đóng gói và phát hành Docker Image khi gắn Git Tag (v*.*.*)
  - Kịch bản Workflow: `.github/workflows/release.yml` (bản sao tại `BaiTap2/release.yml`)
  - Báo cáo kỹ thuật: `BaiTap2/README.md`
  - Đóng gói Multi-stage Docker Image và đẩy tự động lên GitHub Container Registry (`ghcr.io`) với Git Tag semantic versioning.
