#include <AccelStepper.h>

// --- MOTOR PINS ---
const int STEP_PIN_X = 3;
const int DIR_PIN_X  = 2;
const int STEP_PIN_Y = 5;
const int DIR_PIN_Y  = 4;

// --- LIMIT SWITCH PINS ---
const int LIM_Y_TOP = 9; // Hit when moving UP (+) -> Recover DOWN (-)
const int LIM_Y_BOT = 10;  // Hit when moving DOWN (-) -> Recover UP (+)
const int LIM_X_1   = 8;  // Assumed Left/Min -> Recover POSITIVE (+)
const int LIM_X_2   = 7;  // Assumed Right/Max -> Recover NEGATIVE (-)

// --- OBJECTS ---
AccelStepper stepperX(1, STEP_PIN_X, DIR_PIN_X);
AccelStepper stepperY(1, STEP_PIN_Y, DIR_PIN_Y);

// --- SETTINGS ---
const float STEPS_PER_MM = 20; 
float maxSpeed = 2200; 
float acceleration = 500;
float recoverySpeed = 200; // Slow crawl speed

// --- VARIABLES ---
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

  // Setup Limits (All configured for Optocoupler/NC Logic)
  // HIGH = Safe, LOW = Triggered
  pinMode(LIM_Y_TOP, INPUT_PULLUP);
  pinMode(LIM_Y_BOT, INPUT_PULLUP);
  pinMode(LIM_X_1, INPUT_PULLUP);
  pinMode(LIM_X_2, INPUT_PULLUP);
}

void loop() {
  // --- 1. CHECK ALL 4 LIMITS ---
  
  // Check Y-TOP (Pin 10)
  if (digitalRead(LIM_Y_TOP) == LOW) {
    Serial.println("ERROR: Y_TOP_HIT. Recovering DOWN...");
    // Pass the 'stepperY' object and direction -1 (Negative/Down)
    performRecovery(stepperY, -1); 
  }
  
  // Check Y-BOTTOM (Pin 9)
  else if (digitalRead(LIM_Y_BOT) == LOW) {
    Serial.println("ERROR: Y_BOT_HIT. Recovering UP...");
    // Pass 'stepperY' and direction 1 (Positive/Up)
    performRecovery(stepperY, 1);
  }
  
  // Check X-LIMIT 1 (Pin 8)
  else if (digitalRead(LIM_X_1) == LOW) {
    Serial.println("ERROR: X_LIM_1_HIT. Recovering POSITIVE...");
    // Pass 'stepperX' and direction 1 (Positive)
    performRecovery(stepperX, 1);
  }
  
  // Check X-LIMIT 2 (Pin 7)
  else if (digitalRead(LIM_X_2) == LOW) {
    Serial.println("ERROR: X_LIM_2_HIT. Recovering NEGATIVE...");
    // Pass 'stepperX' and direction -1 (Negative)
    performRecovery(stepperX, -1);
  }

  // --- 2. MOTOR EXECUTION ---
  stepperX.run();
  stepperY.run();

  // --- 3. PARSE COMMANDS ---
  if (stringComplete) {
    parseCommand(inputString);
    inputString = "";
    stringComplete = false;
  }
}

// --- UNIVERSAL RECOVERY FUNCTION ---
// Inputs: Which motor to move, and which direction (-1 or 1)
void performRecovery(AccelStepper &motor, int direction) {
  
  // 1. HARD STOP BOTH MOTORS
  stepperX.stop();
  stepperY.stop();
  stepperX.runToPosition();
  stepperY.runToPosition();

  // 2. Set Recovery Speed
  // Direction * Speed gives us the velocity vector
  float velocity = direction * recoverySpeed;
  
  motor.setSpeed(velocity);
  
  // 3. Back-off Loop
  // We need to know WHICH pin to watch. This is a bit tricky in a universal function,
  // so we check ALL pins. If ANY pin is low, we keep moving.
  // This is safe because only one is likely triggered.
  
  long safetyCount = 0;
  long maxSafetySteps = 4000; // ~200mm limit

  // While ANY switch is triggered...
  while ( (digitalRead(LIM_Y_TOP) == LOW || 
           digitalRead(LIM_Y_BOT) == LOW || 
           digitalRead(LIM_X_1)   == LOW || 
           digitalRead(LIM_X_2)   == LOW) 
           && safetyCount < maxSafetySteps) {
             
    motor.runSpeed(); // Run ONLY the recovery motor
    safetyCount++;
  }

  // 4. Clean Up
  motor.stop();
  
  // Reset Position to 0 (This creates a new "Home" at the limit boundary)
  motor.setCurrentPosition(0);
  
  // Restore Max Speeds (Important!)
  stepperX.setMaxSpeed(maxSpeed);
  stepperY.setMaxSpeed(maxSpeed);
  
  Serial.println("RECOVERED: System Safe.");
}

// --- HELPER FUNCTIONS ---

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
    stepperX.move(
      
    );
    Serial.println("ACK: Moving X");
  }
  else if (axis == 'Y' || axis == 'y') {
    stepperY.move(steps); 
    Serial.println("ACK: Moving Y");
  }
}