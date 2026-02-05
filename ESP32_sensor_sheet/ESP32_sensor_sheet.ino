#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Keypad.h>
#include <ESP32Servo.h>
#include <SPI.h>
#include <MFRC522.h>
#include <WiFi.h>
#include <HTTPClient.h>

// ==================== C?u hình OLED ====================
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

// ==================== C?u hình Keypad ====================
const byte ROWS = 4;
const byte COLS = 4;
char keys[ROWS][COLS] = {
  {'1', '2', '3', 'A'},
  {'4', '5', '6', 'B'},
  {'7', '8', '9', 'C'},
  {'*', '0', '#', 'D'}
};
byte rowPins[ROWS] = {33, 32, 26, 17}; // Chân hàng
byte colPins[COLS] = {16, 4, 0, 2};   // Chân c?t
Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);

// ==================== C?u hình Servo, Buzzer, LED ====================
Servo myServo;
const int servoPin = 13;   // Chân di?u khi?n servo
const int buzzerPin = 15;  // Chân di?u khi?n buzzer
const int ledOpenPin = 12; // Chân LED m? c?a (dèn xanh)
const int ledClosePin = 14; // Chân LED dóng c?a (dèn d?)
bool doorLocked = true;    // Tr?ng thái c?a

// ==================== C?u hình RFID ====================
#define SS_PIN 25
#define RST_PIN 27
MFRC522 rfid(SS_PIN, RST_PIN);

// ==================== C?u hình WiFi và Google Sheets ====================
const char* ssid = "magic4pro";      // Thay b?ng SSID c?a b?n
const char* password = "27022004";   // Thay b?ng m?t kh?u WiFi
String Web_App_URL = "https://script.google.com/macros/s/AKfycbwSZu8CL3MztXlWYfjtVSkNecYr14de2gxuRSSmC6OvOT5rCR1sonaC3Vjfla_aP9Hh/exec";
String modes = "atc"; // Ch? d? m?c d?nh: di?m danh
String atc_Name = "", atc_Date = "", atc_Time_In = "", atc_Time_Out = "", atc_EntryCount = "";
String reg_Info = "";

// ==================== C?u hình HC-SR04 ====================
const int trigPin = 5;  // Chân Trig c?a HC-SR04
const int echoPin = 15;  // Chân Echo c?a HC-SR04
const float distanceThreshold = 20.0; // Ngu?ng kho?ng cách (cm) d? phát hi?n v?t c?n

// ==================== C?u hình M?t Kh?u ====================
String passcode = "1234"; // M?t kh?u m?c d?nh
String enteredCode = "";

// ==================== Ðo kho?ng cách b?ng HC-SR04 ====================
float getDistance() {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  long duration = pulseIn(echoPin, HIGH);
  float distance = duration * 0.034 / 2; // Tính kho?ng cách (cm)
  return distance;
}

// ==================== Hi?n th? lên OLED ====================
void updateOLED(const String &message, bool center = true) {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(WHITE);
  int x = center ? (SCREEN_WIDTH - (message.length() * 6)) / 2 : 0;
  display.setCursor(x, 20);
  display.println(message);
  display.display();
}

void displayAttendanceInfo(String name, String date, String timeIn, String timeOut, String entryCount) {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(WHITE);
  display.setCursor(0, 0);
  display.println("Name: " + name);
  display.println("Date: " + date);
  display.println("In: " + timeIn);
  display.println("Out: " + timeOut);
  display.println("Entry: " + entryCount);
  display.display();
}

