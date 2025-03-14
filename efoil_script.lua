local analog_in = analog:channel()
if not analog_in:set_pin(14) then
  gcs:send_text(0, "Invalid analog pin")
end

local min_voltage = 1.1990
local max_voltage = 1.3840
local trim_min = 1100
local trim_max = 1900
local elevator_channel = 11  -- Servo channel for elevator

local function voltage_to_position(voltage)
  local scaled_output = (voltage - min_voltage) / (max_voltage - min_voltage)
  return math.min(math.max(scaled_output, 0), 1)
end

local function position_to_trim(position)
  return math.floor(trim_min + position * (trim_max - trim_min))
end

function update()
  local voltage = analog_in:voltage_average()
  local position_value = voltage_to_position(voltage)
  local trim_value = position_to_trim(position_value)
  
  -- Adjust the elevator trim dynamically
  param:set('SERVO' .. elevator_channel .. '_TRIM', trim_value)
  
  gcs:send_text(0, string.format("Position: %.3f, Elevator Trim: %d", position_value, trim_value))
  
  return update, 100
end

gcs:send_text(0, "**V2** Elevator trim control script running")
return update()
