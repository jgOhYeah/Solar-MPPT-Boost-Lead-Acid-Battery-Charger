' Solar powered boost battery charger with maximum powerpoint tracking
' See accompanying documentation for more information
' Jotham Gates
' Created 2017
' Modified 01/07/2022

#define VERSION "v2.1"

' pins
symbol PIN_LED = c.0
symbol PIN_VOLTS_OUT = c.1
symbol PIN_MOSFET = c.2
symbol PIN_VOLTS_IN = c.4

' variables
symbol debug_mode = bit0
symbol fixed_mpp_voltage = bit1
symbol battery_voltage = b1
symbol solar_voltage = b2
symbol tmpwd0 = w2
symbol tmpwd0l = b4
symbol tmpwd0h = b5
symbol mpp_voltage_numerator = b6
symbol mpp_voltage_denominator = b7
symbol debug_count = w11
symbol current_duty = w12
symbol mpp_voltage = w13

' EEPROM Addresses
#define EEPROM_MPP_VOLTAGE_MODE 0
#define EEPROM_MPP_FIXED_VOLTAGE 1
#define EEPROM_MPP_NUMERATOR 2
#define EEPROM_MPP_DENOMINATOR 3

#define FIXED 0
#define ADAPTIVE 1

' constants' ' 
#define DUTY_MIN 0 ' 0% duty cycle at 4MHz clock at 15094Hz
#define DUTY_MAX 265 ' 50% duty cycle at 4MHz clock at 15094Hz
#define BAT_MAX 142 ' 14.2 - adjust pot to be this
#define BAT_FLOAT 138 ' ~13.8 - voltage to hold for float charging.
#define OVER_VOLTAGE 180 ' If over this voltage, cut of QUICK! - In case the load is suddenly reduced (battery unplugged)
#define DEBUG_EVERY 1000

