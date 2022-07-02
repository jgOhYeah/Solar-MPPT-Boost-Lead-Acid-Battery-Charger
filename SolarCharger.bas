' Solar powered boost battery charger with approximated maximum powerpoint
' tracking.
' Aims to keep the solar panel voltage at ~80% OCV, or can be set to a fixed
' value or some other fraction. See accompanying documentation for more
' information.
'
' Written by Jotham Gates, based on a MPPT design used in model solar vehicle
' races (https://www.modelsolar.org.au/).
' Created 2017
' Modified 02/07/2022

#picaxe 08m2
#no_data

#define VERSION "v2.1"

' pins
symbol PIN_LED = c.0
symbol PIN_VOLTS_OUT = c.1
symbol PIN_MOSFET = c.2
symbol PIN_VOLTS_IN = c.4

' variables
symbol debug_mode = bit0
symbol fixed_mpp_voltage = bit1
symbol bulk_charge = bit2
symbol battery_voltage = b1
symbol solar_voltage = b2
symbol battery_target_voltage = b3
symbol tmpwd0 = w2
symbol tmpwd0l = b4
symbol tmpwd0h = b5
symbol mpp_voltage_numerator = b6
symbol mpp_voltage_denominator = b7
symbol led_on_threshlod = b8 ' Solar voltage at which the LED will turn on in float mode.
symbol previous_time = w10
symbol debug_count = w11
symbol current_duty = w12
symbol mpp_voltage = w13

' EEPROM Addresses
#define EEPROM_MPP_VOLTAGE_MODE 0
#define EEPROM_MPP_FIXED_VOLTAGE 1
#define EEPROM_MPP_NUMERATOR 2
#define EEPROM_MPP_DENOMINATOR 3

#define ADAPTIVE 0
#define FIXED 1

' constants' ' 
#define DUTY_MIN 0 ' 0% duty cycle at 4MHz clock at 15094Hz
#define DUTY_MAX 265 ' 50% duty cycle at 4MHz clock at 15094Hz
#define BAT_MAX 145 ' 14.4 - adjust pot to be this
#define BAT_FLOAT 138 ' 13.8 - voltage to hold for float charging.
#define BAT_MIN 126 ' Voltage to reenter bulk charging when below this.
#define BAT_MIN_LOCKOUT_TIME 60 ' Must have been running for 30s since last mppt before the under voltage can be recognised.
#define OVER_VOLTAGE 180 ' If over this voltage, cut of QUICK! - In case the load is suddenly reduced (battery unplugged)
#define DEBUG_EVERY 800
#define LED_ON_OFFSET 3 ' If solar_voltage > mpp_voltage + LED_ON_OFFSET, then led on, else off in float mode.

