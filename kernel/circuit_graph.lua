local components = require("kernel.components")
require("kernel.krylov")
---@class CircuitGraph : GMResSolver 
---@field private components Component[]
---@field private voltage_sources VoltageSource[]
---@field private connections {[string]:boolean}
---@field private node_map {[string]:integer} | nil
---@field private self.num_unique_nodes integer[] | nil
---@field private ground_terminal string | nil
---@field private voltages number[] | nil
---@field private currents number[] | nil
---@field public time_step number
---@field public sim_time number
---@field private nonlinear boolean
---@field private num_newton_iters integer
CircuitGraph = {sim_time=0,time_step = 0,nonlinear=false,num_newton_iters = 10}
CircuitGraph.__index = CircuitGraph
setmetatable(CircuitGraph,GMResSolver)
---@returns CircuitGraph
function CircuitGraph.new()
    local self = GMResSolver.new()
    ---@cast self CircuitGraph
    self.components = {}
    self.connections = {}
    self.voltage_sources = {}
    setmetatable(self,CircuitGraph)
    return self
end

---@return integer
---@param comp Component
function CircuitGraph:add_component(comp)
    if comp:is_voltage_source() then
        table.insert(self.voltage_sources,comp)
    end
    if comp.is_nonlinear then
        self.nonlinear = true
    end
    table.insert(self.components,comp)
    return #self.components
end

---@param comp_1 integer
---@param terminal_1 integer
---@param comp_2 integer
---@param terminal_2 integer
function CircuitGraph:add_connection(comp_1,terminal_1,comp_2,terminal_2)
    if not self.components[comp_1]:has_terminal(terminal_1) then
        error(("Wrong terminal index %d for component of type %s!"):format(terminal_1,self.components[comp_1].component_type))
    end
    if not self.components[comp_2]:has_terminal(terminal_2) then
        error(("Wrong terminal index %d for component of type %s!"):format(terminal_2,self.components[comp_2].component_type))
    end
    local connstr = comp_1 .. ":" .. terminal_1 .. "," .. comp_2 .. ":" .. terminal_2
    self.connections[connstr] = true
end

---@param comp integer
---@param terminal integer
function CircuitGraph:set_ground_terminal(comp,terminal)
    self.ground_terminal = comp .. ":" .. terminal
end

---@return number
---@param comp integer
---@param terminal integer
function CircuitGraph:get_voltage(comp,terminal)
    if self.ground_terminal == nil then
        error("Ground terminal is required in order to compute voltages!")
    end
    local node = self.node_map[comp .. ":" .. terminal]
    if node == 0 then
        return 0
    else
        return self.voltages[node]
    end
end

---@return Component
function CircuitGraph:get_component(comp)
    return self.components[comp]
end

---@return number
---@param comp integer
---@param terminal integer
function CircuitGraph:set_voltage(comp,terminal,voltage)
    if self.ground_terminal == nil then
        error("Ground terminal is required in order to compute voltages!")
    end
    local node = self.node_map[comp .. ":" .. terminal]
    if node == 0 then
        error("Can't set ground voltage!")
    else
        self.voltages[node] = voltage
    end
end

function CircuitGraph:compute_nodes()
    if self.ground_terminal == nil then
        error("Must set ground terminal before computing nodes!")
    end
    local num_nodes = 1
    local unique_nodes = {1}
    self.node_map = {[self.ground_terminal]=1}
    for conn,_ in pairs(self.connections) do
        local terminal_1,terminal_2 = conn:match("(%d+:%d+),(%d+:%d+)")
        local node_1, node_2 = self.node_map[terminal_1], self.node_map[terminal_2]
        if node_1 and node_2 then
            --Note that since we take the minimum and node_1,node_2 >= 1 we never remove the ground node
            local node = math.min(node_1,node_2)
            self.node_map[terminal_1] = node
            self.node_map[terminal_2] = node
            if node_1 ~= node_2 then
                table.remove(unique_nodes,math.max(node_1,node_2))
            end
        else
            local node = node_1 or node_2
            if not node then
                num_nodes = num_nodes + 1
                node = num_nodes
                table.insert(unique_nodes,node)
            end
            self.node_map[terminal_1] = node
            self.node_map[terminal_2] = node
        end
    end
    --Map unique nodes to range 0, self.num_unique_nodes-1
    --0 will be chosen as the ground node
    local unique_node_index = {}
    self.num_unique_nodes  = 0
    for _,node in pairs(unique_nodes) do
        unique_node_index[node] = self.num_unique_nodes
        self.num_unique_nodes = self.num_unique_nodes + 1
    end
    for k,v in pairs(self.node_map) do
        self.node_map[k] = unique_node_index[v]
    end
    --Define component.terminals and voltage_source.source_index
    for comp_i,component in ipairs(self.components) do
        component.terminals = {}
        for i=1,component.num_terminals do
            local terminal_str = comp_i .. ":" .. i
            component.terminals[i] = self.node_map[terminal_str]
            if component.terminals[i] == nil then
                error("Floating terminals are not allowed. Connect to ground with a high-value resistor instead!")
            end
        end
    end
    for volt_i,voltage_source in ipairs(self.voltage_sources) do
        voltage_source.source_index = self.num_unique_nodes-1 + volt_i
    end
    self.voltages = {}
    self.currents = {}
    for i=1,self.num_unique_nodes + #self.voltage_sources do
        self.voltages[i] = 0
        self.currents[i] = 0
    end
end

function CircuitGraph:linmap(dst,q)
    local currents, voltages = dst, q
    for i=1,#currents do
        currents[i] = 0
    end
    for _,component in ipairs(self.components) do
        component:linmap_step(self.sim_time,self.time_step,currents,voltages)
    end
    return currents
end

function CircuitGraph:newton_step()
    for _,comp in ipairs(self.components) do
        comp:initialize_currents(self.sim_time,self.time_step,self.currents,self.voltages)
    end
    self:solve(self.currents,self.voltages)
end

function CircuitGraph:implicit_euler_step()
    for i=1,#self.currents do
        self.currents[i] = 0
    end
    self:newton_step()
    if self.nonlinear then
        for i=1,self.num_newton_iters do
            self:newton_step()
        end
    end
    self.sim_time = self.sim_time + self.time_step
end
