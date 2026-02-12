
clear; clc;
port = "COM6"; % CHANGE THIS to your actual port
baud = 9600;

try
    arduinoObj = serialport(port, baud);
    configureTerminator(arduinoObj, "LF"); % Arduino uses '\n' (Line Feed)
    flush(arduinoObj);
    disp("Connected to Arduino.");
    pause(2); % Wait for Arduino to reset/boot
catch
    error("Failed to connect. Check port name.");
end

% 2. DEFINE TARGETS
x_pos = 100;  % Target Steps or MM
y_pos = 100;


% 3. CALL THE FUNCTION
moveStage(arduinoObj, x_pos, y_pos);

% 4. CLEANUP (Optional, usually at end of script)
% clear s;