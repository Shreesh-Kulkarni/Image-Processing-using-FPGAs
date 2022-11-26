# Image-Processing-using-FPGAs
## Source Code and other relevant files for EE347 Mini Project in Embedded Control Systems. 
This project revolves around deploying basic Image Processing methods on an FPGA and simulating it.

*3 operations are performed in this project*
1. Brightness Increment/Decrement
2. Image Inversion
3. Threshold

**To run this project download the code file(project1demo) in .zip format and extract it**
1. ***Install Xilinx Vivado IDE 2021.1 ML edition(Newer versions have uncertainty of success)***
2. ***Open the file using Vivado IDE**
3. ***Once the file is opened run the behavioural simulation command in the IDE which runs the testbench file***
4. ***Once the simulation is calibrated, run the following command in the command window:-***
>`run 6ms`
5. ***Wait for 6milliseconds of simulation time(around 30-45 seconds in real time)***
6. ***Note the hexadecimal values being read for every horizontal and vertical synchronous reset corresponding to the clock signal. Once the value changes, it means that one pixel of the image has been successfully read***
7. ***Once the simulation is complete,open the output image in your simulation file. The path to the file will look like this:-***
> `project_1_demo/project_1_demo.sim/sim_1/behav/xsim`
8. ***Finally end the simulation and clear the command window***
