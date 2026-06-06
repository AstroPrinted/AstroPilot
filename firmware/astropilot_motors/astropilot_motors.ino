#include <Arduino.h>
#include <AccelStepper.h>

// Set to 0 if BLE libraries cause a compile issue. Serial will keep working.
#define ENABLE_BLE 1

#if ENABLE_BLE
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#endif

// AstroPilot OE4 - ESP32 + 2x 28BYJ-48 + 2x ULN2003
// Commands are JSON strings processed only by handleJsonCommand(String json).
// Serial and BLE both delegate to that same function.

const long STEPS_PER_REV = 4096;
const float STEPS_PER_DEGREE = STEPS_PER_REV / 360.0f;

const float ALT_MIN_DEG = -90.0f;
const float ALT_MAX_DEG = 90.0f;
const float AZ_MIN_DEG = 0.0f;
const float AZ_MAX_DEG = 360.0f;

const float MOTOR_MAX_SPEED = 600.0f;
const float MOTOR_ACCELERATION = 300.0f;
const unsigned long ROUTINE_PAUSE_MS = 600;
const unsigned long WATCHDOG_TIMEOUT_MS = 1000;
const unsigned int COMMAND_MAX_LENGTH = 256;

// Real validated pinout.
const uint8_t ALT_IN1 = 25;
const uint8_t ALT_IN2 = 26;
const uint8_t ALT_IN3 = 27;
const uint8_t ALT_IN4 = 14;

const uint8_t AZ_IN1 = 32;
const uint8_t AZ_IN2 = 33;
const uint8_t AZ_IN3 = 13;
const uint8_t AZ_IN4 = 12;

// AccelStepper HALF4WIRE pin order is IN1, IN3, IN2, IN4 for 28BYJ-48.
AccelStepper motorAlt(AccelStepper::HALF4WIRE, ALT_IN1, ALT_IN3, ALT_IN2, ALT_IN4);
AccelStepper motorAz(AccelStepper::HALF4WIRE, AZ_IN1, AZ_IN3, AZ_IN2, AZ_IN4);

#if ENABLE_BLE
const char* BLE_DEVICE_NAME = "AstroPilot-OE4";
const char* BLE_SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
const char* BLE_RX_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"; // Flutter -> ESP32 write
const char* BLE_TX_UUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; // ESP32 -> Flutter notify

BLECharacteristic* txCharacteristic = nullptr;
bool bleClientConnected = false;
#endif

enum MoveKind {
  MOVE_NONE,
  MOVE_GOTO,
  MOVE_NUDGE,
  MOVE_HOME,
};

struct RoutineStep {
  const char* label;
  bool home;
  bool status;
  float altDeg;
  float azDeg;
};

const RoutineStep OE4_ROUTINE[] = {
  {"HOME", true, false, 0.0f, 0.0f},
  {"GOTO alt=0 az=45", false, false, 0.0f, 45.0f},
  {"GOTO alt=0 az=30", false, false, 0.0f, 30.0f},
  {"GOTO alt=0 az=120", false, false, 0.0f, 120.0f},
  {"HOME", true, false, 0.0f, 0.0f},
  {"STATUS", false, true, 0.0f, 0.0f},
};
const int OE4_ROUTINE_COUNT = sizeof(OE4_ROUTINE) / sizeof(OE4_ROUTINE[0]);

String serialBuffer;
bool movementActive = false;
MoveKind activeMoveKind = MOVE_NONE;

bool routineActive = false;
bool routineWaiting = false;
int routineIndex = 0;
unsigned long routineNextAtMs = 0;

bool watchdogEnabled = false;
unsigned long lastPingAtMs = 0;

void handleJsonCommand(String json);
void sendResponse(const String& message);
void setupBle();

#if ENABLE_BLE
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* server) override {
    bleClientConnected = true;
    Serial.println("BLE conectado");
  }

  void onDisconnect(BLEServer* server) override {
    bleClientConnected = false;
    Serial.println("BLE desconectado. Advertising reiniciado.");
    BLEDevice::startAdvertising();
  }
};

class RxCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) override {
    String value = String(characteristic->getValue().c_str());
    value.trim();
    if (value.length() == 0) return;
    if (value.length() > COMMAND_MAX_LENGTH) {
      sendResponse("ERROR: comando demasiado largo");
      return;
    }

