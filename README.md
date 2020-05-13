# Solar MPPT Boost Lead Acid Battery Charger
## A solar powered charger designed for charging lead acid batteries with the same or slightly higher voltage than the solar panel.

## About this project
The tracter is mainly used for mowing grass and does not get used much over the winter. As a result the battery in it has been known to be flat or very close to it by the time it is needed again when the grass starts growing. This charger was built to keep some charge in the battery so that the tractor would have a higher chance of starting when needed and hopefully extending the battery life of it by not letting it sit flat for months.

I built this charge controller mostly out of various parts I had access to that were lying around. The solar panel was from a solar powered water pump and actually outputted 12V as opposed to the 18V from a standared "12V" panel designed for charging lead acid batteries. The solar panel is probably in the range of 10W.

Because of this lower voltage, the battery did not charge when connected directly to the solar panel. Most regular solar charge controllers seem to be designed to run off an 18V solar panel to charge a 12V battery, allowing several volts to play with, whereas I needed a controller that would increase the voltage to charge the battery.

This charger tries to match the power output of the solar panel to the battery to get the most energy into it. It will also not let the battery get above a voltage (13.8v) as set by the variable resistor.

The charger has a boost regulator in it to allow solar panels of a lower voltage than the battery to charge it.

The microcontroller used for this is a [picaxe 08M2](http://www.picaxe.com/Hardware/PICAXE-Chips/PICAXE-08M2-microcontroller/). This is a small microcontroller that is very simple to program and can be programmed and updated "in the field."

The maximum power point tracking part of this is based off a version commonly designed and built for model solar vehicles competing in the [Australian-International Model Solar Vehicle Challenge](https://www.modelsolarchallenge.com.au/) and associated state events for matching the voltage produced by the solar panel to the voltage required by the motor at different stages during the race (stalled when the car is stopped, spinning fast when the car is at top speed) at the most power possible.

## Setting the maximum voltage to charge the battery to
Carefully adjust the potentiometer (white knob with Philips head screw) inside the box – it is quite sensitive. Measure the battery voltage carefully over the next while to check.

## Photos of the original installation
This has since removed as it is no longer required in this spot, but will be redeployed somewhere else at some stage.

The shed and tractor that the charger was used with and the controller mounted on its post.
![The shed and tractor that the charger was used with.](/Photos/TractorInShed.jpg =250x) ![The controller on its post.](/Photos/ControllerOnPost.jpg =250x)

In case someone forgot to unplug the charger and drove off, a pair of bullet connectors were used to disconnect the wires. To stop them being unplugged in normal use, the wire from the rafters to the tractor is supported by a length of string that will break if pulled really hard to let the wires be unplugged.
![Emergency safety release.](/Photos/SafetyRelease.jpg =250x) ![The connector on the tractor end.](/Photos/TractorConnector.jpg =250x)

Inside the controller with the lid removed.()
![Inside the controller with the lid removed](/Photos/Inside.jpg =250x)

## How it works
![Circuit Diagram from /CircuitDiagram/CircuitDiagram_schemFixed_Fixed.png](/CircuitDiagram/CircuitDiagram_schemFixed_Fixed.png)
The voltage regulator (IC2) provides power to a PICAXE 08M2 microcontroller (IC1). The PICAXE measures the solar panel open circuit voltage (or fairly close to it) through the voltage divider on the panel side (R1 and R2). It then multiplies this by 80% to get something fairly close the Maximum Power Point (MPP), where the voltage multiplied by the current produces the most power. This charger cannot measure current, so this is the quickest and easiest way of attempting to find it.

The chip will then put a Pulse Width Modulation (PWM) signal to turn the MOSFET on and off, which then draws and interrupts current in the inductor. This creates spikes in the voltage, which are fed through a diode (D1) into a capacitor(C4), where they are stored. The battery is charged through a second diode (D3). The PICAXE varies the duty cycle of the PWM signal to vary how much energy goes through the boost regulator to try to keep the solar panel voltage at the MPP as it determined previously.

To stop the battery from being overcharged, the chip measures the voltage being put into the battery and keeps the regulator at a constant voltage (13.8V) set by the variable resistor until either the voltage on the battery side falls to below ~13.1V or the solar panel voltage falls below its maximum power point, signalling that there is a load placed on the charger and it should start trying to get the most power that it can out of the solar panel.

The charger also stops charging for a few seconds once every 5 minutes to recalculate the MPP in case it has changed.
The LED (LED1) flashes on start up, when maximising and when sending serial data that a computer could pick up if one is connected. The LED also flashes when the battery is disconnected as it treats the storage capacitor as an extremely small battery and charges it so quickly that it spends most of its time maximising.

Serial communication is achieved with a standard PICAXE programming cable or similar (may require an adapter to convert from an audio jack to the 3 pin header (JP1)) and a serial terminal / reader set to 38400 baud, no parity, 8 data bits and one stop bit. I have been using a standared picaxe usb to serial converter programming cable, which I am pretty sure the signal is inverted (when most standared serial pins are high, the programming pins on a picaxe are low and when most standared serial pins are low, the programming pins on a picaxe are high) compared to a standared usb - serial converter or an arduino. 

This charger will not work properly with solar panels that have a significantly higher (more than a few volts) open circuit voltage than the battery as the charger has no way of actually completely disconnecting the battery and solar panel other than using diodes and relying on the battery voltage being higher or close enough that the solar panel cannot push current through it when the boost regulator is not running, possibly overcharging the battery and interfering with the way the charger works out the optimum voltage to get the most power from the panel (the Maximum Power Point, or MPP). If you want to use this for higher voltage panels, you will need to convert it to a buck regulator.

## Notes
I used this calculator to estimate the correct size for the inductor and other components involved with increasing the voltage, as well as the duty cycles for the pwm to run at: [https://learn.adafruit.com/diy-boost-calc](https://learn.adafruit.com/diy-boost-calc).

**Please note that I built this a while ago and some of the files / documentation may not be up to date or missing. I have also updated the firmware in the controller a bit and am not quite sure which documentation suits which firmware revision. I think it is pretty close now.*