#include <ArduinoJson.h> // Recuerda instalar esta librería en Arduino IDE
#include <HTTPClient.h>
#include <WiFi.h>
#include <WiFiClientSecure.h> // <-- Añadido para conexión HTTPS segura
#include <DHT.h>              // <-- Añadido para el sensor AM2302 (DHT22)
#include <NimBLEDevice.h>     // <-- Bluetooth LE para configurar el WiFi desde la app
#include <Preferences.h>      // <-- Memoria persistente (NVS) para guardar el WiFi
#include <time.h>

#include "root_ca.h" // Certificados raíz para validar el HTTPS de Supabase
#include "secrets.h" // Credenciales (no se sube a git; ver secrets.example.h)

// --- 1. CONFIGURACIÓN WIFI ---
// La red WiFi ya no está en el código: se recibe desde la app por Bluetooth y
// se guarda en la memoria del ESP32 (espacio de nombres "wifi").
Preferences prefs;

// Mantener pulsado BOOT este tiempo borra el WiFi guardado y reinicia en modo
// configuración
#define BOOT_BUTTON_PIN 0
#define RESET_HOLD_MS 3000

// --- 2. CONFIGURACIÓN SUPABASE ---
const char *supabase_url = SUPABASE_URL;
const char *supabase_key = SUPABASE_KEY;

// --- 3. CONFIGURACIÓN BLUETOOTH (modo configuración) ---
// Deben coincidir con lib/core/services/ble_provisioning_service.dart
#define PROV_SERVICE_UUID "6e1d0001-8f0b-4c55-9a3e-2b7c1e5a9f01"
#define CHAR_DEVICE_ID_UUID "6e1d0002-8f0b-4c55-9a3e-2b7c1e5a9f01"   // lectura: UUID del dispositivo
#define CHAR_NETWORKS_UUID "6e1d0003-8f0b-4c55-9a3e-2b7c1e5a9f01"    // lectura: redes visibles (JSON)
#define CHAR_CREDENTIALS_UUID "6e1d0004-8f0b-4c55-9a3e-2b7c1e5a9f01" // escritura: {"ssid","pass"}
#define CHAR_STATUS_UUID "6e1d0005-8f0b-4c55-9a3e-2b7c1e5a9f01"      // lectura/notificación

bool provisioningMode = false;
NimBLEServer *bleServer = nullptr;
NimBLECharacteristic *statusChar = nullptr;
NimBLECharacteristic *networksChar = nullptr;

// Credenciales recibidas por Bluetooth; se procesan en loop(), no en el
// callback (que corre en la tarea de Bluetooth)
volatile bool credentialsReceived = false;
String pendingSsid;
String pendingPass;

// El UUID único del dispositivo generado dinámicamente a partir de su dirección
// MAC
String device_uuid = "";

// Función para generar un UUID determinista y válido basado en la dirección MAC
// del ESP32
String generateDeviceUUID() {
  uint8_t mac[6];
  WiFi.macAddress(mac);
  char uuidStr[37];
  // Formato compatible con UUID v4: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
  // Namespace único para GreenBox + los 6 bytes de la MAC única
  snprintf(uuidStr, sizeof(uuidStr),
           "94ee4b0d-71d8-4a6c-8e01-%02x%02x%02x%02x%02x%02x", mac[0], mac[1],
           mac[2], mac[3], mac[4], mac[5]);
  return String(uuidStr);
}

// --- 4. CONFIGURACIÓN SENSOR DE HUMEDAD Y TEMPERATURA ---
#define DHTPIN 4      // Recomendado usar un pin digital normal (ej. 4). El 34 es solo lectura y no tiene pull-up.
#define DHTTYPE DHT22 // El AJ-AM2302 es equivalente al DHT22

DHT dht(DHTPIN, DHTTYPE);

