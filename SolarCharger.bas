' Solar powered boost battery charger with maximum powerpoint tracking
' See accompanying documentation for more information
' Jotham Gates
' Created 2017
' Modified 01/07/2022

#define VERSION "v2.1"

' pins
symbol led = c.0
symbol volts_out = c.1
symbol mosfet = c.2
symbol volts_in = c.4

' variables
symbol debug_mode = bit0
symbol battery_voltage = b1
symbol solar_voltage = b3
symbol current_duty = w12
symbol mpp_voltage = w13

' constants' ' 
symbol DUTY_MIN = 0 ' 0% duty cycle at 4MHz clock at 15094Hz
symbol DUTY_MAX = 265 ' 50% duty cycle at 4MHz clock at 15094Hz
symbol BAT_MAX = 140 ' 13.8 - adjust pot to be this
symbol BAT_MIN = 137 ' ~13.1 - voltage at which to drop back into maximising
symbol OVER_VOLTAGE = 200 ' If over this voltage, cut of QUICK! - In case the load is suddenly reduced (battery unplugged)

init:
	setfreq m32
	sertxd("Solar boost battery charger ", VERSION , cr, lf, "Jotham Gates, Compiled ", ppp_date_uk, cr, lf)
	high led
	pause 16000
	low led
	pause 24000
	readadc volts_in, solar_voltage
	sertxd("Initial OCV: ", #solar_voltage, 13, 10)
	current_duty = DUTY_MIN
	pwmout pwmdiv4, mosfet, 132, current_duty
	gosub mpp
	
main:
	' Maximum Power Point Tracker part
	readadc volts_in, solar_voltage
	if solar_voltage < mpp_voltage then
		if current_duty > DUTY_MIN then
			current_duty = current_duty - 1
		endif
	endif
	if solar_voltage > mpp_voltage then
		if current_duty < DUTY_MAX then
			current_duty = current_duty + 1
		endif
	endif
	
	' Battery monitoring part
	readadc volts_out, battery_voltage
	if battery_voltage > BAT_MAX then gosub batCharged
	' Change MOSFET duty cycle
	pwmduty mosfet, current_duty
	' Re calibrate mpp every 300 seconds (time increment every 0.5 seconds at 32MHz
	if time > 600 then gosub mpp
	goto main
batCharged:
	' Send a message to say battery charged
	sertxd("Battery Charged", 13, 10)
	' repeat until solar panel voltage is below mpp or the battery voltage has dropped sufficiently
	high led
	do
		' Re calibrate mpp every 300 seconds (time increment every 0.5 seconds at 32MHz
		if time > 600 then gosub mpp
		' Constant voltage part
		readadc volts_out, battery_voltage
		if battery_voltage > BAT_MAX then
			if current_duty > DUTY_MIN then
				current_duty = current_duty - 1
			endif
		endif
		if battery_voltage < BAT_MAX then
			if current_duty < DUTY_MAX then
				current_duty = current_duty + 1
			endif
		endif
		' Cut of quickly if massivly over voltage
		if battery_voltage >= OVER_VOLTAGE then
			current_duty = DUTY_MIN
		endif
		pwmduty mosfet, current_duty
		readadc volts_in, solar_voltage
	loop while solar_voltage >= mpp_voltage and battery_voltage >= BAT_MIN
	low led
return
mpp:
	sertxd("Maximising",13,10)
	current_duty = DUTY_MIN
	pwmduty mosfet, current_duty
	high led
	pause 20000
	low led
	pause 20000
	readadc volts_in, mpp_voltage
	sertxd("OCV: ", #mpp_voltage)
	mpp_voltage = mpp_voltage * 8 / 10 ' MPP is roughly 80% of OCV
	sertxd("\tMPP: ", #mpp_voltage, 13, 10, 13, 10)
	gosub resetTime
return
resetTime:
	disabletime
	time = 0
	enabletime
return