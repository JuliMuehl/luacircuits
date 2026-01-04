local function get_voltage(voltages,index)
    if index == 0 then return 0 end
    return voltages[index]
end

local function increment_current(currents,index,curr)
    if index == 0 then return end
    currents[index] = currents[index] + curr
end

---@class Component
---@field num_terminals integer
---@field component_type string
---@field terminals integer[] | nil
---@field public is_nonlinear boolean
Component = {is_nonlinear = false,num_terminals = 2}
Component.__index = Component

---@return boolean
---@param terminal_i number
function Component:has_terminal(terminal_i)
    return 1 <= terminal_i and terminal_i <= self.num_terminals
end

function Component:is_voltage_source()
    return self.component_type == "VoltageSource"
end

---@param time number
---@param time_step number
---@param voltages number[]
---@param currents number[]
function Component:initialize_currents(time,time_step,currents,voltages)
end

---@param time number
---@param time_step number
---@param voltages number[]
---@param currents number[]
function Component:linmap_step(time,time_step,currents,voltages)
end

---@class Capacitor:Component
---@field capacitance number
Capacitor = {component_type="Capacitor",num_terminals=2}
setmetatable(Capacitor,Component)
Capacitor.__index = Capacitor

---@returns Capacitor
---@param capacitance number | nil
function Capacitor.new(capacitance)
    capacitance = capacitance or 1e-12 --Default 1muF
    return setmetatable({capacitance = capacitance},Capacitor)
end

---@param time number
---@param time_step number
---@param voltages number[]
---@param currents number[]
function Capacitor:initialize_currents(time,time_step,currents,voltages)
    if time_step > 0 then
        local conductance = self.capacitance / time_step
        local node1, node2 = self.terminals[1],self.terminals[2]
        local curr = conductance * (get_voltage(voltages,node2) - get_voltage(voltages,node1))
        increment_current(currents,node1,-curr)
        increment_current(currents,node2,curr)
    end
end

---@param time number
---@param time_step number
---@param voltages number[]
---@param currents number[]
function Capacitor:linmap_step(time,time_step,currents,voltages)
    local node1, node2 = self.terminals[1],self.terminals[2]
    local conductance = 1e-8
    if time_step > 0 then
        conductance = self.capacitance / time_step
    end
    local curr = conductance * (get_voltage(voltages,node2) - get_voltage(voltages,node1))
    increment_current(currents,node1,-curr)
    increment_current(currents,node2,curr)
end

---@class Inductor:Component
---@field inductance number
---@field current number
Inductor = {component_type="Inductor",num_terminals=2}
setmetatable(Inductor,Component)
Inductor.__index = Inductor

---@returns Inductor
---@param inductance number | nil
---@params current number | nil
function Inductor.new(inductance,current)
    inductance = inductance or 1e-2 --Default 10mH
    current = current or 0
    return setmetatable({inductance = inductance, current=current},Inductor)
end

---@param time number
---@param time_step number
---@param voltages number[]
---@param currents number[]
function Inductor:initialize_currents(time,time_step,currents,voltages)
    --We solve A_u{k+1} =  i_{k+1} - i_{k}
    local node1, node2 = self.terminals[1],self.terminals[2]
    increment_current(currents,node1,-self.current)
    increment_current(currents,node2,self.current)
    local conductance = time_step / self.inductance
    local curr = conductance * (get_voltage(voltages,node2) - get_voltage(voltages,node1))
    --Explicit euler update for inductor current (i_{k+1} = i_k + h/L u_k) 
    self.current = self.current - curr
end

---@param time number
---@param time_step number
---@param voltages number[]
---@param currents number[]
function Inductor:linmap_step(time,time_step,currents,voltages)
    local node1, node2 = self.terminals[1],self.terminals[2]
    local conductance = time_step / self.inductance
    local curr = conductance * (get_voltage(voltages,node2) - get_voltage(voltages,node1))
    increment_current(currents,node1,-curr)
    increment_current(currents,node2,curr)
