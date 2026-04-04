const mqtt = require('mqtt');
const mysql = require('mysql2');
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const { exec } = require('child_process');

const app = express();
app.use(express.json()); 

const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

const pendingCommands = {};
const deviceStates = { light: null, fan: null, humid: null };

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
    port: 3307,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    timezone: '+07:00' // Đảm bảo đồng bộ múi giờ Việt Nam
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
    mqttClient.subscribe('cmd/request_sync');
    mqttClient.publish('cmd/request_update', '1');
});

// --- 3. NHẬN DỮ LIỆU TỪ ESP32 & LƯU SONG SONG ---
mqttClient.on('message', (topic, message) => {
    const msgStr = message.toString();

    // A. LƯU DỮ LIỆU CẢM BIẾN
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

            // 1. Ghi vào bảng cũ (Duy trì App Flutter)
            // const sqlOld = "INSERT INTO sensor_logs (temp, humid, light, created_at) VALUES (?, ?, ?, ?)";
            // db.query(sqlOld, [data.temp, data.hum, data.light, currentTime], (err) => {
            //     if(err) console.error('❌ Lỗi lưu Sensor cũ:', err.message);
            // });

            // 2. Ghi vào bảng chuẩn Data_Sensors (Theo sơ đồ mới)
            const sensorMap = { 'temp': data.temp, 'humid': data.hum, 'light': data.light };
            Object.entries(sensorMap).forEach(([key, val]) => {
                const sqlNew = `
                    INSERT INTO Data_Sensors (idSS, Value, created_at) 
                    SELECT id, ?, ? FROM DSCB WHERE sensor_key = ?`;
                db.query(sqlNew, [val, currentTime, key], (err) => {
                    if(err) console.error(`❌ Lỗi lưu Data_Sensors (${key}):`, err.message);
                });
            });

        } catch (e) {
            console.error('❌ Lỗi định dạng JSON:', e.message);
        }
    }
    
    // B. LƯU LỊCH SỬ HÀNH ĐỘNG
    if (topic.startsWith('ack/')) {
        const device = topic.split('/')[1]; 
        const status = msgStr; 
        const currentTime = new Date();
        
        const previousStatus = deviceStates[device];
        deviceStates[device] = status;

        let isUserAction = false; 
        if (pendingCommands[device]) {
            clearTimeout(pendingCommands[device]);
            delete pendingCommands[device];
            isUserAction = true; 
        }

        const isStateChange = previousStatus !== null && previousStatus !== status;

        if (isUserAction || isStateChange) {
            const deviceName = getDeviceName(device);
            const actionText = status === 'ON' ? 'Bật' : 'Tắt';
            const statusText = 'Thành công';
            const currentTime = new Date();

            // 1. Ghi vào bảng mới Action (Lưu lịch sử hành động)
            const sqlNewAction = `
                INSERT INTO Action (idTb, Action, Status, created_at)
                SELECT id, ?, ?, ? FROM tbi WHERE Ten = ?`;
                
            db.query(sqlNewAction, [actionText, statusText, currentTime, deviceName], (err) => {
                if (err) {
                    console.error('❌ Lỗi lưu Action mới:', err.message);
                } else {
                    console.log(`💾 Đã lưu lịch sử: ${deviceName} -> ${actionText}`);
                    
                    // 2. CẬP NHẬT TRẠNG THÁI HIỆN TẠI VÀO BẢNG TBI
                    // Chúng ta chỉ UPDATE khi việc ghi log lịch sử đã thành công
                    const sqlUpdateStatus = "UPDATE tbi SET status = ? WHERE Ten = ?";
                    db.query(sqlUpdateStatus, [status, deviceName], (errUpdate) => {
                        if (errUpdate) {
                            console.error(`❌ Lỗi cập nhật status cho ${deviceName}:`, errUpdate.message);
                        } else {
                            console.log(`✅ Đã cập nhật trạng thái '${status}' vào bảng tbi cho: ${deviceName}`);
                        }
                });
            }
        });

            // Cập nhật bộ nhớ tạm của Server để tránh ghi log lặp
            deviceStates[device] = status;
    }
        
        io.emit('device_status_ack', { 
            device: (device === 'fan') ? 'temp' : device, 
            status: status 
        });
    }
    // C. XỬ LÝ YÊU CẦU ĐỒNG BỘ KHI ESP32 KHỞI ĐỘNG LẠI
    if (topic === 'cmd/request_sync') {
        console.log("🔄 ESP32 vừa khởi động, đang gửi lại trạng thái từ Database...");
        
        // Truy vấn bảng tbi để lấy trạng thái cuối cùng
        db.query("SELECT topic, status FROM tbi", (err, results) => {
            if (err) return console.error("❌ Lỗi lấy dữ liệu đồng bộ:", err.message);
            
            results.forEach(device => {
                // Map status 'ON' -> '1', 'OFF' -> '0'
                const payload = (device.status === 'ON' || device.status === 'Bật') ? '1' : '0';
                // Gửi ngược lại topic điều khiển (cmd/light, cmd/temp, cmd/humid)
                mqttClient.publish(device.topic, payload);
                console.log(`📤 Sync: ${device.topic} -> ${payload}`);
            });
        });
    }
});

