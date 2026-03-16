Please download the folder Arduino Control Homing. This is the most up to date version of the code that includes a homing sequence that checks whether the switches are running and then returns to a start position. 

PLEASE NOTE: If the limit switches are not function properly, the motor will reach the end of the table and start grinding. To prevent this, please remain near either the usb connection to the Arduino or the electrical wire powering the whole system via mains. If you observe the module going past a switch without triggering it, remove the Arduino USB connection /power off the switch for power. Then, re-adjust the limit switches if they have been moved out of place, test if they are functioning correctly by placing a metal sheet in front of the switch and waiting for the light to turn on. If you feel that there is something malfunctioning, please reach out to Andrew aes10080@nyu.edu

#Running the code

Open both .m files and ensure your desired codefile is in the correct MATLAB path. Run the moveStage.m function in your code file with the desired parameters (in mm). Please note that the total length of the system is 1000mm and the height is 500mm, however the module is restricted to a fraction of this for safety purposes, as indicated in the arduino code by MAS_POS_X and MAX_POS_Y. The system will keep track of how far you have moved in each direction, and if you call the function with parameters that will exceed the bounds of the system, it will not move and you will receive feedback in the terminal. 


[Need to talk about declaring the object]

#Error handling in MATLAB

If the function hangs when you try to call it, try changing the COM PORT (4 or 6). If there is a serial error, ensure you do not have the Arduino File open in the background. If the code is running and the system is not responding, try re-uploading the arduino code, then closing the Arduino IDE and re-running the MATLAB code. Please note that when you re-initialize the code or declare the object again in matlab the homing sequence will run again.


Then open the ArduinoControlHoming software 
