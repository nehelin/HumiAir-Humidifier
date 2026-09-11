/*
  ============================================================================
  HumiAir - Smart Humidifier (Complete, Robust & Cloud-Connected)
  ============================================================================

  Hardware Pin Map:
    DHT22 DATA     -> Pin D4 (GPIO 2)
    OLED SDA       -> Pin D2 (GPIO 4)
    OLED SCL       -> Pin D1 (GPIO 5)
    Relay Module   -> Pin D6 (GPIO 12)
    Float Switch   -> Pin D5 (GPIO 14) [Active LOW with pull-up]
    Indicator LED  -> Pin D7 (GPIO 13)

  Key Features:
    - Uses your verified working hardware control logic (DHT22, Relay, OLED, Float)
    - Native WiFiClientSecure with setInsecure() (eliminates all BearSSL timeouts)
    - Direct Firestore REST API (reliable, lightweight, no library crashes)
    - Cloud Threshold control: Uses strictly your app-set thresholds (no forced defaults)
    - Persistent EEPROM storage: Remembers custom target thresholds across reboots
    - WiFiManager for seamless one-time WiFi connection
  ============================================================================
*/

#include <ESP8266WiFi.h>
#include <WiFiClientSecure.h>
#include <ESP8266HTTPClient.h>
#include <WiFiManager.h>
#include <DHT.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <EEPROM.h>

// ================= CONFIG =================
#define DHTPIN         D4
#define DHTTYPE        DHT22
#define RELAY_PIN      D6
#define FLOAT_PIN      D5
#define LED_PIN        D7

#define SCREEN_WIDTH   128
#define SCREEN_HEIGHT  64
#define OLED_RESET     -1
#define OLED_ADDRESS   0x3C

#define RELAY_ON       LOW    // active-LOW relay module
#define RELAY_OFF      HIGH

#define MIST_USES_BUTTON false // false = relay cuts/restores power directly
#define BUTTON_PULSE_MS  250

// Firebase Firestore Config
#define FIREBASE_PROJECT_ID "humiair-humidifier"
#define FIREBASE_API_KEY    "AIzaSyDuc4rnzo9BZFBR35qiNx7GKVu2xROwsmk"

// Timing Intervals
const unsigned long SENSOR_INTERVAL_MS   = 2000;  // DHT22 & OLED update (every 2s)
const unsigned long STATUS_WRITE_MS      = 5000;  // Send live data to App (every 5s)
const unsigned long THRESHOLD_POLL_MS    = 10000; // Check App thresholds (every 10s)
const unsigned long HISTORY_LOG_MS       = 60000; // Save history chart entry (every 60s)
// ============================================

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
DHT dht(DHTPIN, DHTTYPE);

bool oledOK              = false;
bool mistMakerState      = false;
bool waterEmpty          = false;
bool thresholdConfigured = false;

float lastHumidity       = NAN;
float lastTemperature    = NAN;
float lowThreshold       = 0.0;
float highThreshold      = 0.0;

unsigned long lastSensorRead     = 0;
unsigned long lastStatusWrite    = 0;
unsigned long lastThresholdFetch = 0;
unsigned long lastHistoryLog     = 0;

String deviceId;

// ================= DEVICE ID =================
String buildDeviceId() {
  String mac = WiFi.macAddress();
  mac.replace(":", "");
  mac.toLowerCase();
  return "humiair_" + mac;
}

// ================= EEPROM STORAGE =============
struct StoredConfig {
  char marker[4];
  float savedLow;
  float savedHigh;
};

void saveThresholdsToEEPROM(float low, float high) {
  StoredConfig cfg;
  strncpy(cfg.marker, "HAOK", sizeof(cfg.marker));
  cfg.savedLow = low;
  cfg.savedHigh = high;
  EEPROM.begin(sizeof(StoredConfig));
  EEPROM.put(0, cfg);
  EEPROM.commit();
  EEPROM.end();
}

void loadThresholdsFromEEPROM() {
  StoredConfig cfg;
  EEPROM.begin(sizeof(StoredConfig));
  EEPROM.get(0, cfg);
  EEPROM.end();

  if (strncmp(cfg.marker, "HAOK", 4) == 0) {
    if (cfg.savedLow > 0 && cfg.savedHigh > cfg.savedLow) {
      lowThreshold = cfg.savedLow;
      highThreshold = cfg.savedHigh;
      thresholdConfigured = true;
      Serial.printf("Loaded custom target from EEPROM: Low %.1f%%, High %.1f%%\n", lowThreshold, highThreshold);
    }
  }
}

// ================= HARDWARE CONTROL ===========
void setMistMaker(bool turnOn) {
  if (MIST_USES_BUTTON) {
    Serial.print("Pulsing mist maker button to turn ");
    Serial.println(turnOn ? "ON" : "OFF");
    digitalWrite(RELAY_PIN, RELAY_ON);
    delay(BUTTON_PULSE_MS);
    digitalWrite(RELAY_PIN, RELAY_OFF);
  } else {
    Serial.print("Setting mist maker power ");
    Serial.println(turnOn ? "ON" : "OFF");
    digitalWrite(RELAY_PIN, turnOn ? RELAY_ON : RELAY_OFF);
  }
  mistMakerState = turnOn;
}