    Serial.print("BLE RX: ");
    Serial.println(value);
    handleJsonCommand(value);
  }
};
#endif

long degreesToSteps(float degrees) {
  return (long)round(degrees * STEPS_PER_DEGREE);
}

float stepsToDegrees(long steps) {
  return steps / STEPS_PER_DEGREE;
}

float normalizeAzimuth(float azDeg) {
  while (azDeg < 0.0f) azDeg += 360.0f;
  while (azDeg >= 360.0f) azDeg -= 360.0f;
  return azDeg;
}

void sendResponse(const String& message) {
  Serial.println(message);

#if ENABLE_BLE
  if (bleClientConnected && txCharacteristic != nullptr) {
    txCharacteristic->setValue((uint8_t*)message.c_str(), message.length());
    txCharacteristic->notify();
  }
#endif
}

bool isNumericLiteral(String raw) {
  raw.trim();
  if (raw.length() == 0) return false;

  bool hasDigit = false;
  bool hasDecimalPoint = false;

  for (int i = 0; i < raw.length(); i++) {
    char ch = raw[i];
    if (ch >= '0' && ch <= '9') {
      hasDigit = true;
      continue;
    }
    if ((ch == '-' || ch == '+') && i == 0) continue;
    if (ch == '.' && !hasDecimalPoint) {
      hasDecimalPoint = true;
      continue;
    }
    return false;
  }

  return hasDigit;
}

bool extractJsonString(String json, const String& key, String& value) {
  String marker = String("\"") + key + String("\"");
  int keyIndex = json.indexOf(marker);
  if (keyIndex < 0) return false;

  int colonIndex = json.indexOf(':', keyIndex + marker.length());
  if (colonIndex < 0) return false;

  int firstQuote = json.indexOf('"', colonIndex + 1);
  if (firstQuote < 0) return false;

  int secondQuote = json.indexOf('"', firstQuote + 1);
  if (secondQuote < 0) return false;

  value = json.substring(firstQuote + 1, secondQuote);
  value.trim();
  return value.length() > 0;
}

bool hasJsonKey(String json, const String& key) {
  String marker = String("\"") + key + String("\"");
  return json.indexOf(marker) >= 0;
}

bool extractJsonBool(String json, const String& key, bool& value) {
  String marker = String("\"") + key + String("\"");
  int keyIndex = json.indexOf(marker);
  if (keyIndex < 0) return false;

  int colonIndex = json.indexOf(':', keyIndex + marker.length());
  if (colonIndex < 0) return false;

  int endIndex = colonIndex + 1;
  while (endIndex < json.length() && json[endIndex] != ',' && json[endIndex] != '}') {
    endIndex++;
  }

  String raw = json.substring(colonIndex + 1, endIndex);
  raw.trim();
  raw.toLowerCase();

  if (raw == "true") {
    value = true;
    return true;
  }
  if (raw == "false") {
    value = false;
    return true;
  }

  return false;
}

bool extractJsonFloat(String json, const String& key, float& value) {
  String marker = String("\"") + key + String("\"");
  int keyIndex = json.indexOf(marker);
  if (keyIndex < 0) return false;

  int colonIndex = json.indexOf(':', keyIndex + marker.length());
  if (colonIndex < 0) return false;

  int endIndex = colonIndex + 1;
  while (endIndex < json.length() && json[endIndex] != ',' && json[endIndex] != '}') {
    endIndex++;
  }

  String raw = json.substring(colonIndex + 1, endIndex);
  raw.trim();
  if (!isNumericLiteral(raw)) return false;

  value = raw.toFloat();
  return true;
}

void sendStatus() {
  String status = String("STATUS -> posicion interna actual: alt=") +
                  String(motorAlt.currentPosition()) +
                  String(" pasos (") +
                  String(stepsToDegrees(motorAlt.currentPosition()), 2) +
                  String(" deg), az=") +
                  String(motorAz.currentPosition()) +
                  String(" pasos (") +
                  String(stepsToDegrees(motorAz.currentPosition()), 2) +
                  String(" deg), moving=") +
                  String(movementActive ? "true" : "false") +
                  String(", watchdog=") +
                  String(watchdogEnabled ? "true" : "false");
  sendResponse(status);
}

void cancelRoutine(const String& reason) {
  if (routineActive) sendResponse(reason);
  routineActive = false;
  routineWaiting = false;
  routineIndex = 0;
}

