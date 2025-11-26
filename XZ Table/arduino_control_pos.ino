#include <AccelStepper.h>

// --- Define your motor pins ---
// Using Common-Anode: PU- (Pulse) and DIR- (Direction)
const int STEP_PIN_X = 5;
const int DIR_PIN_X = 4;
const int STEP_PIN_Y = 3;
const int DIR_PIN_Y = 2;

// Create an instance of AccelStepper
// The "1" means we are using a driver (STEP/DIR pins)
AccelStepper stepperX(1, STEP_PIN_X, DIR_PIN_X);
AccelStepper stepperY(1, STEP_PIN_Y, DIR_PIN_Y);

// --- Your Calculations (Change these!) ---
const float STEPS_PER_MM = 20; // From Calculation 1

// --- Your Goals (This is what you want) ---
const float MOVE_DISTANCE_MM = 300;  // Your "X-distance"
const float TARGET_SPEED_MM_S = 110; // Your "Y-speed"

void setup() {
  Serial.begin(9600); // Optional: for serial monitor
  
  // --- Convert Goals to Stepper Commands ---
  float targetSteps = MOVE_DISTANCE_MM * STEPS_PER_MM;
  float targetSpeedStepsS = TARGET_SPEED_MM_S * STEPS_PER_MM;
  
  // Configure the stepper
  stepperX.setMaxSpeed(targetSpeedStepsS);
  stepperX.setAcceleration(500); // Start with a low acceleration (steps/sec^2)
  stepperY.setMaxSpeed(targetSpeedStepsS);
  stepperY.setAcceleration(500); 
  
  // Tell the stepper to move 10mm (2000 steps)
  // relative to its current position.
  // Use a negative number to move backward: stepperX.move(-targetSteps);
  stepperX.move(-targetSteps); 
  stepperY.move(-targetSteps); 
}

void loop() {
  // Check if the motor has finished its last move

  // This function MUST be called as fast as possible
  // It checks if it needs to send a pulse to move the motor
  stepperX.run();
  stepperY.run();
}