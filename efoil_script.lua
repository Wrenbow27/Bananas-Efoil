k_p = param:get("SCR_USER4")
k_i = param:get("SCR_USER5")
local reverse_potentiometer = 1 --1 or 0 for reversed state

local min_voltage = 1.1990
local max_voltage = 1.3840
local trim_min = 1100
local trim_max = 1900
local elevator_channel = 11  -- Servo channel for elevator

local script_period = param:get("SCR_USER1")
local low_position = 0.78
local med_position = 0.46
local high_position = 0.23
local position_target = 0
local integral_total = 0
local integral_N = math.floor(param:get("SCR_USER3")/script_period)
local integral_arr = {}
for i = 1, integral_N do integral_arr[i] = 0 end
local integral_i = 1
local true_trim = param:get("SCR_USER2")
local pitch_trim = true_trim

local millis = 0
local log_mode = 0 --stopped
local log_file_name = "ride_height_log.csv"
local file = io.open(log_file_name, "w")
file:write("Time,Desired,Actual\n")
file:close()

local control_enabled = false
local control_button_pressed = false

local function rc_pwm_round(channel)
  local pwm = rc:get_pwm(channel)
  return (math.floor(pwm/100 + 0.5))*100
end

local function aux_inputs()
  rc5 = rc_pwm_round(5)
  rc6 = rc_pwm_round(6)
  rc7 = rc_pwm_round(7)
  --gcs:send_text(0, string.format("RC6: %d",rc6))
  --gcs:send_text(0, string.format("RC7: %d",rc7))
  
  if rc5 == 1900 then 
    log_mode = 0  --stopped
  elseif rc5 == 1500 then
    if log_mode == 0 then
      local file = io.open(log_file_name, "w")
      file:write("Time,Desired,Actual\n")
      file:close()
    end
    log_mode = 1 --paused
  elseif rc5 == 1100 then
    log_mode = 2 --running
  end

  if rc6 == 1100 then
    if (not control_button_pressed) then
      control_enabled = not(control_enabled)
    end
    control_button_pressed = true
  else
    control_button_pressed = false
  end
  
  if rc7 == 1900 
  then position_target = low_position
  elseif rc7 == 1500
  then position_target = med_position
  elseif rc7 == 1100
  then position_target = high_position
  end

end

local analog_in = analog:channel()
if not analog_in:set_pin(14) then
  gcs:send_text(0, "Invalid analog pin")
end

local function log_csv(desired, actual)
  local now = millis / 1000 --log time in s
  file = io.open(log_file_name, "a")
    file:write(string.format("%.2f,%.2f,%.2f\n", now, desired, actual))
    file:close()
end

local function voltage_to_position(voltage)
  local scaled_voltage = (voltage - min_voltage) / (max_voltage - min_voltage)
  local position = math.min(math.max(scaled_voltage, 0), 1)
  if reverse_potentiometer == 1 
  then return -1*position + 1
  else return position
  end
end

local function effort_to_trim(effort)
  return math.floor(true_trim + 400*effort)
end

function update()
  aux_inputs()
  local position = voltage_to_position(analog_in:voltage_average())
  local position_error = math.floor((position - position_target)*100)
  
  integral_total = integral_total + position_error - integral_arr[integral_i] --increment integral_total by new error - oldest error
  integral_arr[integral_i] = position_error --overwrite oldest error with new error
  integral_i = (integral_i % integral_N)+1 --increment index
  
  --ride height logging
  if log_mode == 2 then --if logging :
    log_csv(position_target, position)
  end
  
  local effort = k_p*(position_error/100) + k_i*(integral_total/(100*integral_N))
  if control_enabled then
    pitch_trim = effort_to_trim(effort)
  else
    pitch_trim = true_trim
  end
  
  param:set('SERVO' .. elevator_channel .. '_TRIM', pitch_trim)
  --gcs:send_text(0, string.format("Position: %f",position))
  
  millis = millis + script_period
  return update, script_period
end

gcs:send_text(0, "**V1.2.4** EFoil height control script running")
return update()
