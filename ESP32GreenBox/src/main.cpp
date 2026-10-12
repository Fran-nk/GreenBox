#include <ArduinoJson.h> // Recuerda instalar esta librería en Arduino IDE
#include <HTTPClient.h>
#include <WiFi.h>
#include <WiFiClientSecure.h> // <-- Añadido para conexión HTTPS segura
#include <DHT.h>              // <-- Añadido para el sensor AM2302 (DHT22)

// --- 1. CONFIGURACIÓN WIFI ---
const char *ssid = "Casa_2.4G";      // Escribe el nombre de tu WiFi
const char *password = "29499304.J"; // Escribe la contraseña

// --- 2. CONFIGURACIÓN SUPABASE ---
const char *supabase_url = "https://cflrnbpwcznnimiijluk.supabase.co";
const char *supabase_key = "sb_publishable_Z_mqEIUofpbzeMu5rNnKIQ_UQ8X_Urd";

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

// --- 3. CONFIGURACIÓN SENSOR DE HUMEDAD Y TEMPERATURA ---
#define DHTPIN 4      // Recomendado usar un pin digital normal (ej. 4). El 34 es solo lectura y no tiene pull-up.
#define DHTTYPE DHT22 // El AJ-AM2302 es equivalente al DHT22

DHT dht(DHTPIN, DHTTYPE);

// Cliente seguro global
WiFiClientSecure client;

void setup() {
  Serial.begin(115200);

  // Conectar a WiFi
  WiFi.begin(ssid, password);
  Serial.print("Conectando a WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi Conectado con exito!");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());

  // Generar y mostrar el UUID único basado en la MAC
  device_uuid = generateDeviceUUID();
  Serial.println("\n=============================================");
  Serial.println("  🌱 GREENBOX HARDWARE INITIALIZATION 🌱  ");
  Serial.print("  UUID del dispositivo (Copia y pega en la App):\n  ");
  Serial.println(device_uuid);
  Serial.println("=============================================\n");

  // Configurar el cliente para omitir la validación del certificado (Ideal para
  // MVP)
  client.setInsecure();

  // Iniciar sensor AM2302
  dht.begin();
}

void sendToSupabase(float humidity, float temperature) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
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

    http.end(); // Cerrar conexión
  } else {
    Serial.println("Error: WiFi desconectado.");
  }
}

void loop() {
  // 1. Leer el sensor AM2302 (DHT22)
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();

  // 2. Validar que la lectura fue exitosa
  if (isnan(humidity) || isnan(temperature)) {
    Serial.println("Error leyendo del sensor AM2302!");
    delay(2000);
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
  delay(5000);
}