void startMove(long altSteps, long azSteps, MoveKind kind) {
  motorAlt.moveTo(altSteps);
  motorAz.moveTo(azSteps);
  activeMoveKind = kind;
  movementActive = true;
}

void startGoto(float altDeg, float azDeg) {
  long altSteps = degreesToSteps(altDeg);
  long azSteps = degreesToSteps(azDeg);

  sendResponse(
    String("Comando: GOTO alt=") + String(altDeg, 2) +
    String(" deg, az=") + String(azDeg, 2) +
    String(" deg -> alt=") + String(altSteps) +
    String(" pasos, az=") + String(azSteps) + String(" pasos")
  );

  startMove(altSteps, azSteps, MOVE_GOTO);
}

void startNudge(float deltaAltDeg, float deltaAzDeg) {
  float currentAltDeg = stepsToDegrees(motorAlt.currentPosition());
  float currentAzDeg = stepsToDegrees(motorAz.currentPosition());
  float nextAltDeg = currentAltDeg + deltaAltDeg;
  float nextAzDeg = normalizeAzimuth(currentAzDeg + deltaAzDeg);

  if (nextAltDeg < ALT_MIN_DEG) nextAltDeg = ALT_MIN_DEG;
  if (nextAltDeg > ALT_MAX_DEG) nextAltDeg = ALT_MAX_DEG;

  sendResponse(
    String("Comando: NUDGE dAlt=") + String(deltaAltDeg, 2) +
    String(" deg, dAz=") + String(deltaAzDeg, 2) +
    String(" deg -> alt=") + String(nextAltDeg, 2) +
    String(" deg, az=") + String(nextAzDeg, 2) + String(" deg")
  );

  startMove(degreesToSteps(nextAltDeg), degreesToSteps(nextAzDeg), MOVE_NUDGE);
}

void setCurrentLogicalPosition(float altDeg, float azDeg) {
  if (movementActive) {
    sendResponse("ERROR: SET_POSITION requiere motores detenidos");
    return;
  }

  long altSteps = degreesToSteps(altDeg);
  long azSteps = degreesToSteps(azDeg);

  motorAlt.setCurrentPosition(altSteps);
  motorAz.setCurrentPosition(azSteps);
  movementActive = false;
  activeMoveKind = MOVE_NONE;

  sendResponse(
    String("SET_POSITION OK -> alt=") + String(altDeg, 4) +
    String(" deg, az=") + String(azDeg, 4) +
    String(" deg")
  );
  sendStatus();
}

void startHome() {
  sendResponse("Comando: HOME -> Volver a Cero");
  startMove(0, 0, MOVE_HOME);
}

void stopMotors() {
  motorAlt.stop();
  motorAz.stop();
  motorAlt.moveTo(motorAlt.currentPosition());
  motorAz.moveTo(motorAz.currentPosition());
  movementActive = false;
  activeMoveKind = MOVE_NONE;
  cancelRoutine("Rutina OE4 cancelada por STOP");
  sendResponse("STOP Completado -> movimiento detenido");
  sendStatus();
}

void handlePing() {
  lastPingAtMs = millis();
  sendResponse("{\"status\":\"OK\",\"msg\":\"PONG\"}");
}

void setWatchdogEnabled(bool enabled) {
  watchdogEnabled = enabled;
  lastPingAtMs = millis();

  sendResponse(
    String("{\"status\":\"OK\",\"watchdog\":") +
    String(watchdogEnabled ? "true" : "false") +
    String("}")
  );
}

void stopMotorsForWatchdog(unsigned long elapsedMs) {
  motorAlt.stop();
  motorAz.stop();
  motorAlt.moveTo(motorAlt.currentPosition());
  motorAz.moveTo(motorAz.currentPosition());

  movementActive = false;
  activeMoveKind = MOVE_NONE;
  routineActive = false;
  routineWaiting = false;
  routineIndex = 0;

  sendResponse(
    String("ALERTA: conexión perdida. Motores detenidos en ") +
    String(elapsedMs) +
    String(" ms")
  );
}

void updateWatchdog() {
  if (!watchdogEnabled || !movementActive) return;
  if (lastPingAtMs == 0) return;

  unsigned long elapsedMs = millis() - lastPingAtMs;
  if (elapsedMs <= WATCHDOG_TIMEOUT_MS) return;

  stopMotorsForWatchdog(elapsedMs);
}

