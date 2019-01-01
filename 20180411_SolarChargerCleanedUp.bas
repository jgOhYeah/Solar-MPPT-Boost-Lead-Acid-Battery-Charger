'Solar powered boost battery charger with maximum powerpoint tracking
'Revision 2.0 - 11 April 2018
'See accompanying documentation for more information
'Jotham Gates 2017 - 2018

'pins
symbol led = c.0
symbol voltsOut = c.1
symbol mosfet = c.2
symbol voltsIn = c.4

'variables
symbol batteryVoltage = b0
symbol solarVoltage = b3
symbol currentDuty = w12
symbol mppVoltage = w13

'constants
symbol dutyMin = 0 '0% duty cycle at 4MHz clock at 15094Hz
symbol dutyMax = 265 '50% duty cycle at 4MHz clock at 15094Hz
symbol batMax = 140 '13.8 - adjust pot to be this
symbol batMin = 137 '~13.1 - voltage at which to drop back into maximising
symbol overVoltage = 200 'If over this voltage, cut of QUICK! - In case the load is suddenly reduced (battery unplugged)
init:
	setfreq m32
	sertxd("Started", 13, 10)
	high led
	pause 16000
	low led
	pause 24000
	readadc voltsIn, solarVoltage
	sertxd("Initial OCV: ", #solarVoltage, 13, 10)
	currentDuty = dutymin
	pwmout pwmdiv4, mosfet, 132, currentDuty
	gosub mpp
	
main:
	'Maximum Power Point Tracker part
	readadc voltsIn, solarVoltage
	if solarVoltage < mppVoltage then
		if currentDuty > dutyMin then
			currentDuty = currentDuty - 1
		endif
	endif
	if solarVoltage > mppVoltage then
		if currentDuty < dutyMax then
			currentDuty = currentDuty + 1
		endif
	endif
	
	'Battery monitoring part
	readadc voltsOut, batteryVoltage
	if batteryVoltage > batMax then gosub batCharged
	'Change MOSFET duty cycle
	pwmduty mosfet, currentDuty
	'Re calibrate mpp every 300 seconds (time increment every 0.5 seconds at 32MHz
	if time > 600 then gosub mpp
	goto main
batCharged:
	'Send a message to say battery charged
	sertxd("Battery Charged", 13, 10)
	'repeat until solar panel voltage is below mpp or the battery voltage has dropped sufficiently
	high led
	do
		'Re calibrate mpp every 300 seconds (time increment every 0.5 seconds at 32MHz
		if time > 600 then gosub mpp
		'Constant voltage part
		readadc voltsOut, batteryVoltage
		if batteryVoltage > batMax then
			if currentDuty > dutyMin then
				currentDuty = currentDuty - 1
			endif
		endif
		if batteryVoltage < batMax then
			if currentDuty < dutyMax then
				currentDuty = currentDuty + 1
			endif
		endif
		'Cut of quickly if massivly over voltage
		if batteryVoltage >= overVoltage then
			currentDuty = dutyMin
		endif
		pwmduty mosfet, currentduty
		readadc voltsIn, solarVoltage
	loop while solarVoltage >= mppVoltage and batteryVoltage >= batMin
	low led
return
mpp:
	sertxd("Maximising",13,10)
	currentDuty = dutyMin
	pwmduty mosfet, currentDuty
	high led
	pause 20000
	low led
	pause 20000
	readadc voltsIn, mppVoltage
	sertxd("OCV: ", #mppVoltage)
	mppVoltage = mppVoltage * 8 / 10 'MPP is roughly 80% of OCV
	sertxd("\tMPP: ", #mppVoltage, 13, 10, 13, 10)
	gosub resetTime
return
resetTime:
	disabletime
	time = 0
	enabletime
return