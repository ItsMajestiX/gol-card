The PCB for this project is the very first custom PCB I have designed myself. Measuring 86mm by 55mm, it is about the size of a [standard European business card](https://www.zenbusiness.com/blog/business-card-dimensions/). I designed the board in KiCad 9. This project is also my first project with entirely SMD components (besides the Tag Connect connector, which is not a soldered component).

It is a two-layer board manufactured on [OSH Park's after dark service](https://docs.oshpark.com/services/afterdark/), which uses a black substrate and clear solder mask that I found to be a good fit for this design. I started designing the board in May 2025 and ordered the first batch of boards around mid-June 2025. This was intended to catch errors in the board, but to my surprise the initial revision of the board worked perfectly.

# The Process
Since this was my first time building a PCB from scratch, I needed the help of a lot of online resources. This [STM32 PCB in KiCad](https://www.youtube.com/watch?v=aVUqaB0IMh4) tutorial from YouTube channel [Phil's Lab](https://www.youtube.com/@PhilsLab) really helped me to design and lay out the microcontroller section of the PCB. I also watched a design review by [Robert Feranec](https://www.youtube.com/@RobertFeranec) of a novice's first [schematic](https://www.youtube.com/watch?v=YzBtfN1LQtM) and [PCB layout](https://www.youtube.com/watch?v=-luLIJqURlY) to make sure I wasn't making the same mistakes.

I also utilized the datasheets for the microcontroller, the boost converter, and especially the ePaper display. The display needs a lot of external components in order for its boost circuitry to work, so I made sure to build that part of the circuit as it was shown on the datasheet. 

After I had finished the schematic and routing, I wanted to get a review of my design from someone with more experience. To do this, I made [a post on the PrintedCircuitBoard subreddit](https://www.reddit.com/r/PrintedCircuitBoard/comments/1kz87it/review_request_msp430_based_pcb_business_card/) asking for help. This post led me to fix some issues with the board:
- incorrect numbering for the FPC connector
- 90 degree angles in inappropriate locations
- acute angles
- lackluster GND fill on the back layer
- insufficient space between the GND contact for the battery and the trace carrying battery voltage

After fixing these issues, I ordered the board along with the components I needed.

# The Schematic
## Root
I chose to split the schematic into three blocks with a fourth root block making the connections between them. This was to avoid overcrowding a single schematic page with everything on the board.

This page only has eight wires. Two go between the MCU block and the power block, providing an enable signal for the boost converter and a connection from the boost converter's output to the debugging connector, which will be discussed later. The remaining six wires are used to communicate with the ePaper display.

## FPC Connector
The FPC connector block contains the FPC connector that connects to the ePaper display, as well as all of the support circuitry for the ePaper's boost converter. The circuitry here is pretty much copied from the reference design provided by the ePaper manufacturer, as I don't know enough to safely deviate from it.

One issue I ran into with this section of the design was conflicting reference circuits from the maker of the driver chip inside the display and the vendor of the ePaper screen. The former seemed to have an extra capacitor in the boost circuitry, while the latter did not. Since the ePaper vendor's diagram seemed to match the breakout board I had on hand at the time, I decided to err on that side. However, I included an empty pad for that capacitor on the board (C200) in case my judgement was wrong and I needed to hand solder the capacitor on.

Another issue with this section was that the connector symbol I downloaded from Molex seemed to have reverse pin numbering than what the ePaper datasheet and my breakout board expected. To fix this, I just adjusted the labels of each pin to match the corresponding ePaper pin. For example pin 1 got the label 24, while pin 24 got label 1. This did not change the labeling on the PCB view, but at that point I could follow the rat's nest to lay out the traces.

## Battery and Switching Regulator
The next page in the schematic contains the coin cell battery holding and the circuitry to boost its voltage up to a stable 3V. This is a crucial part of the design because, as I inconveniently learned last spring, an ePaper display draws too much power to run directly off of a coin cell battery. The power from the battery first goes through a Schottky diode to provide reverse polarity protection. The boost converter did not seem to be very reverse polarity tolerant, and given the high risk of inserting a coin cell backwards I wanted to make sure users couldn't destroy the power circuitry from one mishap. The voltage drop due to the Schottky diode will be made up for in the boost circuitry.

The rest of the circuit is based on the provided circuit in the datasheet for the boost converter IC. I used TI's [WEBENCH](https://webench.ti.com/power-designer/) to help me to pick components for the circuit. One major change I made was using two 10μF capacitors on the output of the boost regulator instead of the single 22μF capacitor the datasheet recommended. This allowed me to use the same type of capacitor on the input and output of the regulator. I made sure to run this change through WEBENCH, and the simulated output looked acceptable to me.

## Microcontroller
The last page of the schematic contains the microcontroller and its support circuitry. It also contains the debugging connection, a six-pin[ Tag Connect](https://www.tag-connect.com/) footprint.

The only support circuitry included are some decoupling capacitors for the microcontroller, some circuitry to handle board resets, and the 32k crystal with its load capacitors. I had a bit of trouble selecting the values for these, but eventually settled on 6pF with the help of an online calculator.

# PCB Layout
Since this design was fairly simple and I didn't want to add extra cost, I chose to make the board on two layers. This did present a challenge at times, but I was still able to route most of my signals on the top layer. This allowed me to use the vast majority of the bottom layer as a ground plane, with only a few cutouts for some signals that couldn't fit on the top layer. 

In addition to the area for my information, there are four main circuit areas on the board, roughly corresponding to the three pages of the schematic:
- Battery holder
- Boost converter and support circuitry
- Microcontroller and support circuitry
- Connector to ePaper and support circuitry

The location of the FPC connector was relatively fixed due to the short length of the FPC cable and the need to have the display centered on the board. Wanting the battery connector to be near the edge of the board also added a constraint to the design. I also wanted to make sure my contact information had plenty of room and wasn't cluttered by components.

Once I had finished laying out the board, I designed a graphic with my name, major, email, and some QR codes to my LinkedIn and the project repository. I had to split the graphic into a layer that would be exposed and gold plated, and an area to be printed in silkscreen. I then used KiCad's image conversion tools to convert both images to layers I could place on the board before placing them in the space I had left earlier.