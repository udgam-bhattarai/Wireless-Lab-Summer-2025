#include <AccelStepper.h>
#include <avr/interrupt.h>

// --- MOTOR PINS ---
const int STEP_PIN_X = 3;
const int DIR_PIN_X = 2;
const int STEP_PIN_Y = 5;
const int DIR_PIN_Y = 4;
const int MOTOR_ENABLE_PIN_X = 11;
const int MOTOR_ENABLE_PIN_Y = 12;

// --- LIMIT SWITCH PINS ---
const int LIM_Y_TOP = 10;  // Max Y
const int LIM_Y_BOT = 9;   // Home Y
const int LIM_X_1 = 8;     // Home X
const int LIM_X_2 = 7;     // Max X

AccelStepper stepperX(1, STEP_PIN_X, DIR_PIN_X);
AccelStepper stepperY(1, STEP_PIN_Y, DIR_PIN_Y);

long currentPosX = stepperX.currentPosition();

// --- SETTINGS ---
const float microstep = 200;
const float lead = 10;
const float MM_PER_STEP = lead / microstep;  //1/20
float maxSpeed = 1000;           //2400 steps/sec, max speed is 150mm/s according to motor spec
float acceleration = 500;
float recoverySpeed = 200;
float homingSpeed = 1000;  // Slower speed for calibration

// --- SOFTWARE LIMITS (User Defined) ---
const long MAX_POS_X = 1000;  // Max steps allowed from Home
const long MAX_POS_Y = 500;  // Max steps allowed from Home

const long  soft_Limit_X= floor(0.92*MAX_POS_X);
const long  soft_Limit_Y= floor(0.90*MAX_POS_Y);

volatile bool emergencyTriggered = false;
volatile int triggeredPin = 0;
// CRITICAL: Flag to ignore interrupts during the startup check
volatile bool isHoming = false;

bool Homed = false;

String inputString = "";
bool stringComplete = false;

void setup() {
  Serial.begin(9600);
  inputString.reserve(200);

  // Setup Motors
  stepperX.setMaxSpeed(maxSpeed);
  stepperX.setAcceleration(acceleration);
  stepperY.setMaxSpeed(maxSpeed);
  stepperY.setAcceleration(acceleration);

  // Setup Pins
  pinMode(LIM_Y_TOP, INPUT_PULLUP);
  pinMode(LIM_Y_BOT, INPUT_PULLUP);
  pinMode(LIM_X_1, INPUT_PULLUP);
  pinMode(LIM_X_2, INPUT_PULLUP);

  pinMode(MOTOR_ENABLE_PIN_X, OUTPUT);
  pinMode(MOTOR_ENABLE_PIN_Y, OUTPUT);

  digitalWrite(MOTOR_ENABLE_PIN_X, HIGH);
  digitalWrite(MOTOR_ENABLE_PIN_Y, HIGH);

  // ENABLE INTERRUPTS
  cli();
  PCICR |= (1 << PCIE0);     // Port B (8-13)
  PCICR |= (1 << PCIE2);     // Port D (0-7)
  PCMSK0 |= (1 << PCINT2);   // Pin 10
  PCMSK0 |= (1 << PCINT1);   // Pin 9
  PCMSK0 |= (1 << PCINT0);   // Pin 8
  PCMSK2 |= (1 << PCINT23);  // Pin 7
  sei();

  // --- START HOMING & VALIDATION SEQUENCE ---
  Serial.println("System Booting... Starting Limit Switch Check.");
  runHomingSequence();
  Serial.println("System Ready. Waiting for commands.");
}

// --- INTERRUPT LOGIC ---
void emergencyStopISR() {
  // IF we are in the middle of checking switches, IGNORE the emergency stop.
  if (isHoming) return;

  digitalWrite(MOTOR_ENABLE_PIN_X, HIGH);
  digitalWrite(MOTOR_ENABLE_PIN_Y, HIGH);
  checkSwitches();
}

ISR(PCINT0_vect) {
  emergencyStopISR();
}
ISR(PCINT2_vect) {
  emergencyStopISR();
}

void checkSwitches() {
  if (emergencyTriggered) return;
  // Note: No printf in ISRs
  if (digitalRead(LIM_Y_TOP) == LOW) triggeredPin = LIM_Y_TOP;
  else if (digitalRead(LIM_Y_BOT) == LOW) triggeredPin = LIM_Y_BOT;
  else if (digitalRead(LIM_X_1) == LOW) triggeredPin = LIM_X_1;
  else if (digitalRead(LIM_X_2) == LOW) triggeredPin = LIM_X_2;

  if (triggeredPin != 0) emergencyTriggered = true;
}

