k_p = 1
k_i = 1
local reverse_potentiometer = 1 --1 or 0 for reversed state

local min_voltage = 1.1990
local max_voltage = 1.3840
local trim_min = 1100
local trim_max = 1900
local elevator_channel = 11  -- Servo channel for elevator

local script_period = param:get("SCR_USER1")
local low_position = param:get("SCR_USER2")
local med_position = param:get("SCR_USER3")
local high_position = param:get("SCR_USER4")
local position_target = 0
local integral_total = 0
local integral_N = math.floor(param:get("SCR_USER5")/script_period)
local integral_arr = {}
for i = 1, integral_N do integral_arr[i] = 0 end
local integral_i = 1
local true_trim = param:get("SCR_USER6")

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
  
  if rc6 == 1100 then
    --boot:reboot()
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
  
  integral_total = integral_total + position_error - integral_arr[integral_i]
  integral_arr[integral_i] = position_error
  integral_i = (integral_i % integral_N)+1
  
  local effort = k_p*(position_error/100) + k_i*(integral_total/(100*integral_N))
  local pitch_trim = effort_to_trim(effort)
  param:set('SERVO' .. elevator_channel .. '_TRIM', pitch_trim)
  gcs:send_text(0, string.format("Trim_Value: %d",pitch_trim))
  
  return update, script_period
end

gcs:send_text(0, "**V1.1.1** Elevator trim control script running")
return update()
