# Verilog Image Processing (Grayscale, Mirror, Sharpening)
## Project for the Computer Architecture course ([ocw.cs.pub.ro](https://ocw.cs.pub.ro/courses/ac-is))
This is an image processing application in Verilog which can receive and write one pixel at a time during a positive clock cycle. The purpose of the application is to receive pixels from an image and apply 3 filters : Grayscale, Mirror, Sharpening in the order they are mentioned. Mirroring is applied on the GrayScale image and Sharpening is applied onthe Mirrored image.  

To achieve this i've used an always block which is triggered by the positive clock change. In this block the flags that mark the completion of the tasks and the state in which the Finite State Machine is in are updated

In the second always block that is triggered by the change of the state I have implemented a Finite State Machine in which each state describes a step in the process of applying said filters . Each state is corelated with a possible action done in that state cycle ( which in fact is a positive clock cycle ).

For indepth information please check the [README](https://github.com/zuch3e/verilogImgProc/blob/main/README.pdf) and the [code comments](https://github.com/zuch3e/verilogImgProc/blob/main/process.v).