// Cliente seguro global
WiFiClientSecure client;
// HTTPClient global para reutilizar la conexión TLS entre envíos (evita un
// handshake HTTPS completo en cada POST)
HTTPClient http;

// Intenta conectar a la red indicada; devuelve true si lo logra antes del
// tiempo límite
bool connectWiFi(const String &ssid, const String &pass, uint32_t timeoutMs) {
  Serial.print("Conectando a WiFi \"" + ssid + "\"");
  WiFi.begin(ssid.c_str(), pass.c_str());
  uint32_t start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < timeoutMs) {
    delay(500);
    Serial.print(".");
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Conectado con exito!");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
    return true;
  }
  Serial.println("\nNo se pudo conectar.");
  WiFi.disconnect();
  return false;
}

// Si BOOT se mantiene pulsado RESET_HOLD_MS, borra el WiFi y reinicia
void checkResetButton() {
  if (digitalRead(BOOT_BUTTON_PIN) != LOW) return;
  uint32_t start = millis();
  while (digitalRead(BOOT_BUTTON_PIN) == LOW) {
    if (millis() - start >= RESET_HOLD_MS) {
      Serial.println("\nBOOT mantenido: borrando WiFi guardado y reiniciando...");
      prefs.clear();
      delay(200);
      ESP.restart();
    }
    delay(20);
  }
}

// ---------------------------------------------------------------------------
// Modo configuración por Bluetooth
// ---------------------------------------------------------------------------

void setStatus(const char *status) {
  Serial.print("Estado configuración: ");
  Serial.println(status);
  if (statusChar == nullptr) return;
  statusChar->setValue((const uint8_t *)status, strlen(status));
  statusChar->notify();
}

// Escanea las redes WiFi visibles y las publica (JSON, más fuertes primero)
// para que la app las ofrezca en una lista
void scanNetworks() {
  int n = WiFi.scanNetworks();
  JsonDocument doc;
  JsonArray list = doc.to<JsonArray>();
  String json = "[]";
  for (int added = 0; added < 12;) {
    // Selección de la red más fuerte que aún no se haya añadido
    int best = -1;
    for (int i = 0; i < n; i++) {
      if (WiFi.SSID(i).isEmpty()) continue;
      bool dup = false;
      for (JsonVariant v : list) {
        if (WiFi.SSID(i) == v.as<const char *>()) {
          dup = true;
          break;
        }
      }
      if (!dup && (best < 0 || WiFi.RSSI(i) > WiFi.RSSI(best))) best = i;
    }
    if (best < 0) break;
    list.add(WiFi.SSID(best));
    added++;
    String candidate;
    serializeJson(doc, candidate);
    if (candidate.length() > 480) break; // Cabe en una lectura BLE
    json = candidate;
  }
  WiFi.scanDelete();
  networksChar->setValue((const uint8_t *)json.c_str(), json.length());
  Serial.println("Redes visibles: " + json);
}

class CredentialsCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *characteristic,
               NimBLEConnInfo &connInfo) override {
    std::string value = characteristic->getValue();
    JsonDocument doc;
    if (deserializeJson(doc, value) || !doc["ssid"].is<const char *>()) {
      setStatus("error:formato");
      return;
    }
    pendingSsid = doc["ssid"].as<const char *>();
    pendingPass = doc["pass"] | "";
    credentialsReceived = true;
  }
};

