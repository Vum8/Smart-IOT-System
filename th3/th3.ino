#include <WiFi.h>
#include <PubSubClient.h>
#include "DHT.h"

// --- 1. THÔNG TIN KẾT NỐI ---
const char* ssid = "Hmmm";
const char* password = "98766789";
const char* mqtt_server = "192.168.85.13";
const int mqtt_port = 1308;
const char* mqtt_user = "vum8";
const char* mqtt_pass = "123456";

// --- 2. KHAI BÁO CHÂN CẮM ---
const int ledLight = 5;
const int ledFan = 19;
const int ledHumid = 18;
const int ledBlink = 23;
const int lightSensorPin = 34;

#define DHTPIN 4
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

WiFiClient espClient;
PubSubClient client(espClient);

unsigned long lastMsg = 0;
unsigned long prevBlink = 0;
int ledState = LOW;

// --- HÀM GỬI TRẠNG THÁI HIỆN TẠI (ĐỒNG BỘ) ---
void sendCurrentStatus() {
  client.publish("ack/light", digitalRead(ledLight) ? "ON" : "OFF");
  client.publish("ack/fan", digitalRead(ledFan) ? "ON" : "OFF");
  client.publish("ack/humid", digitalRead(ledHumid) ? "ON" : "OFF");
  Serial.println("📢 Da dong bo trang thai thiet bi len Server!");
}

void setup_wifi() {
  delay(10);
  Serial.print("Connecting to "); Serial.println(ssid);
  WiFi.disconnect(true, true);
  delay(1000);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected. IP: ");
  Serial.println(WiFi.localIP());
}

// --- LUỒNG NHẬN LỆNH TỪ APP ---
void callback(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (int i = 0; i < length; i++) message += (char)payload[i];
  String strTopic = String(topic);

  Serial.println("Topic: " + strTopic + " | Message: " + message);

  if (strTopic == "cmd/light") {
    digitalWrite(ledLight, (message == "1") ? HIGH : LOW);
    client.publish("ack/light", (message == "1") ? "ON" : "OFF");
  }
  else if (strTopic == "cmd/temp") {
    digitalWrite(ledFan, (message == "1") ? HIGH : LOW);
    client.publish("ack/fan", (message == "1") ? "ON" : "OFF");
  }
  else if (strTopic == "cmd/humid") {
    digitalWrite(ledHumid, (message == "1") ? HIGH : LOW);
    client.publish("ack/humid", (message == "1") ? "ON" : "OFF");
  }
  else if (strTopic == "cmd/request_update") {
    sendCurrentStatus();
  }
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    String clientId = "ESP32_Vum8_" + String(random(0xffff), HEX);
    if (client.connect(clientId.c_str(), mqtt_user, mqtt_pass)) {
      Serial.println("CONNECTED");
      client.subscribe("cmd/light");
      client.subscribe("cmd/temp");
      client.subscribe("cmd/humid");
      client.subscribe("cmd/request_update");
      client.publish("cmd/request_sync", "1");
      sendCurrentStatus();
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      delay(5000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(ledLight, OUTPUT);
  pinMode(ledFan, OUTPUT);
  pinMode(ledHumid, OUTPUT);
  pinMode(ledBlink, OUTPUT);
  pinMode(lightSensorPin, INPUT);

  // digitalWrite(ledLight, LOW); Cưỡng bức tắt đèn, bỏ đi để set trạng thái cuối khi lỗi xảy ra
  // digitalWrite(ledFan, LOW);
  // digitalWrite(ledHumid, LOW);

  dht.begin();
  setup_wifi();
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
  client.setBufferSize(512);
}

void loop() {
  if (!client.connected()) reconnect();
  client.loop();

  unsigned long currentMillis = millis();

  // Blink LED trạng thái hệ thống
  if (currentMillis - prevBlink >= 500) {
    prevBlink = currentMillis;
    ledState = !ledState;
    digitalWrite(ledBlink, ledState);
  }

  // Gửi dữ liệu định kỳ mỗi 2 giây
  if (currentMillis - lastMsg >= 2000) {
    lastMsg = currentMillis;

    float h = dht.readHumidity();
    float t = dht.readTemperature();
    
    // --- SỬA LOGIC ÁNH SÁNG TẠI ĐÂY ---
    int rawLight = analogRead(lightSensorPin);
    // Đảo ngược giá trị: 4095 (tối) thành ~0, 0 (sáng) thành ~4095
    int lightValue = 4095 - rawLight; 

    if (!isnan(t) && !isnan(h)) {
      String payload = "{\"temp\":" + String(t) +
                       ",\"hum\":" + String(h) +
                       ",\"light\":" + String(lightValue) + "}";

      client.publish("sensors/data", payload.c_str());
    }

    // --- LOGIC TỰ ĐỘNG THUẬN CHIỀU ---
    // Ngưỡng 1000: Nếu dưới mức này là tối -> Bật đèn
    if (lightValue < 1300 && digitalRead(ledLight) == LOW) {
      digitalWrite(ledLight, HIGH);
      client.publish("ack/light", "ON");
      Serial.println("🌙 Tu dong: TROI TOI -> BAT DEN");
    } 
    // Ngưỡng 2500: Nếu trên mức này là đủ sáng -> Tắt đèn
    else if (lightValue > 2500 && digitalRead(ledLight) == HIGH) {
      digitalWrite(ledLight, LOW);
      client.publish("ack/light", "OFF");
      Serial.println("☀️ Tu dong: TROI SANG -> TAT DEN");
    }
  }
}