// ==================== G?i yêu c?u HTTP d?n Google Sheets ====================
void http_Req(String str_modes, String str_uid) {
  if (WiFi.status() == WL_CONNECTED) {
    String http_req_url = Web_App_URL + "?sts=" + str_modes + "&uid=" + str_uid;
    HTTPClient http;
    http.begin(http_req_url.c_str());
    http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);
    delay(100); // Nếu bạn muốn giữ delay // Thêm delay d? tránh l?i watchdog
    int httpCode = http.GET();
    Serial.print("HTTP Status Code: ");
    Serial.println(httpCode);

    String payload;
    if (httpCode > 0) {
      payload = http.getString();
      Serial.println("Payload: " + payload);
    }
    http.end();

    String sts_Res = getValue(payload, ',', 0);

    if (sts_Res == "OK") {
      if (str_modes == "atc") {
        String atc_Info = getValue(payload, ',', 1);
        if (atc_Info == "TI_Successful" || atc_Info == "TO_Successful") {
          atc_Name = getValue(payload, ',', 2);
          atc_Date = getValue(payload, ',', 3);
          atc_Time_In = getValue(payload, ',', 4);
          atc_Time_Out = atc_Info == "TO_Successful" ? getValue(payload, ',', 5) : "";
          atc_EntryCount = getValue(payload, ',', 6);
          unlockDoor();
          displayAttendanceInfo(atc_Name, atc_Date, atc_Time_In, atc_Time_Out, atc_EntryCount);
          delay(5000);
        } else if (atc_Info == "atcInf01") {
          updateOLED("Attendance Completed");
          triggerBuzzer();
          delay(5000);
        } else if (atc_Info == "atcErr01") {
          updateOLED("Card Not Registered");
          triggerBuzzer();
          delay(5000);
        }
        atc_Name = atc_Date = atc_Time_In = atc_Time_Out = atc_EntryCount = "";
      } else if (str_modes == "reg") {
        reg_Info = getValue(payload, ',', 1);
        if (reg_Info == "R_Successful") {
          updateOLED("Card Registered");
          delay(5000);
        } else if (reg_Info == "regErr01") {
          updateOLED("Card Already Registered");
          triggerBuzzer();
          delay(5000);
        }
        reg_Info = "";
      }
    }
  } else {
    updateOLED("WiFi Disconnected");
    triggerBuzzer();
    delay(3000);
  }
}

// ==================== Tách chu?i payload ====================
String getValue(String data, char separator, int index) {
  int found = 0;
  int strIndex[] = {0, -1};
  int maxIndex = data.length() - 1;
  for (int i = 0; i <= maxIndex && found <= index; i++) {
    if (data.charAt(i) == separator || i == maxIndex) {
      found++;
      strIndex[0] = strIndex[1] + 1;
      strIndex[1] = (i == maxIndex) ? i + 1 : i;
    }
  }
  return found > index ? data.substring(strIndex[0], strIndex[1]) : "";
}

// ==================== Ð?c UID t? th? RFID ====================
int getUID(String &uid_result) {
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) {
    return 0;
  }
  char str[32] = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    byte nib1 = (rfid.uid.uidByte[i] >> 4) & 0x0F;
    byte nib2 = (rfid.uid.uidByte[i] >> 0) & 0x0F;
    str[i * 2 + 0] = nib1 < 0xA ? '0' + nib1 : 'A' + nib1 - 0xA;
    str[i * 2 + 1] = nib2 < 0xA ? '0' + nib2 : 'A' + nib2 - 0xA;
  }
  str[rfid.uid.size * 2] = '\0';
  uid_result = String(str);
  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
  return 1;
}