void startProvisioning() {
  provisioningMode = true;
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();

  // Nombre visible: GreenBox-XXXX (últimos 4 caracteres del UUID)
  String bleName = "GreenBox-" + device_uuid.substring(device_uuid.length() - 4);
  bleName.toUpperCase();

  NimBLEDevice::init(bleName.c_str());
  NimBLEDevice::setMTU(517);
  bleServer = NimBLEDevice::createServer();
  NimBLEService *service = bleServer->createService(PROV_SERVICE_UUID);

  NimBLECharacteristic *idChar =
      service->createCharacteristic(CHAR_DEVICE_ID_UUID, NIMBLE_PROPERTY::READ);
  idChar->setValue((const uint8_t *)device_uuid.c_str(), device_uuid.length());

  networksChar =
      service->createCharacteristic(CHAR_NETWORKS_UUID, NIMBLE_PROPERTY::READ);

  NimBLECharacteristic *credChar = service->createCharacteristic(
      CHAR_CREDENTIALS_UUID, NIMBLE_PROPERTY::WRITE);
  credChar->setCallbacks(new CredentialsCallbacks());

  statusChar = service->createCharacteristic(
      CHAR_STATUS_UUID, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);

  service->start();
  scanNetworks();
  setStatus("waiting");

  // El UUID de 128 bits va en el anuncio; el nombre, en la respuesta al escaneo
  // (juntos no caben en los 31 bytes del anuncio)
  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  NimBLEAdvertisementData advData;
  advData.setFlags(BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP);
  advData.setCompleteServices(NimBLEUUID(PROV_SERVICE_UUID));
  adv->setAdvertisementData(advData);
  NimBLEAdvertisementData scanData;
  scanData.setName(bleName.c_str());
  adv->setScanResponseData(scanData);
  adv->start();

  Serial.println("\n=============================================");
  Serial.println("  MODO CONFIGURACION BLUETOOTH ACTIVO");
  Serial.println("  Abre la app > Nueva Planta > Configurar por Bluetooth");
  Serial.println("  Nombre Bluetooth: " + bleName);
  Serial.println("=============================================\n");
}

void provisioningLoop() {
  static uint32_t lastScan = millis();
  static uint32_t lastRetry = millis();
  bool phoneConnected = bleServer->getConnectedCount() > 0;

  if (credentialsReceived) {
    credentialsReceived = false;
    setStatus("connecting");
    if (connectWiFi(pendingSsid, pendingPass, 15000)) {
      prefs.putString("ssid", pendingSsid);
      prefs.putString("pass", pendingPass);
      setStatus("connected");
      delay(1500); // Dar tiempo a que la notificación llegue a la app
      ESP.restart(); // Arranca en modo normal sin Bluetooth (más RAM para HTTPS)
    }
    setStatus("failed");
    lastScan = lastRetry = millis();
  }

  // Sin móvil conectado: refrescar la lista de redes cada 30 s
  if (!phoneConnected && millis() - lastScan > 30000) {
    scanNetworks();
    lastScan = millis();
  }

  // Si hay una red guardada (p. ej. el router estaba apagado al arrancar),
  // reintentarla cada 60 s
  if (!phoneConnected && millis() - lastRetry > 60000 && prefs.isKey("ssid")) {
    if (connectWiFi(prefs.getString("ssid"), prefs.getString("pass"), 10000)) {
      ESP.restart();
    }
    lastScan = lastRetry = millis();
  }

  checkResetButton();
  delay(50);
}

// ---------------------------------------------------------------------------
// Modo normal: lectura del sensor y envío a Supabase
// ---------------------------------------------------------------------------

void startTelemetry() {
  // Sincronizar la hora por NTP: necesaria para comprobar la vigencia del
  // certificado TLS
  configTime(0, 0, "pool.ntp.org", "time.google.com");
  Serial.print("Sincronizando hora");
  time_t now = time(nullptr);
  for (int i = 0; i < 20 && now < 1700000000; i++) {
    delay(500);
    Serial.print(".");
    now = time(nullptr);
  }
  Serial.println(now >= 1700000000 ? " OK" : " (sin NTP, se continúa)");

  // Validar el certificado del servidor contra las CA raíz de Supabase
  client.setCACert(SUPABASE_ROOT_CA);
  http.setReuse(true); // Keep-alive: mantener abierta la conexión con Supabase

  // Iniciar sensor AM2302
  dht.begin();
}