void runHomingSequence() {
  Homed = false;  // System is unsafe until proven otherwise
  isHoming = true;
  bool homingFailed = false;  // Flag to track if we found broken switches

  // Re-enable motors
  digitalWrite(MOTOR_ENABLE_PIN_X, LOW);
  digitalWrite(MOTOR_ENABLE_PIN_Y, LOW);

  Serial.println("Starting Validated Homing...");

  // --- PHASE 1: FIND HOME (Bottom Left) ---
  Serial.println("Phase 1: Finding Home Switches...");
  stepperX.setSpeed(-homingSpeed);
  stepperY.setSpeed(-homingSpeed);

  bool xHomeDone = false;
  bool yHomeDone = false;

  while (!xHomeDone || !yHomeDone) {
    // Handle X
    if (digitalRead(LIM_X_1) == LOW) xHomeDone = true;
    else if (!xHomeDone) stepperX.runSpeed();

    // Handle Y
    if (digitalRead(LIM_Y_BOT) == LOW) yHomeDone = true;
    else if (!yHomeDone) stepperY.runSpeed();
  }

  // Zero positions temporarily so we can measure distance to the other side
  stepperX.setCurrentPosition(0);
  stepperY.setCurrentPosition(0);

  // Back off slightly to release switches
  stepperX.runToNewPosition(50);
  stepperY.runToNewPosition(50);


  // --- PHASE 2: VALIDATE FAR LIMITS (Top Right) ---
  Serial.println("Phase 2: Verifying Far Switches (Watchdog Active)...");
  stepperX.setSpeed(homingSpeed);
  stepperY.setSpeed(homingSpeed);

  bool xEndDone = false;
  bool yEndDone = false;

  while (!xEndDone || !yEndDone) {

    // 1. SAFETY CHECK: Have we gone too far?
    // We use MAX_POS_X (which is steps) NOT 990 (which is mm)
    long currentX = stepperX.currentPosition();
    long currentY = stepperY.currentPosition();

    if (currentX*MM_PER_STEP > MAX_POS_X || currentY*MM_PER_STEP > MAX_POS_Y) {
      Serial.println("\n!!! CRITICAL FAILURE !!!");
      if (currentX > MAX_POS_X) Serial.println("Error: X Switch failed to trigger within valid range.");
      if (currentY > MAX_POS_Y) Serial.println("Error: Y Switch failed to trigger within valid range.");

      homingFailed = true;
      break;  // BREAK OUT of the while loop immediately
    }

    // 2. Normal Homing Logic
    if (digitalRead(LIM_X_2) == LOW) xEndDone = true;
    else if (!xEndDone) stepperX.runSpeed();

    if (digitalRead(LIM_Y_TOP) == LOW) yEndDone = true;
    else if (!yEndDone) stepperY.runSpeed();
  }

  // --- ERROR HANDLING ---
  if (homingFailed) {
    Serial.println("Aborting. Returning to Start...");
    // Simple return to 0 (Fast return)
    stepperX.moveTo(0);
    stepperY.moveTo(0);

    // Using run() here because we want acceleration for the long return trip
    while (stepperX.distanceToGo() != 0 || stepperY.distanceToGo() != 0) {
      stepperX.run();
      stepperY.run();
    }

    Serial.println("Machine parked. CHECK WIRING. System Locked.");
    isHoming = false;
    return;  // EXIT FUNCTION. Homed remains FALSE.
  }

delay(500);
  // --- PHASE 3: RETURN TO HOME (Final Zero) ---
  Serial.println("Phase 3: Returning to Zero...");
  stepperX.setSpeed(-homingSpeed);
  stepperY.setSpeed(-homingSpeed);

  xHomeDone = false;
  yHomeDone = false;

  while (!xHomeDone || !yHomeDone) {
    // Handle X
    if (digitalRead(LIM_X_1) == LOW) {
      xHomeDone = true;
      stepperX.setCurrentPosition(0);  // Mark Zero immediately
    } else if (!xHomeDone) {
      stepperX.runSpeed();
    }

    // Handle Y
    if (digitalRead(LIM_Y_BOT) == LOW) {
      yHomeDone = true;
      stepperY.setCurrentPosition(0);  // Mark Zero immediately
    } else if (!yHomeDone) {
      stepperY.runSpeed();
    }
  }
  stepperX.runToNewPosition(10);
  stepperY.runToNewPosition(10);

  // Set Absolute Zero
  stepperX.setCurrentPosition(0);
  stepperY.setCurrentPosition(0);

  // Restore Speeds
  stepperX.setMaxSpeed(maxSpeed);
  stepperY.setMaxSpeed(maxSpeed);

  Serial.println("System Ready. All Switches Verified.");
  isHoming = false;  // Re-enable Safety Interrupts
  Homed = true;
}

