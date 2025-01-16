// This file contains modified content from Waveshare's example code for their
// ePaper displays for STM32. The original licence notices follow:
// *****************************************************************************
// * | File        :   EPD_3IN52.C
// * | Author      :   Waveshare team
// * | Function    :   3.52inch e-paper
// * | Info        :
// *----------------
// * | This version:   V1.0
// * | Date        :   2022-05-07
// * | Info        :
// * -----------------------------------------------------------------------------
// #
// # Permission is hereby granted, free of charge, to any person obtaining a copy
// # of this software and associated documnetation files (the "Software"), to deal
// # in the Software without restriction, including without limitation the rights
// # to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// # copies of the Software, and to permit persons to  whom the Software is
// # furished to do so, subject to the following conditions:
// #
// # The above copyright notice and this permission notice shall be included in
// # all copies or substantial portions of the Software.
// #
// # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// # FITNESS OR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// # AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// # LIABILITY WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// # OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// # THE SOFTWARE.
// #
// ******************************************************************************
// *****************************************************************************
// * | File        :   DEV_Config.c
// * | Author      :   Waveshare team
// * | Function    :   Hardware underlying interface
// * | Info        :
// *                Used to shield the underlying layers of each master
// *                and enhance portability
// *----------------
// * | This version:   V2.0
// * | Date        :   2018-10-30
// * | Info        :
// # ******************************************************************************
// # Permission is hereby granted, free of charge, to any person obtaining a copy
// # of this software and associated documnetation files (the "Software"), to deal
// # in the Software without restriction, including without limitation the rights
// # to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// # copies of the Software, and to permit persons to  whom the Software is
// # furished to do so, subject to the following conditions:
// #
// # The above copyright notice and this permission notice shall be included in
// # all copies or substantial portions of the Software.
// #
// # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// # FITNESS OR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// # AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// # LIABILITY WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// # OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// # THE SOFTWARE.
// #
// ******************************************************************************
// *****************************************************************************
// * | File        :   EPD_3IN52_test.c
// * | Author      :   Waveshare team
// * | Function    :   3.52inch e-paper test demo
// * | Info        :
// *----------------
// * | This version:   V1.0
// * | Date        :   2020-07-16
// * | Info        :
// #
// # Permission is hereby granted, free of charge, to any person obtaining a copy
// # of this software and associated documnetation files (the "Software"), to deal
// # in the Software without restriction, including without limitation the rights
// # to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// # copies of the Software, and to permit persons to  whom the Software is
// # furished to do so, subject to the following conditions:
// #
// # The above copyright notice and this permission notice shall be included in
// # all copies or substantial portions of the Software.
// #
// # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// # FITNESS OR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// # AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// # LIABILITY WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// # OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// # THE SOFTWARE.
// #
// ******************************************************************************

const msp = @import("./msp430.zig");
const pins = @import("./pins.zig");
const hal = @import("./hal-embedded.zig");

//GC 0.9S
// used
const EPD_3IN52_lut_R20_GC = [_]u8{
    0x01, 0x0f, 0x0f, 0x0f, 0x01, 0x01, 0x01,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};
