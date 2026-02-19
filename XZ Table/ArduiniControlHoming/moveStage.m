function moveStage(arduinoObj, targetX, targetY)
% MOVESTAGE Sends X and Y coordinates and speed to the Arduino stage.
%
%   Usage:
%       moveStage(s, 100, 200, 1500)
%
%   Inputs:
%       arduinoObj - The serialport object (created via serialport)
%       targetX    - Target X position in mm (or steps, depending on your logic)
%       targetY    - Target Y position
%       speed      - Speed in steps/second (optional, defaults to current Arduino max)
%
%   Note: This function assumes your Arduino parses "X100" and "Y100" strings.

    % 1. Validation: Ensure the serial port is valid
    if ~isvalid(arduinoObj)
        error('Error: Serial port object is invalid or closed.');
    end

    % 2. Flush buffer to remove old messages
    flush(arduinoObj);

    % 3. Send Speed Command (Optional - if your Arduino code supports "S" command)
    % If your Arduino code doesn't have a specific speed command yet, you can skip this
    % or add "S" parsing to your Arduino parseCommand() function.
    % fprintf(arduinoObj, "S%d\n", speed); 
    % pause(0.05); 

    % 4. Send X Command
    cmdX = sprintf('X%.2f', targetX); % Format as X100.00
    writeline(arduinoObj, cmdX);      % Send with newline
    fprintf('Sent: %s\n', cmdX);
    
    % Wait for Acknowledgement (Blocking)
    waitForAck(arduinoObj);

    % 5. Send Y Command
    cmdY = sprintf('Y%.2f', targetY); % Format as Y200.00
    writeline(arduinoObj, cmdY);
    fprintf('Sent: %s\n', cmdY);
    
    % Wait for Acknowledgement (Blocking)
    waitForAck(arduinoObj);
    
    fprintf('Move commands sent successfully.\n');
end