function waitForAck(s)
    timeout = 10000; % 1 second timeout
    tic;
    
    while true
        if s.NumBytesAvailable > 0
            response = readline(s);
            % Check if Arduino replied with "ACK" or similar
            if contains(response, "ACK")
                fprintf('Arduino: %s', response);
                break;
            elseif contains(response, "ERROR")
                warning('Arduino reported an ERROR: %s', response);
                break;
            end
        end
        
        if toc > timeout
            warning('Timeout waiting for Arduino response.');
            break;
        end
        pause(0.01);
    end
end