init:
	setfreq m32 ' 38400 Baud
	sertxd("Solar boost battery charger ", VERSION , cr, lf, "Jotham Gates, Compiled ", ppp_date_uk, cr, lf, "For more info, go to https://github.com/jgOhYeah/Solar-MPPT-Boost-Lead-Acid-Battery-Charger/", cr, lf)
	' Retrieve and print settings
	read EEPROM_MPP_VOLTAGE_MODE, fixed_mpp_voltage
	if fixed_mpp_voltage = FIXED then
		' Fixed voltage
		read EEPROM_MPP_FIXED_VOLTAGE, mpp_voltage_numerator
		sertxd("Fixed MPP Voltage. Set to ", #mpp_voltage_numerator, cr, lf)
	else
		' Adaptive voltage
		read EEPROM_MPP_NUMERATOR, mpp_voltage_numerator
		read EEPROM_MPP_DENOMINATOR, mpp_voltage_denominator
		if mpp_voltage_numerator = 0 or mpp_voltage_denominator = 0 then
			' Default EEPROM values from the factory. Load the defaults.
			sertxd("EEPROM Memory seems to have not been set. Setting defaults.")
			write EEPROM_MPP_NUMERATOR, 8
			write EEPROM_MPP_DENOMINATOR, 10
			goto reset_with_msg

		endif
		sertxd("Adaptive MPP Voltage. Set to OCV*", #mpp_voltage_numerator, "/", #mpp_voltage_denominator, cr, lf)

	endif

	' Debug mode and settings
	debug_mode = 0
	sertxd("Press:", cr, lf, "  - 'p' to print often", cr, lf, "  - 'f' for fixed mpp voltage mode", cr, lf, "  - 's' to set fixed mpp target voltage", cr, lf, "  - 'a' for adaptive mpp voltage mode (mpp voltage = OCV * numerator / denominator", cr, lf, "  - 'n' for numerator", cr, lf, "  - 'd' for denominator", cr, lf)
	serrxd[32000, continue_init], tmpwd0l
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
	reconnect
	sertxd("Continuing startup", cr, lf)
	high PIN_LED
	pause 4000
	gosub set_bulk_charge
	readadc PIN_VOLTS_IN, solar_voltage
	sertxd("Initial OCV: ", #solar_voltage, cr, lf)
	current_duty = DUTY_MIN
	pwmout pwmdiv4, PIN_MOSFET, 132, current_duty
	gosub mpp
	
main:
	' Read voltages
	readadc PIN_VOLTS_IN, solar_voltage
	readadc PIN_VOLTS_OUT, battery_voltage

	' Cut of quickly if massivly over voltage
	if battery_voltage >= OVER_VOLTAGE then
		current_duty = DUTY_MIN
		pwmduty PIN_MOSFET, current_duty ' Take action before printing
		sertxd("Overvoltage scram occurred", cr, lf)
	endif

	' Calculate and set the new duty cycle
	if solar_voltage < mpp_voltage or battery_voltage > battery_target_voltage then
		if current_duty > DUTY_MIN then
			current_duty = current_duty - 1
		endif
	endif
	if solar_voltage > mpp_voltage and battery_voltage < battery_target_voltage then
		if current_duty < DUTY_MAX then
			current_duty = current_duty + 1
		endif
	endif
	pwmduty PIN_MOSFET, current_duty

	' Debugging
	if debug_mode = 1 then gosub debug_charger

	' Re calibrate mpp every 300 seconds (time increment every 0.5 seconds at 32MHz
	if time > 600 then gosub mpp

	' State machine for charging
	' When started or if battery voltage ever falls below 12.6V, charge up to 14.3V.
	' When 14.3V is reached, hold at 13.8V.
	if bulk_charge = 1 then
		if battery_voltage >= BAT_MAX then gosub set_float_charge
		' Flash the led often
		if time != previous_time then
			toggle PIN_LED
			previous_time = time
		endif
	else
		if battery_voltage < BAT_MIN and time > BAT_MIN_LOCKOUT_TIME then gosub set_bulk_charge
		' LED is on when voltage limited, LED is off when at mpp
		if solar_voltage > led_on_threshlod then
			high PIN_LED
		else
			low PIN_LED
		endif
	endif
	goto main

mpp:
	if fixed_mpp_voltage = ADAPTIVE then
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

	led_on_threshlod = mpp_voltage + LED_ON_OFFSET
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
		sertxd("Battery is ", #battery_voltage, ",\tPanel is ", #solar_voltage, ",\tDuty is ", #current_duty, cr, lf)
	endif
	return

set_bulk_charge:
	' Sets the voltages to charge to 14.3V
	sertxd("Bulk charging to ", #BAT_MAX, "V", cr, lf)
	bulk_charge = 1
	battery_target_voltage = BAT_MAX
	return

set_float_charge:
	' Sets the voltages to hold at 13.8V
	sertxd("Float charging at ", #BAT_FLOAT, "V", cr, lf)
	bulk_charge = 0
	battery_target_voltage = BAT_FLOAT
	return