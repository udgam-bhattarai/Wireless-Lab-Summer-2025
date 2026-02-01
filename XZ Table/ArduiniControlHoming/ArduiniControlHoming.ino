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
const int LIM_Y_TOP = 9;   // Max Y
const int LIM_Y_BOT = 10;  // Home Y
const int LIM_X_1 = 8;     // Home X
const int LIM_X_2 = 7;     // Max X

// --- SOFTWARE LIMITS (User Defined) ---
const long MAX_POS_X = 900; // Max steps allowed from Home
const long MAX_POS_Y = 400; // Max steps allowed from Home

// --- OBJECTS ---
AccelStepper stepperX(1, STEP_PIN_X, DIR_PIN_X);
AccelStepper stepperY(1, STEP_PIN_Y, DIR_PIN_Y);

// --- SETTINGS ---
const float STEPS_PER_MM = 20;
float maxSpeed = 2200;
float acceleration = 500;
float recoverySpeed = 200;
float homingSpeed = 300; // Slower speed for calibration

volatile bool emergencyTriggered = false;
volatile int triggeredPin = 0;
// CRITICAL: Flag to ignore interrupts during the startup check
volatile bool isHoming = false; 

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

  // ENABLE MOTORS (LOW = ON)
  digitalWrite(MOTOR_ENABLE_PIN_X, LOW);
  digitalWrite(MOTOR_ENABLE_PIN_Y, LOW);

  // ENABLE INTERRUPTS
  cli();
  PCICR |= (1 << PCIE0);  // Port B (8-13)
  PCICR |= (1 << PCIE2);  // Port D (0-7)
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

ISR(PCINT0_vect) { emergencyStopISR(); }
ISR(PCINT2_vect) { emergencyStopISR(); }

void checkSwitches() {
  if (emergencyTriggered) return;
  // Note: No printf in ISRs
  if (digitalRead(LIM_Y_TOP) == LOW)      triggeredPin = LIM_Y_TOP;
  else if (digitalRead(LIM_Y_BOT) == LOW) triggeredPin = LIM_Y_BOT;
  else if (digitalRead(LIM_X_1) == LOW)   triggeredPin = LIM_X_1;
  else if (digitalRead(LIM_X_2) == LOW)   triggeredPin = LIM_X_2;

  if (triggeredPin != 0) emergencyTriggered = true;
}

// --- NEW HOMING FUNCTION ---
// --- CONCURRENT HOMING FUNCTION ---
void runHomingSequence() {
  isHoming = true; // Disable Emergency Stop Interrupts
  
  // Re-enable motors
  digitalWrite(MOTOR_ENABLE_PIN_X, LOW);
  digitalWrite(MOTOR_ENABLE_PIN_Y, LOW);
  
  Serial.println("Starting Concurrent Homing...");

  // --- PHASE 1: MOVE TO START (X1 & Y_BOT) ---
  Serial.println(" - Homing to Start Positions...");
  stepperX.setSpeed(-homingSpeed);
  stepperY.setSpeed(-homingSpeed);
  
  // Run until BOTH switches are pressed
  // Note: We use two bool flags to track who has finished
  bool xHomeDone = false;
  bool yHomeDone = false;

  while (!xHomeDone || !yHomeDone) {
    // Handle X
    if (digitalRead(LIM_X_1) == LOW) { // Switch Triggered
      xHomeDone = true;
    } else if (!xHomeDone) {
      stepperX.runSpeed();
    }

    // Handle Y
    if (digitalRead(LIM_Y_BOT) == LOW) { // Switch Triggered
      yHomeDone = true;
    } else if (!yHomeDone) {
      stepperY.runSpeed();
    }
  }

  // Back off slightly (reset positions)
  stepperX.setCurrentPosition(0);
  stepperY.setCurrentPosition(0);
  stepperX.runToNewPosition(50); 
  stepperY.runToNewPosition(50);


  // --- PHASE 2: VALIDATE END LIMITS (X2 & Y_TOP) ---
  Serial.println(" - Checking End Limits...");
  stepperX.setSpeed(homingSpeed);
  stepperY.setSpeed(homingSpeed);
  
  bool xEndDone = false;
  bool yEndDone = false;

  while (!xEndDone || !yEndDone) {
    if (digitalRead(LIM_X_2) == LOW) xEndDone = true;
    else if (!xEndDone) stepperX.runSpeed();

    if (digitalRead(LIM_Y_TOP) == LOW) yEndDone = true;
    else if (!yEndDone) stepperY.runSpeed();
  }


  // --- PHASE 3: RETURN TO HOME (X1 & Y_BOT) ---
  Serial.println(" - Returning to Home...");
  stepperX.setSpeed(-homingSpeed);
  stepperY.setSpeed(-homingSpeed);
  
  xHomeDone = false;
  yHomeDone = false;

  while (!xHomeDone || !yHomeDone) {
    if (digitalRead(LIM_X_1) == LOW) xHomeDone = true;
    else if (!xHomeDone) stepperX.runSpeed();

    if (digitalRead(LIM_Y_BOT) == LOW) yHomeDone = true;
    else if (!yHomeDone) stepperY.runSpeed();
  }

  // --- FINAL ZEROING ---
  // Move slightly off the switch so we aren't constantly triggering it
  stepperX.setCurrentPosition(0);
  stepperY.setCurrentPosition(0);
  
  // Use runToNewPosition (blocking) here is fine as it's very short
  stepperX.runToNewPosition(10); 
  stepperY.runToNewPosition(10);
  
  stepperX.setCurrentPosition(0);
  stepperY.setCurrentPosition(0);
  
  // Restore Max Speeds
  stepperX.setMaxSpeed(maxSpeed);
  stepperY.setMaxSpeed(maxSpeed);
  
  Serial.println("System Ready. All Switches Verified.");
  isHoming = false; // Re-enable Safety Interrupts
}