void updateDisplay() {
  if (!oledOK) return;

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  // Header
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.print("HumiAir ");
  display.println(WiFi.status() == WL_CONNECTED ? "[Online]" : "[Offline]");
  display.drawLine(0, 10, 128, 10, SSD1306_WHITE);

  // Humidity
  display.setTextSize(2);
  display.setCursor(0, 16);
  if (isnan(lastHumidity)) {
    display.println("--.- %");
  } else {
    display.print(lastHumidity, 1);
    display.println(" %");
  }

  // Temperature
  display.setTextSize(1);
  display.setCursor(0, 38);
  display.print("Temp: ");
  if (isnan(lastTemperature)) {
    display.println("--.- C");
  } else {
    display.print(lastTemperature, 1);
    display.println(" C");
  }

  // Water Status
  display.setCursor(0, 48);
  display.print("Water: ");
  display.println(waterEmpty ? "!EMPTY!" : "OK");

  // Target Threshold Status
  display.setCursor(0, 56);
  if (thresholdConfigured) {
    display.printf("Target: %d-%d%%", (int)lowThreshold, (int)highThreshold);
  } else {
    display.print("Target: Set in App");
  }

  display.display();
}

// ================= FIRESTORE CLOUD REST ============
void sendCloudStatus() {
  if (isnan(lastHumidity) || isnan(lastTemperature)) return;
  if (WiFi.status() != WL_CONNECTED) return;

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(6000);

  HTTPClient https;
  String url = "https://firestore.googleapis.com/v1/projects/";
  url += FIREBASE_PROJECT_ID;
  url += "/databases/(default)/documents/devices/";
  url += deviceId;
  url += "/status/current?key=";
  url += FIREBASE_API_KEY;

  if (https.begin(client, url)) {
    https.addHeader("Content-Type", "application/json");

    String json = "{\"fields\":{";
    json += "\"humidity\":{\"doubleValue\":" + String(lastHumidity, 1) + "},";
    json += "\"temperature\":{\"doubleValue\":" + String(lastTemperature, 1) + "},";
    json += "\"mistOn\":{\"booleanValue\":" + String(mistMakerState ? "true" : "false") + "},";
    json += "\"waterEmpty\":{\"booleanValue\":" + String(waterEmpty ? "true" : "false") + "}";
    json += "}}";

    int code = https.PATCH(json);
    if (code == 200) {
      Serial.println("Cloud Sync -> Status written to Firestore successfully!");
    } else {
      Serial.printf("Cloud Sync -> Status write response: HTTP %d\n", code);
    }
    https.end();
  }
}

void fetchCloudThresholds() {
  if (WiFi.status() != WL_CONNECTED) return;

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(6000);

  HTTPClient https;
  String url = "https://firestore.googleapis.com/v1/projects/";
  url += FIREBASE_PROJECT_ID;
  url += "/databases/(default)/documents/devices/";
  url += deviceId;
  url += "/settings/thresholds?key=";
  url += FIREBASE_API_KEY;

  if (https.begin(client, url)) {
    int code = https.GET();
    if (code == 200) {
      String payload = https.getString();

      auto parseVal = [](const String& text, const String& key) -> float {
        int idx = text.indexOf(key);
        if (idx == -1) return 0;
        int dIdx = text.indexOf("doubleValue", idx);
        int iIdx = text.indexOf("integerValue", idx);
        int target = -1;
        if (dIdx != -1 && (iIdx == -1 || dIdx < iIdx)) {
          target = text.indexOf(":", dIdx) + 1;
        } else if (iIdx != -1) {
          target = text.indexOf(":", iIdx) + 1;
        }
        if (target != -1) {
          while (target < (int)text.length() && (text[target] == ' ' || text[target] == '"')) {
            target++;
          }
          return text.substring(target).toFloat();
        }
        return 0;
      };

      float newLow  = parseVal(payload, "lowerThreshold");
      float newHigh = parseVal(payload, "upperThreshold");

      if (newLow > 0 && newHigh > newLow) {
        if (newLow != lowThreshold || newHigh != highThreshold || !thresholdConfigured) {
          lowThreshold = newLow;
          highThreshold = newHigh;
          thresholdConfigured = true;
          saveThresholdsToEEPROM(lowThreshold, highThreshold);
          Serial.printf("App Thresholds Synced & Saved -> Low: %.1f%%  High: %.1f%%\n", lowThreshold, highThreshold);
        }
      }
    }
    https.end();
  }
}

