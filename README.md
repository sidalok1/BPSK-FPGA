# BPSK-FPGA
A digital RF transmitter and receiver system implemented on the Digilent CMOD-A7 FPGA development board.
This project was inspired by DSP subsystem that is a part of the Wireless RF and Analog project (WRAP) run by the UCLA IEEE club. The system specifications mostly match that of the WRAP DSP subsystem, and are outlined as follows:
- 50kbps symbol rate
- 1MHz carrier frequency
- 6MHz sample rate
- BPSK modulation scheme
This implementation more or less makes use of the same algorithms as the WRAP system, but some of the differences are as listed below:
- All algorithms implemented in Verilog as opposed to C
- All processing is done in real time, sample by sample
- All arithmetic is done with fixed point arithmetic as opposed to floating point
- Both the receiver and transmitter systems can run simultaneously
- Variable length messages are possible
While the basic functionality of the system is implemented, further work on refining, improving, and testing are yet to be done.
Below is a short clip showing the system in action, with a more in depth video to come soon:
https://youtube.com/shorts/_-VgwhMIluw?feature=share
