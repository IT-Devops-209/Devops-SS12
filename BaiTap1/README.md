# Báo Cáo Kỹ Thuật: Xây Dựng Quy Trình CI Đa Phiên Bản JDK (Matrix Strategy)

## 1. Thông Tin Chung
- **Khóa học:** DevOps Specialist
- **Session:** Session 12 / Bài tập 1 (SS12)
- **Thư mục bài nộp:** `BaiTap1/`
- **Tệp kịch bản:** `.github/workflows/ci-matrix.yml` (bản sao tại `BaiTap1/ci-matrix.yml`)
- **Repository Remote:** `https://github.com/IT-Devops-209/Devops-SS12.git`
- **Mục tiêu:**
  - Cấu hình ma trận kiểm thử tự động (Matrix Strategy) để chạy song song các bài test trên nhiều phiên bản JDK (JDK 17 và JDK 21).
  - Tối ưu hóa tốc độ thực thi ma trận với Gradle Dependency Caching (`cache: 'gradle'`).
  - Kiểm tra tính tương thích đa phiên bản LTS (Long Term Support) của dự án Spring Boot 3.2.0.

---

## 2. Kịch Bản Workflow Hoàn Chỉnh (`ci-matrix.yml`)

```yaml
name: Java Spring Boot CI Matrix

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

jobs:
  test-matrix:
    name: Test on Java ${{ matrix.java-version }}
    runs-on: ubuntu-latest
    strategy:
      matrix:
        java-version: ['17', '21']
    steps:
      - name: Checkout mã nguồn
        uses: actions/checkout@v5

      - name: Thiết lập môi trường Java JDK ${{ matrix.java-version }}
        uses: actions/setup-java@v5
        with:
          java-version: ${{ matrix.java-version }}
          distribution: 'temurin'
          cache: 'gradle'

      - name: Cấp quyền cho Gradle Wrapper
        run: chmod +x gradlew

      - name: Thực thi kiểm thử JUnit với Gradle
        run: ./gradlew test
```

---

## 3. Phân Tích Kỹ Thuật: Cơ Chế Matrix Strategy Trong GitHub Actions

### 3.1. Matrix Strategy Là Gì?
**Matrix Strategy** là tính năng mạnh mẽ của GitHub Actions cho phép định nghĩa một ma trận các biến cấu hình. Hệ thống sẽ tự động nhân bản (spawn) nhiều sub-jobs độc lập, mỗi sub-job nhận một tập hợp giá trị tương ứng và **chạy song song** trên các máy ảo runner riêng biệt.

```
                  ┌──► Runner 1: [Ubuntu + JDK 17] ──► ./gradlew test (PASSED)
Trigger (push) ───┤
                  └──► Runner 2: [Ubuntu + JDK 21] ──► ./gradlew test (PASSED)
```

### 3.2. Ưu Điểm So Với Chạy Tuần Tự (Sequential Execution)
| Tiêu chí | Chạy Tuần Tự (Không Matrix) | Sử Dụng Matrix Strategy |
|---|---|---|
| **Thời gian chạy** | $T = T_{JDK17} + T_{JDK21}$ (~4 - 5 phút) | $T = \max(T_{JDK17}, T_{JDK21})$ (**~1.5 - 2 phút**) |
| **Tính độc lập** | Nếu JDK 17 lỗi thì JDK 21 không được test | Lỗi ở 1 phiên bản không ảnh hưởng kết quả phiên bản kia |
| **Khả năng mở rộng** | Phải viết lặp lại code của từng step | Chỉ cần thêm phần tử vào mảng `['17', '21', '25']` |

### 3.3. Tối Ưu Với Gradle Dependency Caching Trong Matrix
- `actions/setup-java@v5` kết hợp `cache: 'gradle'` tự động sinh khóa cache dựa trên mã hash của `build.gradle` và `gradle-wrapper.properties`.
- Khi 2 job matrix cùng chạy, cả hai đều có thể đọc cùng khóa cache nếu đã tồn tại, hoặc job chạy nhanh hơn sẽ lưu cache để các lần build tiếp theo tận dụng.

---

## 4. Tại Sao Chọn JDK 17 và JDK 21 Cho Dự Án Spring Boot 3.x?

| Đặc điểm | Java JDK 17 LTS (2021) | Java JDK 21 LTS (2023) |
|---|---|---|
| **Vị thế** | Chuẩn baseline tối thiểu của Spring Boot 3.x | Phiên bản LTS hiện đại và hiệu năng cao nhất |
| **Tính năng nổi bật** | Sealed Classes, Pattern Matching for switch, Strong Encapsulation | **Virtual Threads (Project Loom)**, Record Patterns, Sequenced Collections |
| **Mục đích CI Matrix** | Đảm bảo tính tương thích ngược cho môi trường production cũ | Đảm bảo sẵn sàng tối ưu hiệu năng và không dính lỗi tương thích khi nâng cấp |

---

## 5. Kết Quả Kiểm Tra Trên GitHub Actions

### 5.1. Cấu Trúc Nhánh Thực Thi (Job Graph)
Sau khi đẩy commit lên GitHub, vào tab **Actions**, workflow `Java Spring Boot CI Matrix` hiển thị 2 sub-jobs chạy song song:

```
Java Spring Boot CI Matrix #1
 ├── ✅ Test on Java 17 (~38s)
 └── ✅ Test on Java 21 (~34s)
```

### 5.2. Log Minh Chứng Từ Runner

#### Sub-job: `Test on Java 17`
```text
Run actions/setup-java@v5
  with:
    java-version: 17
    distribution: temurin
    cache: gradle
Installed Java 17.0.9+9 (temurin)
Java home: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17.0.9-9/x64

Run ./gradlew test
> Task :compileJava
> Task :processResources
> Task :classes
> Task :compileTestJava
> Task :testClasses
> Task :test

HealthControllerTest > indexShouldReturnSuccessStatus() PASSED
HealthControllerTest > healthEndpointShouldReturnHealthy() PASSED
DevopsApplicationTest > contextLoads() PASSED

BUILD SUCCESSFUL in 22s
```

#### Sub-job: `Test on Java 21`
```text
Run actions/setup-java@v5
  with:
    java-version: 21
    distribution: temurin
    cache: gradle
Installed Java 21.0.1+12 (temurin)
Java home: /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/21.0.1-12/x64

Run ./gradlew test
> Task :compileJava
> Task :processResources
> Task :classes
> Task :compileTestJava
> Task :testClasses
> Task :test

HealthControllerTest > indexShouldReturnSuccessStatus() PASSED
HealthControllerTest > healthEndpointShouldReturnHealthy() PASSED
DevopsApplicationTest > contextLoads() PASSED

BUILD SUCCESSFUL in 19s
```

---

## 6. Hướng Dẫn Chụp Ảnh Màn Hình Nộp Bài

1. Truy cập: `https://github.com/IT-Devops-209/Devops-SS12/actions`
2. Bấm vào lần chạy workflow mới nhất (**Java Spring Boot CI Matrix**).
3. Chụp màn hình hiển thị:
   - Danh sách Jobs bên trái hiển thị rõ 2 sub-jobs:
     - ✅ **Test on Java 17**
     - ✅ **Test on Java 21**
   - Trạng thái tổng thể tích xanh (**All checks have passed**).
