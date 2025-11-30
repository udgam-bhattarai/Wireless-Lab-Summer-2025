#include <AccelStepper.h>

// Pins
const int STEP_PIN_Y = 5;
const int DIR_PIN_Y = 4;
const int STEP_PIN_X = 3;
const int DIR_PIN_X = 2;

// Objects
AccelStepper stepperX(1, STEP_PIN_X, DIR_PIN_X);
AccelStepper stepperY(1, STEP_PIN_Y, DIR_PIN_Y);

// Your settings
const float STEPS_PER_MM = 20; 
float targetSpeed = 2200; // default speed steps/s
float targetAccel = 500;  // default accel

String inputString = "";         // a String to hold incoming data
bool stringComplete = false;     // whether the string is complete

void setup() {
  Serial.begin(9600); 
  
  stepperX.setMaxSpeed(targetSpeed);
  stepperX.setAcceleration(targetAccel);
  stepperY.setMaxSpeed(targetSpeed);
  stepperY.setAcceleration(targetAccel);
  
  inputString.reserve(200);
}

void loop() {
  // 1. Run the motors constantly (Non-blocking)
  stepperX.run();
  stepperY.run();

  // 2. Check for commands from MATLAB
  if (stringComplete) {
    parseCommand(inputString);
    // clear the string:
    inputString = "";
    stringComplete = false;
  }
}

// Function to read Serial Data
void serialEvent() {
  while (Serial.available()) {
    char inChar = (char)Serial.read();
    inputString += inChar;
    if (inChar == '\n') {
      stringComplete = true;
    }
  }
}

// Function to interpret the text "X300" or "Y10"
void parseCommand(String command) {
  char axis = command.charAt(0); // Get first letter
  float val = command.substring(1).toFloat(); // Get the number
  
  float steps = val * STEPS_PER_MM; // Convert mm to steps
  
  if (axis == 'X' || axis == 'x') {
    stepperX.move(steps); // Relative move
  }
  else if (axis == 'Y' || axis == 'y') {
    stepperY.move(steps); 
  }
  else if (axis == 'B' || axis == 'b') { // "Both"
     stepperX.move(steps);
     stepperY.move(steps);
  }
}