// --- 4. CÁC API TRUY VẤN (Tạm thời giữ nguyên để App không lỗi) ---
app.get('/api/history', (req, res) => {
    const { device, startTime, endTime, date, statusFilter, keyword, onlyErrors, page = 1 } = req.query;
    const limit = 10; 
    const offset = (parseInt(page) - 1) * limit;

    let conditions = ["1=1"];
    let params = [];

    // 1. Lọc theo ngày
    if (date && date !== 'null' && date !== '') {
        conditions.push("DATE(a.created_at) = ?");
        params.push(date);
    }

    // 2. Lọc theo giờ
    if (startTime && endTime && startTime !== 'null' && endTime !== 'null') {
        conditions.push("TIME(a.created_at) BETWEEN ? AND ?");
        params.push(startTime, endTime);
    }

    // 3. Lọc theo thiết bị (Bảng tbi)
    if (device && device !== 'Tất cả') {
        conditions.push("t.Ten = ?");
        params.push(device);
    }

    // 4. Lọc theo trạng thái Bật/Tắt (Khớp với UI Flutter)
    if (statusFilter === 'on' || statusFilter === 'Chỉ BẬT') {
        conditions.push("a.Action = 'Bật'");
    } else if (statusFilter === 'off' || statusFilter === 'Chỉ TẮT') {
        conditions.push("a.Action = 'Tắt'");
    }

    // 5. CHỈ LỌC LỖI (Sửa lỗi bạn vừa báo)
    if (onlyErrors === 'true') {
        conditions.push("(LOWER(a.Status) = 'thất bại' OR LOWER(a.Status) = 'fail')");
    }

    // 6. SEARCH LIVE ĐA NĂNG
    if (keyword && keyword.trim() !== '') {
        const k = keyword.trim().toLowerCase();
        const p = `%${k}%`;
        
        let searchOr = [
            "LOWER(t.Ten) LIKE ?",
            "LOWER(a.Action) LIKE ?",
            "LOWER(a.Status) LIKE ?",
            "DATE_FORMAT(a.created_at, '%d/%m/%Y %H:%i:%s') LIKE ?"
        ];
        
        // Thông dịch từ khóa nhanh cho người dùng
        if (k.includes("bật") || k === "on") searchOr.push("a.Action = 'Bật'");
        if (k.includes("tắt") || k === "off") searchOr.push("a.Action = 'Tắt'");
        if (k.includes("thành công")) searchOr.push("a.Status = 'Thành công'");
        if (k.includes("thất bại") || k === "fail") searchOr.push("a.Status = 'Thất bại'");

        conditions.push(`(${searchOr.join(" OR ")})`);
        params.push(p, p, p, p);
    }

    const finalWhere = conditions.join(" AND ");

    // TRUY VẤN TỔNG SỐ
    const countSql = `SELECT COUNT(*) AS total FROM Action a JOIN tbi t ON a.idTb = t.id WHERE ${finalWhere}`;

    db.query(countSql, params, (err, countRes) => {
        if (err) return res.status(500).json({ error: "Lỗi Count: " + err.message });
        
        const totalRecords = countRes[0].total;
        const totalPages = totalRecords > 0 ? Math.ceil(totalRecords / limit) : 1; 

        // LẤY DỮ LIỆU VÀ ÉP KIỂU CHO APP FLUTTER (id, action, status, device_name...)
        const sql = `
            SELECT a.id, 
                   a.Action as action, 
                   a.Status as status, 
                   t.Ten as device_name, 
                   a.created_at,
                   -1 AS temp, 
                   (CASE 
                        WHEN a.Action = 'Bật' AND a.Status = 'Thành công' THEN 1 
                        WHEN a.Action = 'Tắt' AND a.Status = 'Thành công' THEN 0 
                        WHEN a.Action = 'Bật' AND a.Status = 'Thất bại' THEN 3 
                        WHEN a.Action = 'Tắt' AND a.Status = 'Thất bại' THEN 2 
                        ELSE 4 
                   END) AS humid,
                   (CASE 
                        WHEN t.Ten = 'Đèn chiếu sáng' THEN 1 
                        WHEN t.Ten = 'Quạt thông gió' THEN 2 
                        WHEN t.Ten = 'Máy tạo ẩm' THEN 3 
                        ELSE 1
                   END) AS light
            FROM Action a 
            JOIN tbi t ON a.idTb = t.id 
            WHERE ${finalWhere} 
            ORDER BY a.created_at DESC LIMIT ? OFFSET ?`;
            
        db.query(sql, [...params, limit, offset], (err, results) => {
            if (err) return res.status(500).json({ error: "Lỗi Select: " + err.message });
            res.json({ currentPage: parseInt(page), totalPages: totalPages, data: results });
        });
    });
});

