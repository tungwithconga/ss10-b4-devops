# Session 10 – Bài 4: Custom Bridge Network & Named Volume

## Mục tiêu
Tạo custom network `app-net`, named volume `db-data`, chạy PostgreSQL `db-server` và backend `app-container` bằng Docker CLI. Chứng minh DNS nội bộ và tính bền vững dữ liệu.

## Yêu cầu
- Docker Desktop đang chạy, Linux containers.
- Image `hw-backend:v1` từ Bài 2 đã được build.
- Git Bash, WSL hoặc bash trên Linux để chạy `commands.sh`. PowerShell dùng `curl.exe`, không dùng alias `curl`.
- Cổng máy host `8082` còn trống.

## 1. Khởi tạo
```bash
bash commands.sh up
```
Script tạo `app-net`, `db-data`, PostgreSQL 15 Alpine và backend từ image Bài 2. Backend có các biến `DB_HOST=db-server`, `DB_PORT=5432`, `DB_USER=appuser`, `DB_PASSWORD=app123456`, `DB_NAME=appdb`.

**Lưu ý:** Backend mẫu của Bài 2 chỉ trả JSON, chưa có code kết nối PostgreSQL. Truyền biến môi trường **không đồng nghĩa** đã tích hợp truy vấn DB. Bài này chứng minh kết nối mạng và lưu dữ liệu DB bằng CLI.

## 2. Kiểm tra network và volume
```bash
docker network ls --filter name=app-net
docker volume ls --filter name=db-data
docker network inspect app-net
docker ps
```
Kiểm tra DNS từ container backend (Node Alpine không nhất thiết có `ping`):
```bash
docker exec app-container node -e "require('dns').lookup('db-server',(err,address)=>{if(err){console.error(err);process.exit(1)}console.log('db-server resolves to',address)})"
```
Kiểm tra TCP 5432:
```bash
docker exec app-container node -e "const s=require('net').connect(5432,'db-server');s.on('connect',()=>{console.log('Connected to db-server:5432');s.end()});s.on('error',e=>{console.error(e);process.exit(1)})"
```
Nếu muốn đúng lệnh ping của đề, có thể chạy trong container (chỉ khi image có tiện ích ping):
```bash
docker exec -it app-container ping -c 2 db-server
```
Kiểm tra HTTP API:
```bash
curl.exe -i http://localhost:8082/
```
Trên Git Bash/Linux dùng `curl -i http://localhost:8082/`.

## 3. Kiểm tra Data Persistence
Thêm một bản ghi vào PostgreSQL:
```bash
bash commands.sh insert
```
Xóa cứng container DB và tạo lại từ **cùng** named volume:
```bash
bash commands.sh recreate-db
```
Script chạy `docker rm -f db-server`, tạo lại container tên `db-server` với volume `db-data`, đợi DB sẵn sàng rồi `SELECT` bảng `persistence_test`. Nếu vẫn thấy `id=1` và `Data survives container recreation` thì dữ liệu đã được giữ lại.

Có thể kiểm tra lại:
```bash
bash commands.sh verify
```

## 4. Kết quả mong đợi
- `app-net` và `db-data` tồn tại.
- `app-container` và `db-server` ở trạng thái `Up`.
- Tên `db-server` phân giải được thành IP nội bộ từ `app-container`.
- Kết nối TCP tới PostgreSQL cổng 5432 thành công.
- Dữ liệu vẫn tồn tại sau `docker rm -f db-server` và tạo lại DB với `db-data`.

## 5. Ảnh minh chứng cần nộp
1. Network và volume: `docker network ls`, `docker volume ls`.
2. `docker network inspect app-net` và `docker ps`.
3. Kết quả phân giải DNS (hoặc ping nếu có).
4. Bản ghi trước khi xóa DB.
5. Bản ghi sau khi tạo lại DB.

## 6. Ghi chú
Không chạy `docker volume rm db-data` hoặc `docker volume prune` trong quá trình kiểm tra vì sẽ làm mất dữ liệu. Mật khẩu trong script chỉ dùng cho bài thực hành, không dùng cho production.
