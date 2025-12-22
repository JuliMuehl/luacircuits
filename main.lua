local libs = require("frontend.load_libs")
local glfw = libs.glfw
local gl = libs.gl
local gl_util = libs.gl_util
local math = require("math")
local ffi = require("ffi")

local vertex_shader_source = [[
#version 330 core
in vec2 in_uv;
void main() { gl_Position = vec4(in_uv.x, in_uv.y, 0.0, 1.0);
}
]]

local fragment_shader_source = [[
#version 330 core
out vec4 frag_color;

void main() {
    frag_color = vec4(1.0);
}
]]

glfw.glfwInit()
local window = glfw.glfwCreateWindow(640,480,"Window",nil,nil)
glfw.glfwMakeContextCurrent(window)
glfw.glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
glfw.glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3)
glfw.glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE)
local quad_buffer = gl_util.create_vertex_buffer({0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,1.0,1.0})
local program = gl_util.create_shader_program(vertex_shader_source,fragment_shader_source)

local function plot_curve(x,y,linewidth)
    linewidth = linewidth or 5e-3
    local coords = {}
    for i=1,#x-1 do
        local dx1,dy1 = x[i+1] - x[i], y[i+1] - y[i]
        local norm1 = math.sqrt(dx1*dx1 + dy1*dy1)
        local nx1, ny1 = -dy1/norm1, dx1/norm1
        table.insert(coords,x[i] - linewidth*nx1)
        table.insert(coords,y[i] - linewidth*ny1)
        table.insert(coords,x[i] + linewidth*nx1)
        table.insert(coords,y[i] + linewidth*ny1)
    end
    local dx1,dy1 = x[#x] - x[#x-1], y[#x] - y[#x-1]
    local norm1 = math.sqrt(dx1*dx1 + dy1*dy1)
    local nx1, ny1 = -dy1/norm1, dx1/norm1
    table.insert(coords, x[#x] - linewidth*nx1)
    table.insert(coords, y[#x] - linewidth*ny1)
    table.insert(coords, x[#x] + linewidth*nx1)
    table.insert(coords, y[#x] + linewidth*ny1)
    local buffer = gl_util.create_vertex_buffer(coords)
    gl.glBindBuffer(GL_ARRAY_BUFFER,buffer)
    gl.glEnableVertexAttribArray(0)
    gl.glVertexAttribPointer(0,2,GL_FLOAT,false,0,nil)
    gl.glDrawArrays(GL_TRIANGLE_STRIP,0,#coords/2)
    gl.glDeleteBuffers(1,ffi.new("unsigned int[1]",{buffer}))
end


require("kernel.circuit_graph")
local components = require("kernel.components")

local network = CircuitGraph:new()
function source(t)
    local tmod = math.fmod(t,200)
    return 100 * math.sin(t/100*2*math.pi)
end
local VCC = components.VoltageSource.new(source)
local C = components.Capacitor.new(15e-6)
local R = components.Resistor.new(10)
local L = components.Inductor.new(1)
local D = components.Diode.new()
local vcc = network:add_component(VCC)

local d = network:add_component(D)

network:set_ground_terminal(vcc,1)
network:add_connection(vcc,2,d,1)
network:add_connection(d,2,vcc,1)
network:compute_nodes()

network.time_step = 5e-2
local plot_times = {}
local plot_voltages = {}
local n = 20000
for  _=1,n do
    network:implicit_euler_step()
    local v = D.current
    table.insert(plot_voltages,v)
    table.insert(plot_times,network.sim_time)
end

local max = plot_voltages[1]
for i=1,n do
    max = math.max(math.abs(plot_voltages[i]),max)
end
local max_time = plot_times[#plot_times]
local ground_voltages = {}
for i=1,n do
    plot_times[i] = (plot_times[i]/max_time) * 2 - 1
    if max ~= 0 then
        plot_voltages[i] = 0.9*((plot_voltages[i]) / max)
    end
    ground_voltages[i] = 0
end

while glfw.glfwWindowShouldClose(window) == 0 do
    glfw.glfwSwapBuffers(window)
    gl.glClear(GL_COLOR_BUFFER_BIT)
    plot_curve(plot_times,plot_voltages)
    plot_curve(plot_times,ground_voltages)
    glfw.glfwPollEvents()
end
