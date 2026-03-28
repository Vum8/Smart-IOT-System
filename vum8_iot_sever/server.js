const mqtt = require('mqtt');
const mysql = require('mysql2');
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const app = express();
app.use(express.json()); 

const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

const pendingCommands = {};
// THÊM DÒNG NÀY: Bộ nhớ lưu trạng thái cuối cùng của các thiết bị
const deviceStates = { light: null, fan: null, humid: null };
// Mở trình duyệt laptop
const { exec } = require('child_process');

// --- HÀM HỖ TRỢ CHUYỂN ĐỔI TÊN THIẾT BỊ ---
const getDeviceName = (deviceCode) => {
    if (deviceCode === 'light') return 'Đèn chiếu sáng';
    if (deviceCode === 'fan' || deviceCode === 'temp') return 'Quạt thông gió';
    if (deviceCode === 'humid') return 'Máy tạo ẩm';
    return 'Không xác định';
};

// --- 1. KẾT NỐI MYSQL POOL ---
const db = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'vum8_iot',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

db.getConnection((err, connection) => {
    if (err) console.error('❌ Lỗi kết nối MySQL Pool:', err.message);
    else {
        console.log('✅ Đã kết nối MySQL thành công (via Pool)');
        connection.release(); 
    }
});

// --- 2. KẾT NỐI MQTT BROKER ---
const mqttClient = mqtt.connect('mqtt://localhost:1308', {
    username: 'vum8',
    password: '123456'
});

mqttClient.on('connect', () => {
    console.log('✅ Đã kết nối tới MQTT Broker Port 1308');
    mqttClient.subscribe('sensors/data');
    mqttClient.subscribe('ack/#'); 
    mqttClient.publish('cmd/request_update', '1');
});

// --- 3. NHẬN DỮ LIỆU TỪ ESP32 ---
mqttClient.on('message', (topic, message) => {
    const msgStr = message.toString();

    // A. LƯU DỮ LIỆU CẢM BIẾN (Chỉ lưu vào sensor_logs)
    if (topic === 'sensors/data') {
        try {
            const data = JSON.parse(msgStr);
            const currentTime = new Date();

            io.emit('sensor_update', {
                temp: data.temp,
                hum: data.hum,
                light: data.light,
                time: currentTime.toLocaleTimeString()
            });

            const sql = "INSERT INTO sensor_logs (temp, humid, light, created_at) VALUES (?, ?, ?, ?)";
            db.query(sql, [data.temp, data.hum, data.light, currentTime], (err) => {
                if(err) console.error('❌ Lỗi lưu Sensor:', err.message);
            });
        } catch (e) {
            console.error('❌ Lỗi định dạng JSON:', e.message);
        }
    }
    
    // B. LƯU LỊCH SỬ HÀNH ĐỘNG (Lưu vào action_history)
    if (topic.startsWith('ack/')) {
        const device = topic.split('/')[1]; 
        const status = msgStr; 
        const currentTime = new Date();
        
        // 1. Kiểm tra sự thay đổi trạng thái
        const previousStatus = deviceStates[device];
        deviceStates[device] = status; // Cập nhật bộ nhớ với trạng thái mới nhất

        let isUserAction = false; 

        // Nếu có lệnh chờ từ người dùng
        if (pendingCommands[device]) {
            clearTimeout(pendingCommands[device]);
            delete pendingCommands[device];
            isUserAction = true; 
        }

        // 2. LOGIC LƯU THÔNG MINH:
        // - Chỉ lưu nếu Tự động thay đổi (isStateChange = true)
        // - Lần đầu tiên server chạy (previousStatus === null) thì không lưu rác
        const isStateChange = previousStatus !== null && previousStatus !== status;

        if (isUserAction || (!pendingCommands[device] && topic === 'ack/light' && isStateChange)) {
            const deviceName = getDeviceName(device);
            const actionText = status === 'ON' ? 'Bật' : 'Tắt';
            const statusText = 'Thành công';

            // GHI VÀO BẢNG MỚI: action_history
            const sqlAction = "INSERT INTO action_history (device_name, action, status, created_at) VALUES (?, ?, ?, ?)";
            db.query(sqlAction, [deviceName, actionText, statusText, currentTime], (err) => {
                if (err) console.error('❌ Lỗi lưu SQL Action:', err.message);
                else console.log(`💾 Ghi log Action: ${deviceName} -> ${actionText} (${statusText})`);
            });
        }
        
        io.emit('device_status_ack', { 
            device: (device === 'fan') ? 'temp' : device, 
            status: status 
        });
    }
});

