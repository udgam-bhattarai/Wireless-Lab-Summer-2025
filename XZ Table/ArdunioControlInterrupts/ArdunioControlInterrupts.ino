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
const int LIM_Y_TOP = 9;
const int LIM_Y_BOT = 10;
const int LIM_X_1 = 8;
const int LIM_X_2 = 7;

// --- OBJECTS ---
AccelStepper stepperX(1, STEP_PIN_X, DIR_PIN_X);
AccelStepper stepperY(1, STEP_PIN_Y, DIR_PIN_Y);

// --- SETTINGS ---
const float STEPS_PER_MM = 20;
float maxSpeed = 2200;
float acceleration = 500;
float recoverySpeed = 500;

volatile bool emergencyTriggered = false;
volatile int triggeredPin = 0;

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
}


void emergencyStopISR() {

  digitalWrite(MOTOR_ENABLE_PIN_X, HIGH);
  digitalWrite(MOTOR_ENABLE_PIN_Y, HIGH);

  // 2. LOGIC CHECK
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

  if (digitalRead(LIM_Y_TOP) == LOW) {
    triggeredPin = LIM_Y_TOP;
    printf("Y -top triggered");
  } else if (digitalRead(LIM_Y_BOT) == LOW) {
    triggeredPin = LIM_Y_BOT;
    printf("Y -bot triggered");
  } else if (digitalRead(LIM_X_1) == LOW) {
    triggeredPin = LIM_X_1;
    printf("X1 triggered");
  } else if (digitalRead(LIM_X_2) == LOW) {
    triggeredPin = LIM_X_2;
    printf("X2 triggered");
  }

  if (triggeredPin != 0) emergencyTriggered = true;
}

void loop() {
  if (emergencyTriggered or (digitalRead(LIM_Y_TOP) == LOW || digitalRead(LIM_Y_BOT) == LOW || digitalRead(LIM_X_1) == LOW || digitalRead(LIM_X_2) == LOW) ) {
    Serial.print("CRITICAL STOP! Pin: ");
    Serial.println(triggeredPin);

   
      if (triggeredPin == LIM_Y_TOP) performRecovery(stepperY, -1);
      else if (triggeredPin == LIM_Y_BOT) performRecovery(stepperY, 1);
      else if (triggeredPin == LIM_X_1) performRecovery(stepperX, 1);
      else if (triggeredPin == LIM_X_2) performRecovery(stepperX, -1);
    
    emergencyTriggered = false;
    triggeredPin = 0;

    // Restore speeds
    stepperX.setMaxSpeed(maxSpeed);
    stepperY.setMaxSpeed(maxSpeed);
  }

  if (!emergencyTriggered) {
    if (digitalRead(LIM_X_1) == HIGH and digitalRead(LIM_X_2) == HIGH and digitalRead(LIM_Y_BOT) == HIGH and digitalRead(LIM_Y_TOP) == HIGH) {
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

void performRecovery(AccelStepper &motor, int direction) {
  // 1. Wipe "Target" Memory ("You are exactly where you are supposed to be")
  stepperX.setCurrentPosition(stepperX.currentPosition());
  stepperY.setCurrentPosition(stepperY.currentPosition());

  // 2. Re-Enable Power
  digitalWrite(MOTOR_ENABLE_PIN_X, LOW);
  digitalWrite(MOTOR_ENABLE_PIN_Y, LOW);
  delay(5);  // Give drivers a moment to wake up

  // 3. Setup Constant Speed Move
  motor.setSpeed(direction * recoverySpeed);

  long safetySteps = 0;

  // 4. Back off until switches clear
  while ((digitalRead(LIM_Y_TOP) == LOW || digitalRead(LIM_Y_BOT) == LOW || digitalRead(LIM_X_1) == LOW || digitalRead(LIM_X_2) == LOW)
         && safetySteps < 20000) {  // Limit to 2000 STEPS (not loops)


    if (motor.runSpeed()) {
      safetySteps++;
    }
  }


  long clearanceSteps = 0;
  while (clearanceSteps < 50) {
    if (motor.runSpeed()) clearanceSteps++;
  }


  motor.setCurrentPosition(0);

  Serial.println("RECOVERED");
}

// ... Helper functions for Serial ...
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
  float steps = val * STEPS_PER_MM;

  if (axis == 'X' || axis == 'x') {
    stepperX.move(steps);
    Serial.println("ACK: Moving X");
  } else if (axis == 'Y' || axis == 'y') {
    stepperY.move(steps);
    Serial.println("ACK: Moving Y");
  }
}