void loop() {

  if (emergencyTriggered) {
    Serial.print("CRITICAL STOP! Pin: ");
    Serial.println(triggeredPin);
    if (triggeredPin == LIM_Y_TOP) {
      performRecovery(stepperY, -1, LIM_Y_TOP, MAX_POS_Y);
    } else if (triggeredPin == LIM_Y_BOT) {
      performRecovery(stepperY, 1, LIM_Y_BOT, 0);
    } else if (triggeredPin == LIM_X_1) {
      performRecovery(stepperX, 1, LIM_X_1, 0);
    } else if (triggeredPin == LIM_X_2) {
      performRecovery(stepperX, -1, LIM_X_2, MAX_POS_X);
    }

    emergencyTriggered = false;
    triggeredPin = 0;

    stepperX.setMaxSpeed(maxSpeed);
    stepperY.setMaxSpeed(maxSpeed);
  }


  if (!emergencyTriggered && Homed) {
    digitalWrite(MOTOR_ENABLE_PIN_X, LOW);
    digitalWrite(MOTOR_ENABLE_PIN_Y, LOW);
    // Run motors if no emergency
    if (digitalRead(LIM_X_1) == HIGH && digitalRead(LIM_X_2) == HIGH && digitalRead(LIM_Y_BOT) == HIGH && digitalRead(LIM_Y_TOP) == HIGH) {
      stepperX.run();
      stepperY.run();
    } else
      Serial.println("Limit still stuck");
  }

  if (stringComplete) {
    parseCommand(inputString);
    inputString = "";
    stringComplete = false;
  }
}
void performRecovery(AccelStepper &motor, int direction, int limitSwitchPin, long limitHitPosition) {
  delay(500);  // Let vibrations settle

  // 1. Force Stop & Ignore old path
  motor.setCurrentPosition(motor.currentPosition());

  Serial.print("LIMIT HIT (Pin ");
  Serial.print(limitSwitchPin);
  Serial.println(")! Recovering & Re-calibrating...");

  // Re-enable driver
  digitalWrite(MOTOR_ENABLE_PIN_X, LOW);
  digitalWrite(MOTOR_ENABLE_PIN_Y, LOW);

  // 2. SMART BACK-OFF (Track distance moved)
  bool isReleased = false;
  int attempts = 0;
  long totalStepsMoved = 0;  // Track how far we move to fix the coordinate math later
  int stepChunk = 50 * direction;

  while (!isReleased && attempts < 40) {
    if (digitalRead(limitSwitchPin) == HIGH) {
      isReleased = true;
    } else {
      motor.move(stepChunk);
      motor.runToPosition();
      totalStepsMoved += stepChunk;  // Keep a running total (e.g., -50, -100...)
      delay(50);
      attempts++;
    }
  }

  // 3. SAFETY BUFFER
  if (isReleased) {
    long safetyBuffer = 100 * direction;
    motor.move(safetyBuffer);
    motor.runToPosition();
    totalStepsMoved += safetyBuffer;
    motor.setCurrentPosition(limitHitPosition + totalStepsMoved);
    Serial.print("RECOVERY COMPLETE. Position forced to: ");
    Serial.println(limitHitPosition + totalStepsMoved);
  } else {
    Serial.println("CRITICAL FAILURE: Switch stuck closed!");
  }
}

void serialEvent() {
  while (Serial.available()) {
    char inChar = (char)Serial.read();
    inputString += inChar;
    if (inChar == '\n') stringComplete = true;
  }
}

void parseCommand(String command) {
  char axis = command.charAt(0);
  float val = command.substring(1).toFloat();
  float stepsToMove = round(val*(1/MM_PER_STEP));  // Requested move in steps
  // --- SOFTWARE LIMIT CHECK ---
  if (axis == 'X' || axis == 'x') {
    long currentPosX = stepperX.currentPosition();
    long targetPos = currentPosX + stepsToMove;

    // Check bounds (0 to 900)
    if (targetPos*MM_PER_STEP > soft_Limit_X) {
      Serial.print("ERROR: X Move exceeds limit! Max steps remaining: ");
      Serial.println(soft_Limit_X - currentPosX*MM_PER_STEP);
    } else if (targetPos < 0) {
      Serial.println("ERROR: Cannot move below X Home (0). Max steps remaining backwards: ");
      Serial.println(currentPosX*MM_PER_STEP);
    } else {
      stepperX.move(stepsToMove);
      Serial.println("ACK: Moving X");
    }
  }

  else if (axis == 'Y' || axis == 'y') {
    long currentPosY = stepperY.currentPosition();
    long targetPos = currentPosY + stepsToMove;

    // Check bounds (0 to 400)
    if (targetPos*MM_PER_STEP > soft_Limit_Y) {
      Serial.print("ERROR: Y Move exceeds limit! Max steps remaining: ");
      Serial.println(soft_Limit_Y - currentPosY*MM_PER_STEP);
    } else if (targetPos < 0) {
      Serial.println("ERROR: Cannot move below Y Home (0).");
      Serial.println(currentPosY*MM_PER_STEP);
    } else {
      stepperY.move(stepsToMove);
      Serial.println("ACK: Moving Y");
    }
  }
}