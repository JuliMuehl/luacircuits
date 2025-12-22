local libs = require("frontend.load_libs")
local glfw = libs.glfw
local gl_util = libs.gl_util
local gl = libs.gl

local ffi = require("ffi")

function to_cstr(luastr)
    local cstr = ffi.new("char[?]",#luastr+1)
    ffi.copy(cstr,luastr)
    return cstr
end

---@class GraphEditor
---@field in_uv_location integer
---@field uv_buffer integer
---@field component_program integer
---@field instance_position_location integer
---@field component_vao integer
---@field component_positions_buffer integer
---@field u_component_size_location integer
---@field u_width_location integer
---@field u_height_location integer
---@field u_cam_pos_location integer
---@field u_zoom_location integer
GraphEditor = {}
GraphEditor.__index = GraphEditor

local component_vertex_shader_source = [[
#version 330 core
in vec2 in_uv;
in vec2 instance_position;
uniform float u_component_size;
uniform float u_width;
uniform float u_height;
uniform vec2 u_cam_pos;
uniform float u_zoom;
out vec2 frag_uv;
void main() { 
    frag_uv = in_uv;
    vec2 coords = u_zoom*(instance_position - u_cam_pos + 0.5 * u_component_size * (in_uv*2.0 - 1.0));
    vec2 normalized = vec2(coords.x,coords.y) * vec2(u_height/u_width,1.0);
    gl_Position = vec4(normalized, 0.0, 1.0);
}
]]

local component_fragment_shader_source = [[
#version 330 core
in vec2 frag_uv;
out vec4 frag_color;

void main() {
    frag_color = vec4(frag_uv,0.0,1.0);
}
]]

---@return GraphEditor
function GraphEditor.new()
    local self = setmetatable(GraphEditor,{})
    self.component_program = gl_util.create_shader_program(component_vertex_shader_source,component_fragment_shader_source)
    self.in_uv_location = gl.glGetAttribLocation(self.component_program,to_cstr("in_uv"))
    self.uv_buffer = gl_util.create_vertex_buffer({0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,1.0,1.0})
    self.instance_position_location = gl.glGetAttribLocation(self.component_program,to_cstr("instance_position"))

    local component_vao = ffi.new("unsigned int[1]")
    gl.glGenVertexArrays(1,component_vao)
    self.component_vao = component_vao[0]
    gl.glBindVertexArray(self.component_vao)
    gl.glEnableVertexAttribArray(self.in_uv_location)
    gl.glBindBuffer(GL_ARRAY_BUFFER,self.uv_buffer)
    gl.glVertexAttribPointer(self.in_uv_location,2,GL_FLOAT,GL_FALSE,0,nil)
    self.component_positions_buffer = gl_util.create_vertex_buffer({})
    gl.glBindBuffer(GL_ARRAY_BUFFER,self.component_positions_buffer)
    gl.glEnableVertexAttribArray(self.instance_position_location)
    gl.glVertexAttribPointer(self.instance_position_location,2,GL_FLOAT,GL_FALSE,0,nil)
    gl.glVertexAttribDivisor(self.instance_position_location,1)
    gl.glBindVertexArray(0)
    self.u_component_size_location = gl.glGetUniformLocation(self.component_program,"u_component_size")
    self.u_width_location = gl.glGetUniformLocation(self.component_program,"u_width")
    self.u_height_location = gl.glGetUniformLocation(self.component_program,"u_height")
    self.u_cam_pos_location = gl.glGetUniformLocation(self.component_program,"u_cam_pos")
    self.u_zoom_location = gl.glGetUniformLocation(self.component_program,"u_zoom")
    return self
end

function GraphEditor:render_components(component_positions,component_size,cam_pos,zoom,viewport)
    component_size = component_size or 0.2
    gl.glUseProgram(self.component_program)
    gl.glUniform1f(self.u_component_size_location,component_size)
    gl.glUniform1f(self.u_width_location,viewport.width)
    gl.glUniform1f(self.u_height_location,viewport.height)
    gl.glUniform1f(self.u_component_size_location,component_size)
    gl.glUniform1f(self.u_zoom_location,zoom)
    gl.glUniform2f(self.u_cam_pos_location,cam_pos.x,cam_pos.y)
    gl.glBindVertexArray(self.component_vao)
    gl.glBindBuffer(GL_ARRAY_BUFFER,self.component_positions_buffer)
    gl.glBufferData(GL_ARRAY_BUFFER,ffi.sizeof("float") * #component_positions,ffi.new("float[?]",#component_positions,component_positions),GL_STATIC_DRAW)
    gl.glDrawArraysInstanced(GL_TRIANGLES,0,6,math.floor(#component_positions/ 2))
end

function GraphEditor:render_connections(component_positions,component_size,component_connections,line_width,aspect_ratio)
end

function GraphEditor:render_component_terminals()
end

glfw.glfwInit()
local width_p,height_p = ffi.new("int[1]"),ffi.new("int[1]")
width_p[0],height_p[0] = 640,480
local window = glfw.glfwCreateWindow(width_p[0],height_p[0],"Window",nil,nil)
glfw.glfwMakeContextCurrent(window)

local graph_editor = GraphEditor.new()

gl.glClearColor(0.0,0.0,0.0,1.0)
gl.glViewport(0,0,640,480)

local camera_pos = {x = 0,y = 0}
local zoom = 1.0
local viewport = {width=640,height=480}

local mouse_x,mouse_y = ffi.new("double[1]"),ffi.new("double[1]")
local pressed = false
local ref_x, ref_y = 0, 0
glfw.glfwSetMouseButtonCallback(window, function(window,button,action,mods)
    if button == GLFW_MOUSE_BUTTON_RIGHT and action == GLFW_PRESS then
        ref_x, ref_y = mouse_x[0], mouse_y[0]
        pressed = true
    end
    if button == GLFW_MOUSE_BUTTON_RIGHT and action == GLFW_RELEASE then
        pressed = false
    end
end);


glfw.glfwSetScrollCallback(window, function(window,x,y)
    zoom = math.max(zoom + 0.1*y,0.1)
    print(zoom)
end);

while glfw.glfwWindowShouldClose(window) == 0 do
    gl.glClear(GL_COLOR_BUFFER_BIT)
    local old_width,old_height = width_p[0],height_p[0]
    if pressed then
        local delta_x, delta_y = mouse_x[0] - ref_x, mouse_y[0] - ref_y
        camera_pos.x =  camera_pos.x- (delta_x)/viewport.width * 2 / zoom
        camera_pos.y =  camera_pos.y+ (delta_y)/viewport.height * 2 / zoom
        ref_x, ref_y = mouse_x[0], mouse_y[0]
    end
    glfw.glfwGetWindowSize(window,width_p,height_p)
    if old_width ~= width_p[0] or old_height ~= height_p[0] then
        gl.glViewport(0,0,width_p[0],height_p[0])
        viewport.width, viewport.height = width_p[0], height_p[0]
    end
    glfw.glfwGetCursorPos(window,mouse_x,mouse_y)
    graph_editor:render_components({-0.4,-0.4,0.4,0.4,-0.4,0.4,0.4,-0.4,0.0,0.0},0.4,camera_pos,zoom,viewport)
    glfw.glfwPollEvents()
    glfw.glfwSwapBuffers(window)
end