// --- 4. API LẤY LỊCH SỬ HOẠT ĐỘNG (Đọc từ action_history, "đóng giả" cấu trúc cũ) ---
app.get('/api/history', (req, res) => {
    const { device, startTime, endTime, date, statusFilter, keyword, onlyErrors, page = 1 } = req.query;
    const limit = 10; 
    const offset = (parseInt(page) - 1) * limit;

    let conditions = ["1=1"];
    let params = [];

    // 1. Lọc theo ngày
    if (date && date !== 'null' && date !== '') {
        conditions.push("DATE(created_at) = ?");
        params.push(date);
    }
    // 2. Lọc theo khoảng giờ
    if (startTime && endTime && startTime !== 'null' && endTime !== 'null') {
        conditions.push("TIME(created_at) BETWEEN ? AND ?");
        params.push(startTime, endTime);
    }
    // 3. Lọc theo thiết bị
    if (device && device !== 'Tất cả') {
        conditions.push("device_name = ?");
        params.push(device);
    }
    // 4. Lọc theo trạng thái Bật/Tắt
    if (statusFilter === 'on' || statusFilter === 'Chỉ BẬT') {
        conditions.push("action = 'Bật'");
    } else if (statusFilter === 'off' || statusFilter === 'Chỉ TẮT') {
        conditions.push("action = 'Tắt'");
    }
    // 5. Chỉ lọc lỗi
    if (onlyErrors === 'true') {
        conditions.push("(LOWER(status) = 'thất bại' OR LOWER(status) = 'fail')");
    }

    // --- 6. SEARCH LIVE (PHẦN QUAN TRỌNG NHẤT) ---
    if (keyword && keyword.trim() !== '') {
        const k = keyword.trim().toLowerCase();
        const p = `%${k}%`;
        
        let searchOr = [];
        // Tìm theo Tên thiết bị và Ngày tháng (Dùng LIKE)
        searchOr.push("LOWER(device_name) LIKE ?");
        searchOr.push("DATE_FORMAT(created_at, '%d/%m/%Y %H:%i:%s') LIKE ?");
        params.push(p, p);

        // Thông dịch Turn On/Off -> Ép so khớp cứng (=) để không lẫn lộn
        if (k.includes("on") || k.includes("bật")) {
            searchOr.push("action = 'Bật'");
        } else if (k.includes("off") || k.includes("tắt")) {
            searchOr.push("action = 'Tắt'");
        }

        // Thông dịch Thành công/Thất bại -> Ép so khớp cứng (=) để sạch trang cuối
        if (k === 'thành công' || k === 'thanh cong') {
            searchOr.push("status = 'Thành công'");
        } else if (k === 'thất bại' || k === 'that bai') {
            searchOr.push("status = 'Thất bại'");
        }

        // Bọc toàn bộ OR trong ngoặc và nối với chuỗi AND chính
        conditions.push(`(${searchOr.join(" OR ")})`);
    }

    const finalWhere = conditions.join(" AND ");

    // ĐẾM TỔNG SỐ
    db.query(`SELECT COUNT(*) AS total FROM action_history WHERE ${finalWhere}`, params, (err, countRes) => {
        if (err) return res.status(500).json({ error: "Lỗi Count: " + err.message });
        
        const totalRecords = countRes[0].total;
        const totalPages = Math.ceil(totalRecords / limit) || 1; 

        // LẤY DỮ LIỆU
        const sql = `
            SELECT id, action, status, device_name, created_at,
                -1 AS temp, 
                (CASE 
                    WHEN action = 'Bật' AND status = 'Thành công' THEN 1 
                    WHEN action = 'Tắt' AND status = 'Thành công' THEN 0 
                    WHEN action = 'Bật' AND status = 'Thất bại' THEN 3 
                    WHEN action = 'Tắt' AND status = 'Thất bại' THEN 2 
                    ELSE 4 
                END) AS humid, 
                (CASE 
                    WHEN device_name = 'Đèn chiếu sáng' THEN 1 
                    WHEN device_name = 'Quạt thông gió' THEN 2 
                    WHEN device_name = 'Máy tạo ẩm' THEN 3 
                    ELSE 1
                END) AS light
            FROM action_history 
            WHERE ${finalWhere} 
            ORDER BY created_at DESC LIMIT ? OFFSET ?`;
            
        db.query(sql, [...params, limit, offset], (err, results) => {
            if (err) return res.status(500).json({ error: "Lỗi Select: " + err.message });
            res.json({ currentPage: parseInt(page), totalPages: totalPages, data: results });
        });
    });
});