void loop() {
  if (emergencyTriggered) {
    Serial.print("CRITICAL STOP! Pin: ");
    Serial.println(triggeredPin);

    // Call recovery ONCE. The function itself loops until safe.
    if (triggeredPin == LIM_Y_TOP)      performRecovery(stepperY, -1);
    else if (triggeredPin == LIM_Y_BOT) performRecovery(stepperY, 1);
    else if (triggeredPin == LIM_X_1)   performRecovery(stepperX, 1);
    else if (triggeredPin == LIM_X_2)   performRecovery(stepperX, -1);

    emergencyTriggered = false;
    triggeredPin = 0;

    stepperX.setMaxSpeed(maxSpeed);
    stepperY.setMaxSpeed(maxSpeed);
  }

  if (!emergencyTriggered) {
     // Run motors if no emergency
     if (digitalRead(LIM_X_1) == HIGH && digitalRead(LIM_X_2) == HIGH && 
         digitalRead(LIM_Y_BOT) == HIGH && digitalRead(LIM_Y_TOP) == HIGH) {
         stepperX.run();
         stepperY.run();
     }
  }

  if (stringComplete) {
    parseCommand(inputString);
    inputString = "";
    stringComplete = false;
  }
}

// --- RECOVERY FUNCTION ---
void performRecovery(AccelStepper &motor, int direction) {
  stepperX.setCurrentPosition(stepperX.currentPosition());
  stepperY.setCurrentPosition(stepperY.currentPosition());
  digitalWrite(MOTOR_ENABLE_PIN_X, LOW);
  digitalWrite(MOTOR_ENABLE_PIN_Y, LOW);
  delay(10); 

  motor.setSpeed(direction * recoverySpeed);
  long safetySteps = 0;

  while ((digitalRead(LIM_Y_TOP) == LOW || digitalRead(LIM_Y_BOT) == LOW || 
          digitalRead(LIM_X_1) == LOW   || digitalRead(LIM_X_2) == LOW)
          && safetySteps < 20000) {

    if (motor.runSpeed()) safetySteps++;
  }

  long clearanceSteps = 0;
  while (clearanceSteps < 100) { 
    if (motor.runSpeed()) clearanceSteps++;
  }

  motor.setCurrentPosition(0);
  Serial.println("RECOVERED");
}

// --- SERIAL HELPERS WITH SOFTWARE LIMITS ---
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
  float stepsToMove = val * STEPS_PER_MM; // Requested move in steps

  // --- SOFTWARE LIMIT CHECK ---
  if (axis == 'X' || axis == 'x') {
    long currentPos = stepperX.currentPosition();
    long targetPos = currentPos + stepsToMove;

    // Check bounds (0 to 900)
    if (targetPos > MAX_POS_X) {
      Serial.print("ERROR: X Move exceeds limit! Max steps remaining: ");
      Serial.println(MAX_POS_X - currentPos);
    } 
    else if (targetPos < 0) {
      Serial.println("ERROR: Cannot move below X Home (0).");
    } 
    else {
      stepperX.move(stepsToMove);
      Serial.println("ACK: Moving X");
    }
  } 
  
  else if (axis == 'Y' || axis == 'y') {
    long currentPos = stepperY.currentPosition();
    long targetPos = currentPos + stepsToMove;

    // Check bounds (0 to 400)
    if (targetPos > MAX_POS_Y) {
      Serial.print("ERROR: Y Move exceeds limit! Max steps remaining: ");
      Serial.println(MAX_POS_Y - currentPos);
    } 
    else if (targetPos < 0) {
      Serial.println("ERROR: Cannot move below Y Home (0).");
    } 
    else {
      stepperY.move(stepsToMove);
      Serial.println("ACK: Moving Y");
    }
  }
}