// used
const EPD_3IN52_lut_R21_GC = [_]u8{ 0x01, 0x4f, 0x8f, 0x0f, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
//used
const EPD_3IN52_lut_R22_GC = [_]u8{ 0x01, 0x0f, 0x8f, 0x0f, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
// used
const EPD_3IN52_lut_R23_GC = [_]u8{ 0x01, 0x4f, 0x8f, 0x4f, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
// used
const EPD_3IN52_lut_R24_GC = [_]u8{ 0x01, 0x0f, 0x8f, 0x4f, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };

/// Refresh the eInk display.
pub fn refresh() void {
    pins.ePD_DataCommand.setPin(false); // command mode
    msp.eusci.sendDataSync(0x17); // refresh sequence
    pins.ePD_DataCommand.setPin(true); // data mode
    msp.eusci.sendDataSync(0xA5);
    msp.busyWait(1); // make sure the pin is set before busy waiting
    msp.eusci.enableSWReset(true); // disable the SPI for now
    pins.ePD_Busy.waitForChange(.LowToHigh); // go to LPM4 until the display is done
    msp.eusci.enableSWReset(false);
}

// This was the second branch of the LUT code if the lut was redownloaded
// EPD_3IN52_SendCommand(0x22);    // bw r
// for(count = 0; count < 56 ; count++)
// {
//     EPD_3IN52_SendData(EPD_3IN52_lut_R23_GC[count]);
// }

// EPD_3IN52_SendCommand(0x23);    // wb w
// for(count = 0; count < 42 ; count++)
// {
//     EPD_3IN52_SendData(EPD_3IN52_lut_R22_GC[count]);
// }

// EPD_3IN52_Flag = 0;

/// Enter deep sleep and then power off the display
pub fn powerOff() void {
    pins.ePD_DataCommand.setPin(false); // command mode
    msp.eusci.sendDataSync(0x07); // deep sleep
    pins.ePD_DataCommand.setPin(true); // data mode
    msp.eusci.sendDataSync(0xA5);

    msp.busyWait(4); // wait for shutdown
    pins.ePD_Power.setPin(false); // remove power
}

pub fn initDisplay() void {
    pins.ePD_DataCommand.setPin(false); // set DC to 0
    pins.ePD_Reset.setPin(false); // set reset to low while starting up
    pins.ePD_Power.setPin(true); // apply power
    msp.busyWait(4); // datasheet requires waiting 1ms from 95% VDD before releasing reset
    pins.ePD_Reset.setPin(true); // release reset
    msp.busyWait(4); // datasheet requires waiting 1ms from 90% rst before sending commands
    msp.eusci.setFetchData(setupFetchData);
}

var setup_stage: u8 = 0;
const stage0_data = [_]u8{ 0x03, 0x10, 0x3F, 0x3F, 0x03 };
const stage1_data = [_]u8{ 0x37, 0x3D, 0x3D };
const stage2_data = [_]u8{ 0xF0, 0x01, 0x68 };

fn setupFetchData() void {
    switch (setup_stage) {
        0 => {
            // There is not a lot of room between mode switches in these first bytes, just do them sync.
            pins.ePD_DataCommand.setPin(false); // command mode
            msp.eusci.sendDataSync(0x00); // panel setting   PSR
            pins.ePD_DataCommand.setPin(true); // data mode
            // changing this byte may fix mirroring issues
            msp.eusci.sendDataSync(0xFF); // RES1 RES0 REG KW/R     UD    SHL   SHD_N  RST_N
            msp.eusci.sendDataSync(0x01); // x x x VCMZ TS_AUTO TIGE NORG VC_LUTZ
            pins.ePD_DataCommand.setPin(false); // command mode
            msp.eusci.sendDataSync(0x01); // POWER SETTING   PWR
            pins.ePD_DataCommand.setPin(true); // data mode
            // This should be enough time to get a few instructions off.
            setup_stage += 1;
            msp.eusci.sendSlice(&stage0_data);
            // buffer is full, so int shouldn't be tripped immidiately.
            // from now on, this function will be called in IRQ.
            msp.eusci.setTXInt(true);
        },
        1 => {
            // sending command byte next, so flush everything
            msp.eusci.busyWaitForComplete();
            pins.ePD_DataCommand.setPin(false); // command mode
            msp.eusci.sendDataSync(0x06); // booster soft start   BTST
            pins.ePD_DataCommand.setPin(true); // data mode
            setup_stage += 1;
            msp.eusci.sendSlice(&stage1_data);
        },
        2 => {
            // lots of two byte commands
            msp.eusci.busyWaitForComplete();

            pins.ePD_DataCommand.setPin(false); // command mode
            msp.eusci.sendDataSync(0x60); // TCON settingTCON
            pins.ePD_DataCommand.setPin(true); // data mode
            msp.eusci.sendDataSync(0x22); // S2G[3:0] G2S[3:0]   non-overlap = 12

            pins.ePD_DataCommand.setPin(false); // command mode
            msp.eusci.sendDataSync(0x82); // VCOM_DC settingVDCS
            pins.ePD_DataCommand.setPin(true); // data mode
            msp.eusci.sendDataSync(0x07); // x  VDCS[6:0]VCOM_DC value= -1.9v    00~3f, 0x12=-1.9v

            pins.ePD_DataCommand.setPin(false); // command mode
            msp.eusci.sendDataSync(0x30);
            pins.ePD_DataCommand.setPin(true); // data mode
            msp.eusci.sendDataSync(0x07);

            pins.ePD_DataCommand.setPin(false); // command mode
            msp.eusci.sendDataSync(0xe3); // power savingPWS
            pins.ePD_DataCommand.setPin(true); // data mode
            msp.eusci.sendDataSync(0x88); // VCOM_W[3:0] SD_W[3:0]

            pins.ePD_DataCommand.setPin(false); // command mode
            msp.eusci.sendDataSync(0x61); // resoultion setting
            pins.ePD_DataCommand.setPin(true); // data mode
            setup_stage += 1;
            msp.eusci.sendSlice(&stage2_data);
        },
        3 => {
            msp.eusci.busyWaitForComplete();
            pins.ePD_DataCommand.setPin(false); // command mode
            msp.eusci.sendDataSync(0x50);
            pins.ePD_DataCommand.setPin(true); // data mode
            msp.eusci.sendDataSync(0xB7);

            // Now we are done with the setup function. start sending LUT data
            // waveshare's code does this after the image is sent, but I don't
            // see why this order won't work.

            pins.ePD_DataCommand.setPin(false); // command mode
            msp.eusci.sendDataSync(0x20); // vcom
            pins.ePD_DataCommand.setPin(true); // data mode
            setup_stage += 1;
            msp.eusci.sendSlice(EPD_3IN52_lut_R20_GC[0..56]);
        },
        4 => {
            msp.eusci.busyWaitForComplete();
            pins.ePD_DataCommand.setPin(false); // command mode
            msp.eusci.sendDataSync(0x21); // red not use
            pins.ePD_DataCommand.setPin(true); // data mode
            setup_stage += 1;
            msp.eusci.sendSlice(EPD_3IN52_lut_R21_GC[0..42]);
        },
        5 => {
            msp.eusci.busyWaitForComplete();
            pins.ePD_DataCommand.setPin(false); // command mode
            msp.eusci.sendDataSync(0x24); // bb b
            pins.ePD_DataCommand.setPin(true); // data mode
            setup_stage += 1;
            msp.eusci.sendSlice(EPD_3IN52_lut_R24_GC[0..42]);
        },
        6 => {
            msp.eusci.busyWaitForComplete();
            pins.ePD_DataCommand.setPin(false); // command mode
            msp.eusci.sendDataSync(0x22); // bw r
            pins.ePD_DataCommand.setPin(true); // data mode
            setup_stage += 1;
            msp.eusci.sendSlice(EPD_3IN52_lut_R22_GC[0..56]);
        },
        7 => {
            msp.eusci.busyWaitForComplete();
            pins.ePD_DataCommand.setPin(false); // command mode
            msp.eusci.sendDataSync(0x23); // wb w
            pins.ePD_DataCommand.setPin(true); // data mode
            setup_stage += 1;
            msp.eusci.sendSlice(EPD_3IN52_lut_R23_GC[0..42]);
        },
        8 => {
            // All of the non-image setup the display needs is done.
            // Switch over to the image data handler.
            msp.eusci.busyWaitForComplete();
            pins.ePD_DataCommand.setPin(false); // command mode
            msp.eusci.sendDataSync(0x13); //Transfer new data
            pins.ePD_DataCommand.setPin(true); // data mode

            // once the mode is switched, shut down the eUSCI module to reconfigure it
            msp.eusci.enableSWReset(true);
            // the display expects the MSB to be the lowest pixel, but it's stored in the LSB here
            // switch byte order to fix this
            msp.eusci.setSPIBitOrder(false);
            msp.eusci.enableSWReset(false);
            msp.eusci.setTXInt(true); // txint bit was cleared, need to reenable

            // reset to zero to prevent unpredictible behavior
            setup_stage = 0;

            // switch to new fetchData
            msp.eusci.setFetchData(hal.imageFetchData);
        },
        else => unreachable,
    }
}