end

---@class Resistor:Component
---@field resistance number
Resistor = {component_type="Resistor",num_terminals=2}
Resistor.__index = Resistor
setmetatable(Resistor,Component)

---@returns Resistor
---@param resistance number | nil
function Resistor.new(resistance)
    resistance = resistance or 1000 --Default 1kOhm
    return setmetatable({resistance = resistance},Resistor)
end

---@param time number
---@param time_step number
---@param voltages number[]
---@param currents number[]
function Resistor:linmap_step(time,time_step,currents,voltages)
    local node1, node2 = self.terminals[1], self.terminals[2]
    local conductance = 1.0 / self.resistance
    local curr = conductance * (get_voltage(voltages,node2) - get_voltage(voltages,node1))
    increment_current(currents,node1,-curr)
    increment_current(currents,node2,curr)
end

---@class VoltageSource:Component
---@field voltage_func function(t : number) : number
---@field source_index integer | nil
VoltageSource = {component_type="VoltageSource",num_terminals=2}
VoltageSource.__index = VoltageSource
setmetatable(VoltageSource,Component)
---@returns VoltageSource
---@param voltage_func function(t : number) : number
function VoltageSource.new(voltage_func)
    func = func or function(t) return 5.0 end --Default V(t) = 5V
    ---@type VoltageSource
    return setmetatable({voltage_func=voltage_func},VoltageSource)
end

---@param time number
---@param time_step number
---@param voltages number[]
---@param currents number[]
function VoltageSource:initialize_currents(time,time_step,currents,voltages)
    currents[self.source_index] = self.voltage_func(time)
end

---@param time number
---@param time_step number
---@param voltages number[]
---@param currents number[]
function VoltageSource:linmap_step(time,time_step,currents,voltages)
    local node1,node2 = self.terminals[1],self.terminals[2]
    local curr = get_voltage(voltages,node2) - get_voltage(voltages,node1)
    increment_current(currents,self.source_index,curr)
    increment_current(currents,node1,voltages[self.source_index])
    increment_current(currents,node2,-voltages[self.source_index])
end

---@class Diode:Component
---@field saturation_current number
---@field itv number Inverse thermal voltage i.e. 1/(nU_T)
---@field current number
---@field parasitic_capacitance
---Default values from spice
Diode = setmetatable({
    saturation_current = 1e-14,
    itv = 1.0 / 25.856e-3,
    nonlinear=true },Component)
Diode.__index = Diode

function Diode.new(saturation_current,itv)
    return setmetatable({
        saturation_current = saturation_current,
        current = 0,
        itv = itv},Diode)
end

---@param time number
---@param time_step number
---@param voltages number[]
---@param currents number[]
function Diode:initialize_currents(time,time_step,currents,voltages)
    local node1, node2 = self.terminals[1], self.terminals[2]
    local voltage = get_voltage(voltages,node2) - get_voltage(voltages,node1)
    local parasitic_current = 1e-2 * self.saturation_current * voltage
    local curr = self.current + parasitic_current
    increment_current(currents,node1,-curr)
    increment_current(currents,node2,curr)
    self.current = (math.exp(self.itv*voltage) - 1) * self.saturation_current
end

---@param time number
---@param time_step number
---@param voltages number[]
---@param currents number[]
function Diode:linmap_step(time,time_step,currents,voltages)
    local node1, node2 = self.terminals[1],self.terminals[2]
    local voltage = get_voltage(voltages,node2) - get_voltage(voltages,node1)
    local conductance = self.itv*(self.current + self.saturation_current)
    increment_current(currents,node1,-conductance * voltage)
    increment_current(currents,node2,conductance * voltage)
end

return {
    Capacitor = Capacitor,
    Inductor = Inductor,
    Resistor = Resistor,
    VoltageSource = VoltageSource,
    Diode = Diode,
}