void scheduleNextRoutineStep() {
  if (!routineActive) return;

  if (routineIndex >= OE4_ROUTINE_COUNT) {
    routineActive = false;
    routineWaiting = false;
    sendResponse("TEST_ROUTINE Completado");
    return;
  }

  routineWaiting = true;
  routineNextAtMs = millis() + ROUTINE_PAUSE_MS;
}

void runRoutineStep() {
  if (!routineActive || movementActive) return;

  if (routineIndex >= OE4_ROUTINE_COUNT) {
    routineActive = false;
    sendResponse("TEST_ROUTINE Completado");
    return;
  }

  const RoutineStep& step = OE4_ROUTINE[routineIndex];
  sendResponse(
    String("Rutina OE4 paso ") + String(routineIndex + 1) +
    String("/") + String(OE4_ROUTINE_COUNT) +
    String(": ") + String(step.label)
  );

  if (step.status) {
    sendStatus();
    routineIndex++;
    scheduleNextRoutineStep();
    return;
  }

  if (step.home) {
    startHome();
    return;
  }

  startGoto(step.altDeg, step.azDeg);
}

void startTestRoutine() {
  if (movementActive) {
    sendResponse("TEST_ROUTINE no iniciado: movimiento activo. Envie STOP o espere a que termine.");
    return;
  }

  routineActive = true;
  routineWaiting = false;
  routineIndex = 0;
  sendResponse("TEST_ROUTINE iniciado: HOME -> 0/45 -> 0/30 -> 0/120 -> HOME -> STATUS");
  runRoutineStep();
}

void updateRoutine() {
  if (!routineActive || !routineWaiting) return;

  if ((long)(millis() - routineNextAtMs) >= 0) {
    routineWaiting = false;
    runRoutineStep();
  }
}

void updateMovementCompletion() {
  if (!movementActive) return;
  if (motorAlt.distanceToGo() != 0 || motorAz.distanceToGo() != 0) return;

  MoveKind completedKind = activeMoveKind;
  movementActive = false;
  activeMoveKind = MOVE_NONE;

  if (completedKind == MOVE_GOTO) {
    sendResponse("GOTO Completado");
  } else if (completedKind == MOVE_NUDGE) {
    sendResponse("NUDGE Completado");
  } else if (completedKind == MOVE_HOME) {
    sendResponse("HOME Completado");
    sendResponse(
      String("Comando: Volver a Cero -> posicion interna actual: alt=") +
      String(motorAlt.currentPosition()) +
      String(" pasos, az=") +
      String(motorAz.currentPosition()) +
      String(" pasos")
    );
  }

  if (routineActive) {
    routineIndex++;
    scheduleNextRoutineStep();
  }
}

