|
| twoP_FSM.cmd.txt
|
| Comments
| Elec422/527 twoP_FSM demo
| CMOS two phase FSM counter with hold input and odd output
| The two state bits are also ouput. 
| Notice escape chararcter needed for state bits
| 
|
| define vectors for easier display
vector statebits state\[1\] state\[0\] 
ana clka clkb restart hold odd state\[1\] state\[0\] statebits
V   restart  0 1 0 0 0 0 0 0 0 0 0
V   hold     0 0 0 0 0 1 1 1 0 0 0
| Two phase clock with non-overlap period - same as Questa testbench
clock clka 0 1 0 0
clock clkb 0 0 0 1
R
