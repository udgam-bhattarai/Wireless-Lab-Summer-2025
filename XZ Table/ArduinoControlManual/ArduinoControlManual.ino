#include <AccelStepper.h>

// --- PINS (Matches your setup) ---
const int STEP_PIN_X = 3;
const int DIR_PIN_X = 2;
const int STEP_PIN_Y = 5;
const int DIR_PIN_Y = 4;
const int MOTOR_ENABLE_PIN_X = 11;
const int MOTOR_ENABLE_PIN_Y = 12;

// --- SETTINGS ---
// Using your "Full Step" config for now to be safe/strong
const float STEPS_PER_MM = 20.0; 

AccelStepper stepperX(1, STEP_PIN_X, DIR_PIN_X);
AccelStepper stepperY(1, STEP_PIN_Y, DIR_PIN_Y);

void setup() {
  Serial.begin(9600);
  
  // 1. Force Enable Motors
  pinMode(MOTOR_ENABLE_PIN_X, OUTPUT);
  pinMode(MOTOR_ENABLE_PIN_Y, OUTPUT);
  digitalWrite(MOTOR_ENABLE_PIN_X, LOW); // ON
  digitalWrite(MOTOR_ENABLE_PIN_Y, LOW); // ON

  stepperX.setMaxSpeed(1000);
  stepperX.setAcceleration(500);
  stepperY.setMaxSpeed(1000);
  stepperY.setAcceleration(500);

  Serial.println("--- MANUAL RESCUE MODE ---");
  Serial.println("Type 'X10' to move X 10mm positive.");
  Serial.println("Type 'Y10' to move Y 10mm positive.");
}

void loop() {
  if (Serial.available()) {
    String input = Serial.readStringUntil('\n');
    char axis = input.charAt(0);
    float val_mm = input.substring(1).toFloat();
    long steps = val_mm * STEPS_PER_MM;

    if (axis == 'X' || axis == 'x') {
      Serial.print("Moving X: "); Serial.println(val_mm);
      stepperX.move(steps); // Relative move
    } 
    else if (axis == 'Y' || axis == 'y') {
      Serial.print("Moving Y: "); Serial.println(val_mm);
      stepperY.move(steps); // Relative move
    }
  }

  // Always run motors if they have a target
  stepperX.run();
  stepperY.run();
}