void handleJsonCommand(String json) {
  json.trim();

  if (json.length() > COMMAND_MAX_LENGTH) {
    sendResponse("ERROR: comando demasiado largo");
    return;
  }

  if (!json.startsWith("{") || !json.endsWith("}")) {
    sendResponse("ERROR: JSON invalido");
    return;
  }

  String cmd;
  if (!extractJsonString(json, "cmd", cmd)) {
    sendResponse("ERROR: campos requeridos ausentes");
    return;
  }

  cmd.toUpperCase();

  if (cmd == "STOP") {
    stopMotors();
    return;
  }

  if (cmd == "PING") {
    handlePing();
    return;
  }

  if (cmd == "ENABLE_WATCHDOG") {
    bool enabled = false;
    if (!hasJsonKey(json, "enabled")) {
      sendResponse("ERROR: campos requeridos ausentes");
      return;
    }
    if (!extractJsonBool(json, "enabled", enabled)) {
      sendResponse("ERROR: JSON invalido");
      return;
    }

    setWatchdogEnabled(enabled);
    return;
  }

  if (cmd == "STATUS") {
    sendStatus();
    return;
  }

  if (cmd == "TEST_ROUTINE") {
    startTestRoutine();
    return;
  }

  if (routineActive) {
    cancelRoutine("Rutina OE4 cancelada por comando manual");
  }

  if (cmd == "HOME") {
    startHome();
    return;
  }

  if (cmd == "GOTO") {
    float altDeg = 0.0f;
    float azDeg = 0.0f;

    if (!hasJsonKey(json, "alt") || !hasJsonKey(json, "az")) {
      sendResponse("ERROR: campos requeridos ausentes");
      return;
    }

    if (!extractJsonFloat(json, "alt", altDeg) || !extractJsonFloat(json, "az", azDeg)) {
      sendResponse("ERROR: alt/az no numericos");
      return;
    }

    if (altDeg < ALT_MIN_DEG || altDeg > ALT_MAX_DEG) {
      sendResponse("ERROR: altitud fuera de rango");
      return;
    }

    if (azDeg < AZ_MIN_DEG || azDeg > AZ_MAX_DEG) {
      sendResponse("ERROR: azimut fuera de rango");
      return;
    }

    startGoto(altDeg, azDeg);
    return;
  }

  if (cmd == "NUDGE") {
    float deltaAltDeg = 0.0f;
    float deltaAzDeg = 0.0f;

    if (!hasJsonKey(json, "dAlt") || !hasJsonKey(json, "dAz")) {
      sendResponse("ERROR: campos requeridos ausentes");
      return;
    }

    if (!extractJsonFloat(json, "dAlt", deltaAltDeg) || !extractJsonFloat(json, "dAz", deltaAzDeg)) {
      sendResponse("ERROR: dAlt/dAz no numericos");
      return;
    }

    startNudge(deltaAltDeg, deltaAzDeg);
    return;
  }

  if (cmd == "SET_POSITION") {
    float altDeg = 0.0f;
    float azDeg = 0.0f;

    if (!hasJsonKey(json, "alt") || !hasJsonKey(json, "az")) {
      sendResponse("ERROR: campos requeridos ausentes");
      return;
    }

    if (!extractJsonFloat(json, "alt", altDeg) || !extractJsonFloat(json, "az", azDeg)) {
      sendResponse("ERROR: alt/az no numericos");
      return;
    }

    if (altDeg < ALT_MIN_DEG || altDeg > ALT_MAX_DEG) {
      sendResponse("ERROR: altitud fuera de rango");
      return;
    }

    if (azDeg < AZ_MIN_DEG || azDeg > AZ_MAX_DEG) {
      sendResponse("ERROR: azimut fuera de rango");
      return;
    }

    setCurrentLogicalPosition(altDeg, azDeg);
    return;
  }

  sendResponse("ERROR: comando desconocido");
}

void handleSerialInput(String input) {
  input.trim();
  if (input.length() == 0) return;

  if (input.startsWith("{")) {
    handleJsonCommand(input);
    return;
  }

  String upper = input;
  upper.toUpperCase();

  if (upper == "HOME") {
    handleJsonCommand("{\"cmd\":\"HOME\"}");
    return;
  }

  if (upper == "STATUS") {
    handleJsonCommand("{\"cmd\":\"STATUS\"}");
    return;
  }

  if (upper == "PING") {
    handleJsonCommand("{\"cmd\":\"PING\"}");
    return;
  }

  if (upper == "ENABLE_WATCHDOG") {
    handleJsonCommand("{\"cmd\":\"ENABLE_WATCHDOG\",\"enabled\":true}");
    return;
  }

  if (upper == "DISABLE_WATCHDOG") {
    handleJsonCommand("{\"cmd\":\"ENABLE_WATCHDOG\",\"enabled\":false}");
    return;
  }

  if (upper == "STOP") {
    handleJsonCommand("{\"cmd\":\"STOP\"}");
    return;
  }

  if (upper == "TEST_ROUTINE") {
    handleJsonCommand("{\"cmd\":\"TEST_ROUTINE\"}");
    return;
  }

  if (upper.startsWith("GOTO:")) {
    int commaIndex = input.indexOf(',');
    if (commaIndex < 0) {
      sendResponse("ERROR: formato esperado GOTO:alt,az");
      return;
    }

    String altRaw = input.substring(5, commaIndex);
    String azRaw = input.substring(commaIndex + 1);
    altRaw.trim();
    azRaw.trim();

    if (!isNumericLiteral(altRaw) || !isNumericLiteral(azRaw)) {
      sendResponse("ERROR: alt/az no numericos");
      return;
    }

    String json = String("{\"cmd\":\"GOTO\",\"alt\":") +
                  altRaw + String(",\"az\":") + azRaw + String("}");
    handleJsonCommand(json);
    return;
  }

  if (upper.startsWith("NUDGE:")) {
    int commaIndex = input.indexOf(',');
    if (commaIndex < 0) {
      sendResponse("ERROR: formato esperado NUDGE:dAlt,dAz");
      return;
    }

    String altRaw = input.substring(6, commaIndex);
    String azRaw = input.substring(commaIndex + 1);
    altRaw.trim();
    azRaw.trim();

    if (!isNumericLiteral(altRaw) || !isNumericLiteral(azRaw)) {
      sendResponse("ERROR: dAlt/dAz no numericos");
      return;
    }

    String json = String("{\"cmd\":\"NUDGE\",\"dAlt\":") +
                  altRaw + String(",\"dAz\":") + azRaw + String("}");
    handleJsonCommand(json);
    return;
  }

  if (upper.startsWith("SET_POSITION:")) {
    int commaIndex = input.indexOf(',');
    if (commaIndex < 0) {
      sendResponse("ERROR: formato esperado SET_POSITION:alt,az");
      return;
    }

    String altRaw = input.substring(13, commaIndex);
    String azRaw = input.substring(commaIndex + 1);
    altRaw.trim();
    azRaw.trim();

    if (!isNumericLiteral(altRaw) || !isNumericLiteral(azRaw)) {
      sendResponse("ERROR: alt/az no numericos");
      return;
    }

    String json = String("{\"cmd\":\"SET_POSITION\",\"alt\":") +
                  altRaw + String(",\"az\":") + azRaw + String("}");
    handleJsonCommand(json);
    return;
  }

  sendResponse("ERROR: JSON invalido");
}