void setup() {
  Serial.begin(115200);
  pinMode(BOOT_BUTTON_PIN, INPUT_PULLUP);

  // Inicializar el WiFi antes de leer la MAC
  WiFi.mode(WIFI_STA);

  // Generar y mostrar el UUID único basado en la MAC
  device_uuid = generateDeviceUUID();
  Serial.println("\n=============================================");
  Serial.println("  🌱 GREENBOX HARDWARE INITIALIZATION 🌱  ");
  Serial.print("  UUID del dispositivo:\n  ");
  Serial.println(device_uuid);
  Serial.println("=============================================\n");

  prefs.begin("wifi", false);
  if (!prefs.isKey("ssid")) {
    Serial.println("No hay WiFi configurado.");
    startProvisioning();
    return;
  }
  if (!connectWiFi(prefs.getString("ssid"), prefs.getString("pass"), 20000)) {
    startProvisioning();
    return;
  }

  startTelemetry();
}

void sendToSupabase(float humidity, float temperature) {
  if (WiFi.status() == WL_CONNECTED) {
    // Utilizamos el endpoint de Broadcast HTTP de Supabase Realtime (No guarda
    // en Base de Datos)
    String endpoint = String(supabase_url) + "/realtime/v1/api/broadcast";

    // Usamos el cliente seguro que configuramos en el setup
    http.begin(client, endpoint);

    // Headers obligatorios de Supabase
    http.addHeader("apikey", supabase_key);
    http.addHeader("Authorization", "Bearer " + String(supabase_key));
    http.addHeader("Content-Type", "application/json");

    // Construir el cuerpo de la petición (JSON) para Supabase Realtime
    // Formato:
    // {"messages":[{"topic":"device:UUID","event":"telemetry","payload":{"humidity":X, "temperature": Y}}]}
    StaticJsonDocument<300> doc;
    JsonArray messages = doc.createNestedArray("messages");
    JsonObject message = messages.createNestedObject();

    message["topic"] = "device:" + device_uuid;
    message["event"] = "telemetry";

    JsonObject payload = message.createNestedObject("payload");
    payload["humidity"] = humidity;
    payload["temperature"] = temperature;

    String requestBody;
    serializeJson(doc, requestBody);

    // Enviar los datos
    Serial.println("Transmitiendo por WebSockets (Broadcast HTTP)...");
    int httpResponseCode = http.POST(requestBody);

    // Revisar la respuesta
    if (httpResponseCode > 0) {
      Serial.print("Exito! Codigo HTTP: ");
      Serial.println(httpResponseCode); // 200 significa "Broadcast exitoso"
    } else {
      Serial.print("Error en el envio: ");
      Serial.println(http.errorToString(httpResponseCode).c_str());
    }

    http.end(); // Con setReuse(true) la conexión TLS queda abierta para el próximo envío
  } else {
    Serial.println("Error: WiFi desconectado.");
  }
}

// Espera ms milisegundos sin dejar de vigilar el botón BOOT
void waitAndCheckButton(uint32_t ms) {
  uint32_t start = millis();
  while (millis() - start < ms) {
    checkResetButton();
    delay(20);
  }
}

void loop() {
  if (provisioningMode) {
    provisioningLoop();
    return;
  }

  // 1. Leer el sensor AM2302 (DHT22)
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();

  // 2. Validar que la lectura fue exitosa
  if (isnan(humidity) || isnan(temperature)) {
    Serial.println("Error leyendo del sensor AM2302!");
    waitAndCheckButton(2000);
    return;
  }

  // 3. Mostrar en pantalla para depuración
  Serial.print("Temperatura: ");
  Serial.print(temperature);
  Serial.print(" °C | Humedad Ambiental: ");
  Serial.print(humidity);
  Serial.println("%");

  // 4. Enviar a Supabase
  sendToSupabase(humidity, temperature);

  // 5. Esperar antes de la siguiente lectura (el AM2302 requiere ~2 segundos entre lecturas)
  waitAndCheckButton(2000);
}
