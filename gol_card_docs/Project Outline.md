# Step 1: Create a Simulated Card on PC
- [ ] Create a program that simulates Conway's Game of Life on a fixed sized board.
- [ ] Random seeding of the initial state.
- [ ] Add various time scales, as well as step functionality.
- [ ] Save the state to a file after each step, at first naively 
- [ ] Investigate and implement methods to compress the state size between steps
- [ ] Break off state save/load into a HAL
- [ ] Break off display interaction into a HAL
- [ ] Separate a single state update into a function that can be called either on msp430 or by the simulator
when this step is done, the step function should contain no I/O except through the HAL
# Step 2: Hardware Prototyping
- [ ] Based on the simulator, choose an appropriate MSP430 processor
	- MSP430FR2433, has 16kB (bytes)
- [ ] Constrain the simulator to run within the amount of memory the processor has
- [ ] Produce MSP430 assembly from the program
- [ ] Order necessary parts
- [ ] Set up bootstrap code for MSP430
- [ ] Implement sending/recieving data (state, display)
- [ ] Move state to hardware
- [ ] Move step time to hardware
- [ ] Implement eInk interface (will take a while, API may need to be restructured)
when this step is complete, all desired functionality should be complete, just not in the correct form factor

# Step 3: Hardware Design
- [ ] Design a custom PCB to house all components
- [ ] Add art/contact info to PCB
- [ ] Order standalone components, PCB, PCB mask
- [ ] Assemble