This was a file I had on my computer with some early ideas for this project:

Timer IC
- [TPL5110](https://www.ti.com/lit/gpn/tpl5110) if design uses mosfet
- [TPL5111](https://www.ti.com/lit/gpn/tpl5111) if LDO is used

MCU

eInk Display
- [This display](https://www.waveshare.com/product/displays/e-paper/epaper-2/3.52inch-e-paper.htm) is ~4mm over in the y direction, but it is very close otherwise
	- Driver circuitry can be found on page 57 of [this datasheet](https://files.waveshare.com/upload/7/7a/UC8253c.pdf).
- [This one](https://www.waveshare.com/wiki/2.9inch_e-Paper_Module) is smaller, but the whole design (components only, traces on back are fine) will probably be able to fit on to one side with it
	- Chip datasheet not available separately, but the waveshare datasheet includes a circuit
	- Seems to be [IL0373](https://github.com/adafruit/Adafruit_EPD/blob/master/src/panels/ThinkInk_290_Grayscale4_T5.h), the Adafruit featherwing probably uses the same module

Battery
- [This](https://www.digikey.com/en/products/detail/seiko-instruments/MS421R-IV03E/11696836) is one of the tiniest rechargable SMT batteries (not replacable though), it is just over 2mm thick
- capacitors won't hold charge for long enough
- [replacable coin cell that can fit](https://www.digikey.com/en/products/detail/seiko-instruments/MS621FE/1887175), [holder](https://www.digikey.com/en/products/detail/keystone-electronics/3098/2745787)
- all of [these parts](https://www.sii.co.jp/en/me/files/2024/01/MicroBattery_E_20230330_rev05-security.pdf) seem good, document also has charging circuit for battery

Solar
- [This part](https://www.digikey.com/en/products/detail/tdk-corporation/BCSC452B3/22608180) from TDK looks good
	- [Video](https://www.digikey.com/en/videos/t/tdk/eye-on-npi-tdk-bcs-series-low-illumination-film-solar-cells-eyeonnpi-digikey-tdkcorporation) showing usage and chip
- [This part](https://www.digikey.com/en/products/detail/panasonic-bsg/AM-1417CA-DGK-E/2165185) is smaller, but it has easy to use wires
- [This chip](https://www.analog.com/en/products/max20361.html) looks useful, but only with higher powered solar module
	- [Like this one](https://www.digikey.com/en/products/detail/anysolar-ltd/SM141K04TFV/14311388)
- [Another analog chip](https://www.analog.com/en/products/adp5091.html?doc=ADP5091-5092.pdf)
- [This one](https://www.ti.com/product/BQ25505) from TI looks good, is low cost, and is active for new designs unlike the analog one
	- [This one](https://www.digikey.com/en/products/detail/texas-instruments/BQ25504RGTR/2799286) is simpler because it doesn't have non-rechargeable battery fallback but it costs more (maybe because it is smaller)
	- Combine with a [boost converter](https://www.ti.com/product/TPS610986) and TPL5111