init:
	setfreq m32
	sertxd("Solar boost battery charger ", VERSION , cr, lf, "Jotham Gates, Compiled ", ppp_date_uk, cr, lf)

	' Retrieve and print settings
	read EEPROM_MPP_VOLTAGE_MODE, tmpwd0l
	if tmpwd0l = FIXED then
		' Fixed voltage
		fixed_mpp_voltage = FIXED
		read EEPROM_MPP_FIXED_VOLTAGE, mpp_voltage_numerator
		sertxd("Fixed MPP Voltage. Set to ", #mpp_voltage_numerator, cr, lf)
	else
		' Adaptive voltage
		fixed_mpp_voltage = ADAPTIVE
		read EEPROM_MPP_NUMERATOR, mpp_voltage_numerator
		read EEPROM_MPP_DENOMINATOR, mpp_voltage_denominator
		if mpp_voltage_numerator = 255 and mpp_voltage_denominator = 255 then
			' Default EEPROM values from the factory. Load the defaults.
			sertxd("EEPROM Memory seems to have not been set. Setting defaults.")
			write EEPROM_MPP_NUMERATOR, 8
			write EEPROM_MPP_DENOMINATOR, 10
			goto reset_with_msg

		endif
		sertxd("Adaptive MPP Voltage. Set to OCV*", #mpp_voltage_numerator, "/", #mpp_voltage_denominator, cr, lf)

	endif

	' Debug mode and keyboard
	debug_mode = 0
	sertxd("Press:", cr, lf, "  - 'p' to print often", cr, lf, "  - 'f' for fixed mpp voltage mode", cr, lf, "  - 's' to set fixed mpp target voltage", cr, lf, "  - 'a' for adaptive mpp voltage mode (mpp voltage = OCV * numerator / denominator", cr, lf, "  - 'n' for numerator", cr, lf, "  - 'd' for denominator")
	serrxd[16000, continue_init], tmpwd0l
	select tmpwd0l
		case "p"
			sertxd("Enabling debug mode", cr, lf)
			debug_mode = 1
		case "f"
			sertxd("Setting fixed mode", cr, lf)
			write EEPROM_MPP_VOLTAGE_MODE, FIXED
		
		case "s"
			sertxd("Enter the voltage: ")
			serrxd #tmpwd0l
			write EEPROM_MPP_FIXED_VOLTAGE, tmpwd0l
			sertxd(#tmpwd0l, cr, lf, "Set.", cr, lf)

		case "a"
			sertxd("Setting adaptve mode", cr, lf)
			write EEPROM_MPP_VOLTAGE_MODE, ADAPTIVE

		case "n"
			sertxd("Enter the numerator: ")
			serrxd #tmpwd0l
			write EEPROM_MPP_NUMERATOR, tmpwd0l
			sertxd(#tmpwd0l, cr, lf, "Set.", cr, lf)

		case "d"
			sertxd("Enter the denominator: ")
			serrxd #tmpwd0l
			write EEPROM_MPP_DENOMINATOR, tmpwd0l
			sertxd(#tmpwd0l, cr, lf, "Set.", cr, lf)
		
		else
			sertxd("'", tmpwd0l, "' Not recognised", cr, lf)
	endselect
	if debug_mode = 0 then reset_with_msg

continue_init:
	high PIN_LED
	pause 16000
	low PIN_LED
	pause 24000
	readadc PIN_VOLTS_IN, solar_voltage
	sertxd("Initial OCV: ", #solar_voltage, cr, lf)
	current_duty = DUTY_MIN
	pwmout pwmdiv4, PIN_MOSFET, 132, current_duty
	gosub mpp
	
mppt_mode:
	' Maximum Power Point Tracker part
	sertxd("MPPT Mode", cr, lf)
	low PIN_LED
	do
		readadc PIN_VOLTS_IN, solar_voltage
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
		readadc PIN_VOLTS_OUT, battery_voltage
		' Cut of quickly if massivly over voltage
		if battery_voltage >= OVER_VOLTAGE then
			current_duty = DUTY_MIN
			pwmduty PIN_MOSFET, current_duty ' Take action before printing
			sertxd("Overvoltage scram occurred", cr, lf)
			low PIN_LED
		endif

		' Change MOSFET duty cycle
		pwmduty PIN_MOSFET, current_duty

		if debug_mode = 1 then
			gosub debug_charger
			low PIN_LED
		endif

		' Re calibrate mpp every 300 seconds (time increment every 0.5 seconds at 32MHz
		if time > 600 then gosub mpp
	loop while battery_voltage < BAT_MAX
	' Fall through to constant_voltage_mode

constant_voltage_mode:
	' Send a message to say battery charged
	sertxd("CV Mode", cr, lf)
	' repeat until solar panel voltage is below mpp or the battery voltage has dropped sufficiently
	high PIN_LED
	do
		' Re calibrate mpp every 300 seconds (time increment every 0.5 seconds at 32MHz
		if time > 600 then gosub mpp
		' Constant voltage part
		readadc PIN_VOLTS_OUT, battery_voltage
		if battery_voltage > BAT_FLOAT then
			if current_duty > DUTY_MIN then
				current_duty = current_duty - 1
			endif
		endif
		if battery_voltage < BAT_FLOAT then
			if current_duty < DUTY_MAX then
				current_duty = current_duty + 1
			endif
		endif
		' Cut of quickly if massivly over voltage
		if battery_voltage >= OVER_VOLTAGE then
			current_duty = DUTY_MIN
			pwmduty PIN_MOSFET, current_duty ' Take action before printing
			sertxd("Overvoltage scram occurred", cr, lf)
			high PIN_LED
		endif
		pwmduty PIN_MOSFET, current_duty
		readadc PIN_VOLTS_IN, solar_voltage

		if debug_mode = 1 then
			gosub debug_charger
			high PIN_LED
		endif

	loop while solar_voltage >= mpp_voltage
	goto mppt_mode

mpp:
	if fixed_mpp_voltage = 0 then
		' Use the fraction of OCV rule.
		sertxd("Adaptive MPPT. Maximising", cr, lf)
		current_duty = DUTY_MIN
		pwmduty PIN_MOSFET, current_duty
		high PIN_LED
		pause 20000
		low PIN_LED
		pause 20000
		readadc PIN_VOLTS_IN, mpp_voltage
		sertxd("OCV: ", #mpp_voltage)
		mpp_voltage = mpp_voltage * mpp_voltage_numerator / mpp_voltage_denominator ' MPP is roughly 80% of OCV
		sertxd("\tMPP: ", #mpp_voltage, cr, lf, cr, lf)
	else
		' Use a fixed value in EEPROM.
		sertxd("Fixed MPPT at ", #mpp_voltage_numerator, cr, lf)
		mpp_voltage = mpp_voltage_numerator
	endif
	gosub reset_time
return

reset_time:
	disabletime
	time = 0
	enabletime
return

reset_with_msg:
	sertxd("Resetting so changes take effect.", cr, lf, cr, lf)
	reset

debug_charger:
	' Prints a debugging message once every 1000 calls.
	inc debug_count
	if debug_count > DEBUG_EVERY then
		debug_count = 0
		sertxd("Battery is ", #battery_voltage, ", Panel is ", #solar_voltage, cr, lf)
	endif
	return