# 🚀 Smart IOT System - Project by Vum8

Hệ thống điều khiển và giám sát thiết bị IOT tích hợp giao thức MQTT.

## 📁 Cấu trúc thư mục
* **vum8_iot_app/**: 📱 Ứng dụng di động phát triển bằng Flutter.
* **vum8_iot_sever/**: 💻 Backend Node.js xử lý logic và kết nối MQTT.
* **th3/**: 🤖 Mã nguồn nạp cho Arduino/ESP32.

## 🛠 Công nghệ sử dụng
* **Frontend**: Flutter (Dart)
* **Backend**: Node.js, Express
* **Giao thức**: MQTT (để truyền nhận dữ liệu sensor/điều khiển LED)
* **Phần cứng**: Arduino, cảm biến DHT11, Light Sensor.

## ⚙️ Hướng dẫn cài đặt nhanh
1.  **Backend**: Truy cập `cd vum8_iot_sever` -> `npm install` -> `node server.js`.
2.  **App**: Truy cập `cd vum8_iot_app` -> `flutter run`.