// --- 4.1 API LẤY DỮ LIỆU CẢM BIẾN (FULL FIX - DỮ LIỆU SẼ KHÔNG CÒN BẰNG 0) ---
app.get('/api/sensors', (req, res) => {
    const { keyword, page = 1, date, startTime, endTime } = req.query;
    const limit = 10;
    const offset = (parseInt(page) - 1) * limit;

    // 1. Tạo bảng tạm Unpivot: Dùng 'temp' làm tên cột chung để khớp với Model Flutter
    let unpivotSql = `
        SELECT id, 'Nhiệt độ' as sensor_type, temp as temp, created_at FROM sensor_logs
        UNION ALL
        SELECT id, 'Độ ẩm' as sensor_type, humid as temp, created_at FROM sensor_logs
        UNION ALL
        SELECT id, 'Ánh sáng' as sensor_type, light as temp, created_at FROM sensor_logs
    `;

    let conditions = ["1=1"];
    let params = [];

    // 2. Search Live: Tìm kiếm đa năng (Tên cảm biến, Giá trị, Thời gian)
    if (keyword && keyword.trim() !== '') {
        const k = keyword.trim().toLowerCase();
        const p = `%${k}%`;
        
        let searchOr = [
            "LOWER(sensor_type) LIKE ?",
            "CAST(temp AS CHAR) LIKE ?",
            "DATE_FORMAT(created_at, '%d/%m/%Y %H:%i:%s') LIKE ?"
        ];
        
        conditions.push(`(${searchOr.join(" OR ")})`);
        params.push(p, p, p);
    }

    // 3. Lọc theo ngày (Bộ lọc chuyên sâu)
    if (date && date !== 'null' && date !== '') {
        conditions.push("DATE(created_at) = ?");
        params.push(date);
    }

    // 4. Lọc theo giờ (Bộ lọc chuyên sâu)
    if (startTime && endTime && startTime !== 'null' && endTime !== 'null') {
        conditions.push("TIME(created_at) BETWEEN ? AND ?");
        params.push(startTime, endTime);
    }

    const whereClause = conditions.join(" AND ");

    // --- THỰC THI TRUY VẤN ---
    const countSql = `SELECT COUNT(*) AS total FROM (${unpivotSql}) AS unpivoted WHERE ${whereClause}`;

    db.query(countSql, params, (err, countResults) => {
        if (err) return res.status(500).json({ error: "Lỗi Count Sensor: " + err.message });
        
        const totalRecords = countResults[0].total;
        const totalPages = Math.ceil(totalRecords / limit) || 1;

        const finalSql = `
            SELECT * FROM (${unpivotSql}) AS unpivoted 
            WHERE ${whereClause} 
            ORDER BY created_at DESC LIMIT ? OFFSET ?`;
        
        // Kết hợp params lọc và params phân trang (limit, offset)
        const finalParams = [...params, limit, offset];

        db.query(finalSql, finalParams, (err, results) => {
            if (err) return res.status(500).json({ error: "Lỗi Select Sensor: " + err.message });
            res.json({ totalPages: totalPages, data: results });
        });
    });
});

// --- 5. SOCKET.IO: XỬ LÝ ĐIỀU KHIỂN & TIMEOUT ---
io.on('connection', (socket) => {
    mqttClient.publish('cmd/request_update', '1');

    socket.on('request_data', () => {
        console.log("🔄 App yêu cầu cập nhật dữ liệu...");
        mqttClient.publish('cmd/request_update', '1');
    });

    socket.on('control_device', (command) => {
        const reqDevice = command.device; 
        
        if (['light', 'temp', 'humid'].includes(reqDevice)) {
            const topic = `cmd/${reqDevice}`;
            mqttClient.publish(topic, command.action);

            const ackDevice = reqDevice === 'temp' ? 'fan' : reqDevice;

            if (pendingCommands[ackDevice]) {
                clearTimeout(pendingCommands[ackDevice]);
            }

            pendingCommands[ackDevice] = setTimeout(() => {
                console.log(`⚠️ TIMEOUT: Thiết bị ${ackDevice} không phản hồi!`);
                
                const deviceName = getDeviceName(ackDevice);
                const actionText = command.action === '1' ? 'Bật' : 'Tắt';
                const statusText = 'Thất bại';
                const currentTime = new Date();
                
                // GHI LOG THẤT BẠI VÀO action_history
                const sqlAction = "INSERT INTO action_history (device_name, action, status, created_at) VALUES (?, ?, ?, ?)";
                db.query(sqlAction, [deviceName, actionText, statusText, currentTime], (err) => {
                    if (err) console.error('❌ Lỗi lưu Timeout Action:', err.message);
                });

                io.emit('device_status_ack', {
                    device: reqDevice, 
                    status: 'FAIL',
                    attemptAction: command.action 
                });

                delete pendingCommands[ackDevice];
            }, 3000);
        }
    });

    socket.on('disconnect', () => {});
});

// Mở trình duyệt laptop
app.get('/api/open-link', async (req, res) => {
    const url = req.query.url;
    // Lệnh start trong Windows sẽ mở trình duyệt mặc định
    const start = process.platform == 'darwin' ? 'open' : process.platform == 'win32' ? 'start' : 'xdg-open';
    
    console.log(`🚀 Đang thực thi lệnh: ${start} ${url}`);
    
    exec(`${start} ${url}`, (err) => {
        if (err) {
            console.error("Lỗi:", err);
            res.status(500).send(err.message);
        } else {
            res.status(200).send("OK");
        }
    });
});
const PORT = 3000;
server.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Backend chạy tại: http://localhost:${PORT}`);
});