app.get('/api/sensors', (req, res) => {
    const { keyword, page = 1, date, startTime, endTime } = req.query;
    const limit = 10;
    const offset = (parseInt(page) - 1) * limit;

    let conditions = ["1=1"];
    let params = [];

    // Lọc theo ngày/giờ trên bảng chuẩn
    if (date && date !== 'null' && date !== '') {
        conditions.push("DATE(ds.created_at) = ?");
        params.push(date);
    }
    if (startTime && endTime && startTime !== 'null' && endTime !== 'null') {
        conditions.push("TIME(ds.created_at) BETWEEN ? AND ?");
        params.push(startTime, endTime);
    }

    // Search Live: Tìm trên Tên cảm biến (bảng DSCB) hoặc Giá trị (bảng Data_Sensors)
    if (keyword && keyword.trim() !== '') {
        const p = `%${keyword.trim().toLowerCase()}%`;
        conditions.push(`(LOWER(d.Ten) LIKE ? OR CAST(ds.Value AS CHAR) LIKE ? OR DATE_FORMAT(ds.created_at, '%d/%m/%Y %H:%i:%s') LIKE ?)`);
        params.push(p, p, p);
    }

    const whereClause = conditions.join(" AND ");

    // JOIN 2 bảng để lấy Tên và Đơn vị
    const countSql = `SELECT COUNT(*) AS total FROM Data_Sensors ds JOIN DSCB d ON ds.idSS = d.id WHERE ${whereClause}`;

    db.query(countSql, params, (err, countRes) => {
        if (err) return res.status(500).json({ error: err.message });
        const totalPages = Math.ceil(countRes[0].total / limit) || 1;

        const finalSql = `
            SELECT ds.id, d.Ten as sensor_type, ds.Value as temp, ds.created_at 
            FROM Data_Sensors ds 
            JOIN DSCB d ON ds.idSS = d.id 
            WHERE ${whereClause} 
            ORDER BY ds.created_at DESC LIMIT ? OFFSET ?`;

        db.query(finalSql, [...params, limit, offset], (err, results) => {
            if (err) return res.status(500).json({ error: err.message });
            // Trả về Alias 'sensor_type' và 'temp' để App Flutter không phải sửa code
            res.json({ totalPages: totalPages, data: results });
        });
    });
});

// --- 5. SOCKET.IO: ĐIỀU KHIỂN & TIMEOUT ---
io.on('connection', (socket) => {
    socket.on('control_device', (command) => {
        const reqDevice = command.device; 
        if (['light', 'temp', 'humid'].includes(reqDevice)) {
            const topic = `cmd/${reqDevice}`;
            mqttClient.publish(topic, command.action);

            const ackDevice = reqDevice === 'temp' ? 'fan' : reqDevice;
            if (pendingCommands[ackDevice]) clearTimeout(pendingCommands[ackDevice]);

            pendingCommands[ackDevice] = setTimeout(() => {
                const deviceName = getDeviceName(ackDevice);
                const actionText = command.action === '1' ? 'Bật' : 'Tắt';
                const statusText = 'Thất bại';
                const currentTime = new Date();
                
                // Ghi log thất bại song song
                // db.query("INSERT INTO action_history (device_name, action, status, created_at) VALUES (?, ?, ?, ?)", [deviceName, actionText, statusText, currentTime]);
                const sqlNewFail = "INSERT INTO Action (idTb, Action, Status, created_at) SELECT id, ?, ?, ? FROM tbi WHERE Ten = ?";
                db.query(sqlNewFail, [actionText, statusText, currentTime, deviceName]);

                io.emit('device_status_ack', { device: reqDevice, status: 'FAIL' });
                delete pendingCommands[ackDevice];
            }, 3000);
        }
    });
});

app.get('/api/open-link', async (req, res) => {
    const url = req.query.url;
    const start = process.platform == 'darwin' ? 'open' : process.platform == 'win32' ? 'start' : 'xdg-open';
    exec(`${start} ${url}`, (err) => {
        if (err) res.status(500).send(err.message);
        else res.status(200).send("OK");
    });
});

const PORT = 3000;
server.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Backend chuẩn hóa đang chạy tại: http://localhost:${PORT}`);
});