void readSerialCommands() {
  while (Serial.available() > 0) {
    char ch = (char)Serial.read();

    if (ch == '\n' || ch == '\r') {
      if (serialBuffer.length() > 0) {
        handleSerialInput(serialBuffer);
        serialBuffer = "";
      }
      continue;
    }

    if (serialBuffer.length() < COMMAND_MAX_LENGTH) {
      serialBuffer += ch;
    } else {
      serialBuffer = "";
      sendResponse("ERROR: comando demasiado largo");
    }
  }
}

void configureMotors() {
  motorAlt.setMaxSpeed(MOTOR_MAX_SPEED);
  motorAlt.setAcceleration(MOTOR_ACCELERATION);
  motorAlt.setCurrentPosition(0);

  motorAz.setMaxSpeed(MOTOR_MAX_SPEED);
  motorAz.setAcceleration(MOTOR_ACCELERATION);
  motorAz.setCurrentPosition(0);
}

#if ENABLE_BLE
void setupBle() {
  BLEDevice::init(BLE_DEVICE_NAME);

  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService* service = server->createService(BLE_SERVICE_UUID);

  txCharacteristic = service->createCharacteristic(
    BLE_TX_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  txCharacteristic->addDescriptor(new BLE2902());

  BLECharacteristic* rxCharacteristic = service->createCharacteristic(
    BLE_RX_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  rxCharacteristic->setCallbacks(new RxCallbacks());

  service->start();

  BLEAdvertising* advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(BLE_SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->setMinPreferred(0x06);
  advertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("BLE listo: AstroPilot-OE4");
  Serial.println("BLE service UUID: 6e400001-b5a3-f393-e0a9-e50e24dcca9e");
  Serial.println("BLE RX write UUID: 6e400002-b5a3-f393-e0a9-e50e24dcca9e");
  Serial.println("BLE TX notify UUID: 6e400003-b5a3-f393-e0a9-e50e24dcca9e");
}
#else
void setupBle() {}
#endif

void setup() {
  Serial.begin(115200);
  delay(500);

  configureMotors();
  setupBle();

  sendResponse("AstroPilot OE4 - Firmware listo");
  sendResponse("Motores: AccelStepper HALF4WIRE, STEPS_PER_REV=4096");
  sendResponse("Serial JSON ejemplo: {\"cmd\":\"GOTO\",\"alt\":90,\"az\":180}");
  sendResponse("Comandos: HOME, STATUS, STOP, TEST_ROUTINE, PING, ENABLE_WATCHDOG, GOTO:alt,az, NUDGE:dAlt,dAz, SET_POSITION:alt,az");
  sendStatus();
}

void loop() {
  readSerialCommands();

  motorAlt.run();
  motorAz.run();

  updateMovementCompletion();
  updateRoutine();
  updateWatchdog();
}