void sendCloudHistory() {
  if (isnan(lastHumidity) || isnan(lastTemperature)) return;
  if (WiFi.status() != WL_CONNECTED) return;

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(6000);

  HTTPClient https;
  String url = "https://firestore.googleapis.com/v1/projects/";
  url += FIREBASE_PROJECT_ID;
  url += "/databases/(default)/documents/devices/";
  url += deviceId;
  url += "/sensorData?key=";
  url += FIREBASE_API_KEY;

  if (https.begin(client, url)) {
    https.addHeader("Content-Type", "application/json");

    String json = "{\"fields\":{";
    json += "\"humidity\":{\"doubleValue\":" + String(lastHumidity, 1) + "},";
    json += "\"temperature\":{\"doubleValue\":" + String(lastTemperature, 1) + "},";
    json += "\"mistOn\":{\"booleanValue\":" + String(mistMakerState ? "true" : "false") + "},";
    json += "\"waterEmpty\":{\"booleanValue\":" + String(waterEmpty ? "true" : "false") + "}";
    json += "}}";

    https.POST(json);
    https.end();
  }
}

// ================= SETUP =====================
void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println();
  Serial.println("========================================");
  Serial.println("  HumiAir - Smart Humidifier Starting   ");
  Serial.println("========================================");

  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, RELAY_OFF);

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  pinMode(FLOAT_PIN, INPUT_PULLUP);

  dht.begin();
  Serial.println("DHT22 initialized.");

  Wire.begin(); // D2=SDA, D1=SCL
  if (display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDRESS)) {
    oledOK = true;
    Serial.println("OLED initialized OK.");
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1);
    display.setCursor(0, 0);
    display.println("HumiAir Starting...");
    display.display();
  } else {
    oledOK = false;
    Serial.println("OLED NOT FOUND (continuing without display).");
  }

  // Load custom user thresholds from EEPROM
  loadThresholdsFromEEPROM();

  // WiFi Connection via WiFiManager
  WiFiManager wifiManager;
  wifiManager.setConfigPortalTimeout(180);
  bool connected = wifiManager.autoConnect("HumiAir-Setup");

  deviceId = buildDeviceId();
  Serial.println("========================================");
  Serial.print("Device ID : ");
  Serial.println(deviceId);
  Serial.println("========================================");

  if (connected) {
    Serial.println("WiFi connected successfully.");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
    // Initial fetch from cloud
    fetchCloudThresholds();
  } else {
    Serial.println("WiFi not connected. Running in offline standalone mode.");
  }

  Serial.println("Setup complete. Entering main loop.");
  Serial.println("========================================");
}

// ================= MAIN LOOP =================
void loop() {
  unsigned long now = millis();

  // 1. Local Sensor, Mist Control & OLED (Every 2 seconds)
  if (now - lastSensorRead >= SENSOR_INTERVAL_MS) {
    lastSensorRead = now;

    float h = dht.readHumidity();
    float t = dht.readTemperature();

    if (isnan(h) || isnan(t)) {
      Serial.println("WARNING: Failed to read from DHT sensor! Keeping last good reading.");
    } else {
      lastHumidity = h;
      lastTemperature = t;
    }

    waterEmpty = (digitalRead(FLOAT_PIN) == LOW);
    digitalWrite(LED_PIN, waterEmpty ? HIGH : LOW);

    // Mist maker logic based strictly on user configured thresholds
    if (waterEmpty) {
      if (mistMakerState) setMistMaker(false); // Safety: no water, force OFF
    } else if (thresholdConfigured && !isnan(lastHumidity)) {
      if (!mistMakerState && lastHumidity < lowThreshold) {
        setMistMaker(true);
      } else if (mistMakerState && lastHumidity >= highThreshold) {
        setMistMaker(false);
      }
    } else if (!thresholdConfigured) {
      if (mistMakerState) setMistMaker(false);
    }

    // Serial monitor status
    Serial.print("Humidity: ");
    Serial.print(lastHumidity, 1);
    Serial.print(" %\tTemp: ");
    Serial.print(lastTemperature, 1);
    Serial.print(" C\tMist: ");
    Serial.print(mistMakerState ? "ON" : "OFF");
    Serial.print("\tWater: ");
    Serial.print(waterEmpty ? "EMPTY" : "OK");
    if (thresholdConfigured) {
      Serial.printf("\tTarget: %.1f-%.1f%%\n", lowThreshold, highThreshold);
    } else {
      Serial.println("\tTarget: [Waiting for App Target]");
    }

    if (oledOK) {
      updateDisplay();
    }
  }

  // 2. Cloud Operations (Staggered non-blocking)
  if (WiFi.status() == WL_CONNECTED) {
    // Send live data to Mobile App (every 5 seconds)
    if (now - lastStatusWrite >= STATUS_WRITE_MS) {
      lastStatusWrite = now;
      sendCloudStatus();
    }
    // Fetch user target threshold from App (every 10 seconds)
    else if (now - lastThresholdFetch >= THRESHOLD_POLL_MS) {
      lastThresholdFetch = now;
      fetchCloudThresholds();
    }
    // Log history for charts (every 60 seconds)
    else if (now - lastHistoryLog >= HISTORY_LOG_MS) {
      lastHistoryLog = now;
      sendCloudHistory();
    }
  }
}