// ==================== Ði?u khi?n Servo ====================
void unlockDoor() {
  if (doorLocked) {
    Serial.println("MO CUA");
    updateOLED("MO CUA");
    myServo.write(180);
    delay(500); // Đợi servo di chuyển
    digitalWrite(ledOpenPin, HIGH);
    digitalWrite(ledClosePin, LOW);
    doorLocked = false;

    // Kiểm tra vật cản bằng HC-SR04
    bool obstacleDetected = true;
    unsigned long noObstacleStartTime = 0;
    bool waitingToClose = false;

    while (obstacleDetected || waitingToClose) {
      float distance = getDistance();
      Serial.print("Khoảng cách: ");
      Serial.print(distance);
      Serial.println(" cm");

      if (distance > 0 && distance < distanceThreshold) {
        updateOLED("VAT CAN DETECTED!");
        obstacleDetected = true; // Giữ cửa mở nếu có vật cản
        waitingToClose = false; // Reset thời gian chờ nếu vật cản xuất hiện lại
        noObstacleStartTime = 0;
      } else {
        updateOLED("MO CUA");
        obstacleDetected = false; // Không có vật cản
        if (!waitingToClose) {
          noObstacleStartTime = millis(); // Bắt đầu đếm thời gian khi không còn vật cản
          waitingToClose = true;
        }
      }

      // Kiểm tra nếu đã chờ đủ 3 giây mà không có vật cản
      if (waitingToClose && (millis() - noObstacleStartTime >= 3000)) {
        break; // Thoát vòng lặp để khóa cửa
      }
      delay(100); // Kiểm tra mỗi 100ms
    }
    lockDoor(); // Khóa cửa sau khi không còn vật cản trong 3 giây
  }
}

void lockDoor() {
  Serial.println("CUA KHOA");
  updateOLED("CUA KHOA");
  myServo.write(0);
  digitalWrite(ledOpenPin, LOW);
  digitalWrite(ledClosePin, HIGH);
  doorLocked = true;
}

// ==================== C?nh báo khi nh?p sai ====================
void triggerBuzzer() {
  for (int i = 0; i < 3; i++) {
    digitalWrite(buzzerPin, HIGH);
    delay(300);
    digitalWrite(buzzerPin, LOW);
    delay(300);
  }
}

// ==================== Setup ====================
void setup() {
  Serial.begin(9600);
  SPI.begin();
  rfid.PCD_Init();
  pinMode(buzzerPin, OUTPUT);
  pinMode(ledOpenPin, OUTPUT);
  pinMode(ledClosePin, OUTPUT);
  myServo.attach(servoPin);

  // C?u hình chân HC-SR04
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);

  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("? KHONG TIM THAY MAN OLED!");
    while (true);
  }

  updateOLED("HE THONG OK");
  delay(2000);

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  int timeout = 20 * 2; // 20 giây
  while (WiFi.status() != WL_CONNECTED && timeout > 0) {
    updateOLED("Connecting WiFi...");
    delay(500);
    timeout--;
  }
  if (WiFi.status() == WL_CONNECTED) {
    updateOLED("WiFi Connected");
    delay(2000);
  } else {
    updateOLED("WiFi Failed");
    delay(2000);
  }

  lockDoor();
  updateOLED(modes == "atc" ? "NHAP MA PIN HOAC QUET THE" : "QUET THE DE DANG KY");
}

// ==================== Loop ====================
void loop() {
  char key = keypad.getKey();
  String uid_result;

  // Ki?m tra th? RFID
  if (getUID(uid_result)) {
    http_Req(modes, uid_result);
  }

  // X? lý bàn phím
  if (key) {
    Serial.print(key);
    if (key == 'A') { // Chuy?n d?i ch? d?
      modes = (modes == "atc") ? "reg" : "atc";
      updateOLED(modes == "atc" ? "NHAP MA PIN HOAC QUET THE" : "QUET THE DE DANG KY");
    } else if (isDigit(key)) {
      enteredCode += key;
      updateOLED("MA PIN: " + enteredCode);
    } else if (key == '#') {
      Serial.println();
      if (enteredCode == passcode) {
        unlockDoor();
      } else {
        updateOLED("SAI PIN!");
        triggerBuzzer();
      }
      enteredCode = "";
      updateOLED(modes == "atc" ? "NHAP MA PIN HOAC QUET THE" : "QUET THE DE DANG KY");
    } else if (key == '*') {
      if (enteredCode.length() > 0) {
        enteredCode.remove(enteredCode.length() - 1);
        updateOLED("MA PIN: " + enteredCode);
      }
    }
  }

  delay(100);
}