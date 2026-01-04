local components = require("kernel.components")
require("kernel.circuit_graph")

local side_pane_width = 350
local top_bar_height = 100
local scrollbar = {
    selected = false,
    width = 10,
    x = side_pane_width - 10,
    y = top_bar_height
}
--This is just an alias in case we want add additional padding etc. later on
local cvsx, cvsy = side_pane_width,top_bar_height

function terminal_radius(size)
    return 0.05 * size
end

--For the following functions x,y are the coordinates of the center of the component.
local function draw_endpoint_terminals(x,y,size)
    local terminal_radius = terminal_radius(size)
    love.graphics.circle("fill",x-size/2-terminal_radius,y,terminal_radius)
    love.graphics.circle("fill",x+size/2+terminal_radius,y,terminal_radius)
end

local function draw_ground_terminal(x,y,size)
    local terminal_radius = terminal_radius(size)
    love.graphics.circle("fill",x+size/2+terminal_radius,y,terminal_radius)
end

local function draw_capacitor(x,y,size)
    local plate_x = 0.15 * size  / 2.0
    local plate_y = 0.6 * size / 2.0
    love.graphics.line(x-plate_x,y-plate_y,x-plate_x,y+plate_y)
    love.graphics.line(x+plate_x,y-plate_y,x+plate_x,y+plate_y)
    love.graphics.line(x-size/2,y,x-plate_x,y)
    love.graphics.line(x+plate_x,y,x+size/2.0,y)
end

local function draw_voltage_source(x,y,size)
    local radius = 0.6 * size/2.0
    love.graphics.circle("line",x,y,radius)
    love.graphics.line(x-size/2.0,y,x-radius,y)
    love.graphics.line(x+radius,y,x+size/2.0,y)
    local sign_center = radius / 2.0
    local sign_size = size/20.0
    local x_minus = x - sign_center
    local x_plus = x + sign_center
    if sign_size <= radius then
        --Minus Sign
        love.graphics.line(x_minus-sign_size,y,x_minus+sign_size,y)
        --Plus Sign
        love.graphics.line(x_plus-sign_size,y,x_plus+sign_size,y)
        love.graphics.line(x_plus,y-sign_size,x_plus,y+sign_size)
    end
end

local function draw_resistor(x,y,size)
    local left = x - 0.8 * size/2.0
    local right = x + 0.8 * size/2.0
    love.graphics.line(x-size/2.0,y,left,y)
    local height = size * 0.1
    local width = size * 0.8
    local nbumps = 10
    for j=1,nbumps do
        local x1 = left+(j-1)*width/nbumps
        local x2 = x1 + 0.5*width/nbumps
        local x3 = x2 + 0.5*width/nbumps
        local dy = 0.5*width/nbumps
        local sign = 0.0
        if j % 2 == 0 then
            sign = 1
        else
            sign = -1
        end
        love.graphics.line(x1,y,x2,y + sign*height)
        love.graphics.line(x2,y+sign*height,x3,y)
    end
    love.graphics.line(right,y,x+size/2.0,y)
end

local function draw_open_semicircle(x,y,r,n)
    n = n or 64
    local x0,y0 = x+r,y
    for j=1,n do
        local thetaj = -j/n * math.pi
        local xi = x + r * math.cos(thetaj)
        local yi = y + r * math.sin(thetaj)
        love.graphics.line(x0,y0,xi,yi)
        x0,y0 = xi,yi
    end
end

local function draw_inductor(x,y,size)
    local left = x - 0.8 * size/2.0
    local right = x + 0.8 * size/2.0
    love.graphics.line(x-size/2.0,y,left,y)
    local height = size * 0.1
    local width = size * 0.8
    local nbumps = 4
    for j=1,nbumps do
        local radius = 0.5*width/nbumps
        local xcenter = left + (j-1)*width/nbumps + radius
        draw_open_semicircle(xcenter,y,radius,16)
    end
    love.graphics.line(right,y,x+size/2.0,y)
end

local function draw_diode(x,y,size)
    local diode_size = 0.4 * size
    love.graphics.line(x-0.5*size,y,x+0.5*size,y)
    local diode_left = x - diode_size/2.0
    local diode_right = x + diode_size/2.0
    love.graphics.line(diode_left,y-0.5*diode_size,diode_left,y + 0.5*diode_size)
    love.graphics.line(diode_right,y-0.5*diode_size,diode_right,y + 0.5*diode_size)
    love.graphics.line(diode_left,y+0.5*diode_size,diode_right,y)
    love.graphics.line(diode_left,y-0.5*diode_size,diode_right,y)
end

local function draw_ground(x,y,size)
    love.graphics.line(x,y,x+0.5*size,y)
    love.graphics.line(x,y-0.4*size,x,y+0.4*size)
    love.graphics.line(x-0.1*size,y-0.3*size,x-0.1*size,y+0.3*size)
    love.graphics.line(x-0.2*size,y-0.2*size,x-0.2*size,y+0.2*size)
end

local buttons = {
    size = 40,
    play_hovered = false,
    pause_hovered = false,
    stop_hovered = false,
}

--For the following methods x,y refers to the top right corner
function buttons:draw_play_button(x,y,size)
    if self.play_hovered then
        love.graphics.setColor(0.5,1.0,0.5)
    else
        love.graphics.setColor(0.3,0.9,0.3)
    end
    love.graphics.rectangle("fill",x,y,size,size)
    local x1,y1 = x+size/2-size*0.2,y+size/2 - size*0.4
    local x2,y2 = x+size/2-size*0.2,y+size/2 + size*0.4
    local x3,y3 = x+size/2+size*0.4,y+size/2
    love.graphics.setColor(0.9,0.9,0.9)
    love.graphics.line(x1,y1,x2,y2)
    love.graphics.line(x1,y1,x3,y3)
    love.graphics.line(x2,y2,x3,y3)
end

function buttons:draw_stop_button(x,y,size)
    if self.stop_hovered then
        love.graphics.setColor(1.0,0.5,0.5)
    else
        love.graphics.setColor(0.9,0.3,0.3)
    end
    love.graphics.rectangle("fill",x,y,size,size)
    love.graphics.setColor(0.9,0.9,0.9)
    love.graphics.rectangle("line",x+size/4,y+size/4,size/2,size/2)
end

function buttons:draw_pause_button(x,y,size)
    if self.pause_hovered then
        love.graphics.setColor(0.5,0.5,1.0)
    else
        love.graphics.setColor(0.3,0.3,0.9)
    end
    love.graphics.rectangle("fill",x,y,size,size)
    love.graphics.setColor(0.9,0.9,0.9)
    x,y = x + size/2,y + size/2
    love.graphics.line(x-0.1*size,y-0.3*size,x-0.1*size,y+0.3*size)
    love.graphics.line(x+0.1*size,y-0.3*size,x+0.1*size,y+0.3*size)
end

function buttons:check_mouse(mousex,mousey)
    self.play_hovered = false
    self.pause_hovered = false
    self.stop_hovered = false
    local xplay, yplay = mousex - cvsx, mousey-cvsy
    if 0 <= xplay and xplay <= buttons.size and 0 <= yplay and yplay <= buttons.size then
        self.play_hovered = true
        return true
    end
    local xpause, ypause = xplay - buttons.size , yplay
    if 0 <= xpause and xpause <= buttons.size and 0 <= ypause and ypause <= buttons.size then
        self.pause_hovered = true
        return true
    end
    local xstop, ystop = xplay - 2*buttons.size , yplay
    if 0 <= xstop and xstop <= buttons.size and 0 <= ystop and ystop <= buttons.size then
        self.stop_hovered =  true
        return true
    end
    return false
end


---@class Scrollbar
---@field width number
---@field height number
---@field x number
---@field y number
---@field scroll_x boolean
---@field scroll_y boolean
---@field min_scroll number
---@field max_scroll number
---@field pressed boolean
Scrollbar = {}
---@return Scrollbar
function Scrollbar.new(direction,xinit,yinit,width,height,min_scroll,max_scroll)
    local self = setmetatable(Scrollbar,{
        scroll_x = (direction == "x"),
        scroll_y = (direction == "y"),
        x = xinit,
        y = yinit,
        width = width,
        height = height,
        min_scroll = min_scroll,
        max_scroll = max_scroll,
        pressed = false
    })
    return self
end

function Scrollbar:draw()
    love.rectangle(self.x,self.y,self.width,self.height)
end

function Scrollbar:mousedown(x,y,button)
    if button == 1 then
        if self.x <= x and x <= self.x + self.width then
            self.pressed = true
        end
    end
end

function Scrollbar:mousemoved(x,y,dx,dy)
    if self.pressed and self.scroll_x then
        self.x = math.max(math.min(self.x + dx,self.max_scroll),self.min_scroll)
    end
    if self.pressed and self.scroll_y then
        self.y = math.max(math.min(self.y + dy,self.max_scroll),self.min_scroll)
    end
end

function Scrollbar:mousereleased()
    if self.pressed then
        self.pressed = false
    end
end



local function draw_plot(values, max, plot_size, offsetx, offsety)
    local centery = offsety + 0.5 * plot_size
    local h = plot_size/ (#values-1)
    local x = offsetx
    for i=1,#values-1 do
        local y1 = centery - values[i] / max  * plot_size/2
        local y2 = centery - values[i+1] / max * plot_size/2
        local x1 = x
        local x2 = x + h
        love.graphics.line(x1,y1,x2,y2)
        x = x2
    end
end

---@class RenderComponent
---@field type string
---@field x number
---@field y number
---@field size number
---@field draw_func fun(x:number, y:number, size:number)
---@field selected boolean
---@field is_fresh boolean
RenderComponent = {
    ---@type RenderComponent|nil
    _selected_component = nil,
    ---@type RenderComponent|nil
    _hovered_component = nil,
    _hovered_terminal = {},
    _selected_terminal = {},
    ---@type string | nil
    _hovered_connection = nil,
    ---@type {[string]: fun(x:number, y:number, size:number)}
    _draw_funcs = {
        VoltageSource = draw_voltage_source,
        Resistor = draw_resistor,
        Capacitor = draw_capacitor,
        Inductor = draw_inductor,
        Diode = draw_diode,
        Ground = draw_ground
    }
}

RenderComponent.__index = RenderComponent

function RenderComponent.new(type,xinit,yinit,size,is_fresh)
    local self = setmetatable({},RenderComponent)
    self.type = type
    self.x = xinit
    self.y = yinit
    self.size = size
    self.is_fresh = is_fresh or false
    self.draw_func = RenderComponent._draw_funcs[type]
    return self
end

function RenderComponent:check_mouse(x,y)
    --The ground component is fixed and therefore can't be selected or hovered
    if self.type == "Ground" then
        return false
    end
    local xcheck = self.x - self.size/2 <= x and x <= self.x + self.size/2
    local ycheck = self.y - self.size/2 <= y and y <= self.y + self.size/2
    return xcheck and ycheck
end

function RenderComponent:num_terminals()
    if self.type == "Ground" then
        return 1
    end
    return 2
end

function RenderComponent:check_mouse_terminal(mousex,mousey,offsetx,offsety)
    local r = terminal_radius(self.size)
    for i=1,self:num_terminals() do
        local x,y = self:get_term_position(i,offsetx,offsety)
        if x  - r <= mousex and mousex <= x + r and y-r <= mousey and mousey <= y+r then
            return i
        end
    end
end

function RenderComponent:is_selected()
    return RenderComponent._selected_component == self
end

function RenderComponent:is_hovered()
    return RenderComponent._hovered_component == self
end

function RenderComponent:terminal_is_hovered(term)
    return RenderComponent._hovered_terminal.comp == self and RenderComponent._hovered_terminal.term == term
end

function RenderComponent:terminal_is_selected(term)
    return RenderComponent._selected_terminal.comp == self and RenderComponent._selected_terminal.term == term
end

function RenderComponent:get_term_position(term,offsetx,offsety)
    local r = terminal_radius(self.size)
    if self.type == "Ground" and term == 1 then
        local termx, termy = self.x + offsetx + self.size/2 + r, self.y + offsety
        return termx,termy
    end
    if term == 1 then
        local termx, termy = self.x + offsetx - self.size/2 - r, self.y + offsety
        return termx, termy
    end
    if term == 2 then
        local termx, termy = self.x + offsetx + self.size/2 + r, self.y + offsety
        return termx, termy
    end
end

function RenderComponent:render(offsetx,offsety)
    if self:is_hovered() then
        local cornerx, cornery = self.x + offsetx - self.size/2, self.y + offsety - self.size/2
        love.graphics.rectangle("line",cornerx,cornery,self.size,self.size)
    end
    local wh = 2 * terminal_radius(self.size)
    if self:terminal_is_hovered(1) then
        local termx, termy = self:get_term_position(1,offsetx,offsety)
        love.graphics.rectangle("line",termx-wh/2,termy - wh/2,wh,wh)
    end
    if self:terminal_is_hovered(2) then
        local termx, termy = self:get_term_position(2,offsetx,offsety)
        love.graphics.rectangle("line",termx-wh/2,termy-wh/2,wh,wh)
    end
    if self:terminal_is_selected(1) then
        local termx, termy = self:get_term_position(1,offsetx,offsety)
        love.graphics.rectangle("fill",termx-wh/2,termy-wh/2,wh,wh)
        local mousex, mousey = love.mouse.getPosition()
        love.graphics.line(termx, termy, mousex, mousey)
    end
    if self:terminal_is_selected(2) then
        local termx, termy = self:get_term_position(2,offsetx,offsety)
        love.graphics.rectangle("fill",termx-wh/2,termy-wh/2,wh,wh)
        local mousex, mousey = love.mouse.getPosition()
        love.graphics.line(termx, termy, mousex, mousey)
    end
    if self.type == "Ground" then
        draw_ground_terminal(self.x + offsetx,self.y + offsety,self.size)
    else
        draw_endpoint_terminals(self.x + offsetx,self.y + offsety,self.size)
    end
    self.draw_func(offsetx+self.x,offsety+self.y,self.size)
end

local rendercomponents = {
    RenderComponent.new("Ground",50,buttons.size+50,100,100),
    RenderComponent.new("Capacitor",200,200,100),
    RenderComponent.new("Resistor",200,300,100)
}
local connections = {
    ["1:1,2:1"] = true,
}

local function draw_connections()
    for conn,_ in pairs(connections) do
        if conn == RenderComponent._hovered_connection then
            love.graphics.setColor(1.0,0.0,0.0)
        end
        local comp1,term1,comp2,term2 = conn:match("(%d+):(%d+),(%d+):(%d+)")
        comp1, term1, comp2, term2 = tonumber(comp1), tonumber(term1), tonumber(comp2), tonumber(term2)
        local termx1,termy1 = rendercomponents[comp1]:get_term_position(term1,cvsx,cvsy)
        local termx2,termy2 = rendercomponents[comp2]:get_term_position(term2,cvsx,cvsy)
        love.graphics.line(termx1,termy1,termx2,termy2)
        if conn == RenderComponent._hovered_connection then
            love.graphics.setColor(0.0,0.0,0.0)
        end
    end
end

local prototype_components = {}
local prototype_padding = 30
local function get_prototype_position(i)
    return 50 + (i-1) * (100 + prototype_padding), 50
end

local function component_index(comp)
    for i,rcomp in ipairs(rendercomponents) do
        if comp == rcomp then
            return i
        end
    end
end

local removedcomponents = {}
local function remove_component(comp)
    local compi = component_index(comp)
    removedcomponents[compi] = true
    for conn,_ in pairs(connections) do
        local comp1,term1,comp2,term2 = conn:match("(%d+):(%d+),(%d+):(%d+)")
        comp1, term1, comp2, term2 = tonumber(comp1), tonumber(term1), tonumber(comp2), tonumber(term2)
        if comp1 == compi or comp2 == compi then
            connections[conn] = nil
        end
    end
end

local function iter_components() local i = 1
    return function()
        while removedcomponents[i] do
            i = i + 1
        end
        if i > #rendercomponents then
            return nil
        end
        local comp = rendercomponents[i]
        i = i + 1
        return comp
    end
end

function love.mousepressed(x,y,button,istouch,presses)
    if button == 2 and (RenderComponent._hovered_connection or RenderComponent._hovered_component) then
        local conn = RenderComponent._hovered_connection
        if conn ~= nil then
            connections[conn] = nil
        else
            remove_component(RenderComponent._hovered_component)
        end
    end
    if button == 1 then
        local scrollbarxcond = scrollbar.x <= x   and x <= scrollbar.x + scrollbar.width 
        local scrollbarycond = scrollbar.y <= y and y <= scrollbar.y + scrollbar.height
        if  scrollbarxcond and scrollbarycond then
            scrollbar.selected = true
        elseif 0 <= y and y <= top_bar_height then
            for _,comp in ipairs(prototype_components) do
                if comp:check_mouse(x,y) then
                    RenderComponent._selected_component = RenderComponent.new(comp.type,comp.x-cvsx,comp.y-cvsy,comp.size,true)
                    table.insert(rendercomponents,RenderComponent._selected_component)
                    break
                end
            end
        else
            local selected_term = RenderComponent._selected_terminal
            local hovered_term = RenderComponent._hovered_terminal
            if  selected_term.comp ~= nil and
                hovered_term.comp ~= nil and
                selected_term.term ~= nil and
                hovered_term.term ~= nil then
                local same_comp = selected_term.comp == hovered_term.comp
                local same_term = selected_term.term == hovered_term.term
                if not same_comp or not same_term then
                    local sterm = tostring(component_index(selected_term.comp)) .. ":" .. tostring(selected_term.term)
                    local hterm = tostring(component_index(hovered_term.comp)) .. ":" .. tostring(hovered_term.term)
                    connections[sterm .. "," .. hterm] = true
                    selected_term.comp = nil
                    selected_term.term = nil
                end
            else
                if hovered_term then
                    selected_term.comp = hovered_term.comp
                    selected_term.term = hovered_term.term
                end
            end
            if RenderComponent._hovered_component then
                RenderComponent._selected_component = RenderComponent._hovered_component
            end
        end
    end
end

local function connection_check_mouse(conn,mousex,mousey,offsetx,offsety,linewidth)
    linewidth = linewidth or 10
    local comp1,term1,comp2,term2 = conn:match("(%d+):(%d+),(%d+):(%d+)")
    comp1, term1, comp2, term2 = tonumber(comp1), tonumber(term1), tonumber(comp2), tonumber(term2)
    local term1x,term1y = rendercomponents[comp1]:get_term_position(term1,offsetx,offsety)
    local term2x,term2y = rendercomponents[comp2]:get_term_position(term2,offsetx,offsety)
    local x, y = mousex - term1x, mousey - term1y
    local dx, dy = term2x - term1x, term2y - term1y
    local norm = math.sqrt(dx*dx + dy*dy)
    dx, dy = dx/norm, dy/norm
    local nx, ny = -dy, dx
    local t = x * dx + y * dy
    local s = x * nx + y * ny
    if 0 <= t and t <= norm and linewidth - math.abs(s) >= 0 then
        return linewidth - math.abs(s)
    end
end


function love.mousemoved(x,y,dx,dy)
    if scrollbar.selected then
        scrollbar.y = math.min(math.max(y,top_bar_height),love.graphics.getHeight() - scrollbar.height)
        return
    end
    if buttons:check_mouse(x,y) then
        return
    end
    local selected = RenderComponent._selected_component
    if selected ~= nil then
        if selected.is_fresh or x - selected.size/2 >= cvsx then
            selected.x = x - cvsx
        end
        if selected.is_fresh or y - selected.size/2 >= cvsy then
            selected.y = y - cvsy
        end
    else
        RenderComponent._hovered_component = nil
        RenderComponent._hovered_terminal.comp = nil
        RenderComponent._hovered_terminal.term = nil
        for comp in iter_components() do
            local terminal = comp:check_mouse_terminal(x,y,cvsx,cvsy)
            if terminal then
                RenderComponent._hovered_terminal.comp = comp
                RenderComponent._hovered_terminal.term = terminal
                break
            end
            if comp:check_mouse(x-cvsx,y-cvsy) then
                RenderComponent._hovered_component = comp
                break
            end
        end
    end
    RenderComponent._hovered_connection = nil
    local min_dist = math.huge
    for conn,_ in pairs(connections) do
        local dist = connection_check_mouse(conn,x,y,cvsx,cvsy)
        if  dist ~= nil and dist < min_dist then
            min_dist = dist
            RenderComponent._hovered_connection = conn
        end
    end
end

function love.mousereleased(x,y,button,istouch,presses)
    if scrollbar.selected then
        scrollbar.selected = false
        return
    end
    local selected = RenderComponent._selected_component
    if button == 1 and selected ~= nil then
        if  selected.is_fresh then
            RenderComponent._selected_component.is_fresh = false
            if x - selected.size/2 < cvsx or y - selected.size/2 < cvsy then
                table.remove(rendercomponents,#rendercomponents)
            end
        end
        RenderComponent._selected_component = nil
    end
end

function draw_components()
    love.graphics.setColor(0, 0, 0)
    for comp in iter_components() do
        comp:render(cvsx,cvsy)
    end
end

local example_currents = {}
local example_voltages = {}
for i=1,100 do
    example_currents[i] = math.sin(i*2.0*math.pi/100)
    example_voltages[i] = math.cos(i*2.0*math.pi/100)
end

local plot_data = {
    {
        currents = example_currents,
        voltages = example_voltages
    },
    {
        currents = example_currents,
        voltages = example_voltages
    },
    {
        currents = example_currents,
        voltages = example_voltages
    },
    {
        currents = example_currents,
        voltages = example_voltages
    },
    {
        currents = example_currents,
        voltages = example_voltages
    }
}

local function draw_ui()
    local w,h = love.graphics.getWidth(), love.graphics.getHeight()
    --background for side panel
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.rectangle("fill",0,0,side_pane_width,h)
    local side_pane_height = h - top_bar_height
    --scroll bar
    local plot_size = side_pane_width - scrollbar.width
    local total_plot_height = plot_size * #plot_data
    scrollbar.height = math.min(side_pane_height/total_plot_height,1.0)*side_pane_height
    love.graphics.setColor(0.8,0.8,0.8)
    love.graphics.rectangle("fill",scrollbar.x,scrollbar.y,scrollbar.width,scrollbar.height)
    local scroll_percentage = (scrollbar.y - top_bar_height) / (side_pane_height - scrollbar.height)
    --plots
    for i,data in ipairs(plot_data) do
        local y = top_bar_height - (total_plot_height - side_pane_height)* scroll_percentage + (i-1) * plot_size
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.rectangle("fill",0,y,plot_size,plot_size)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.rectangle("line",0,y,plot_size,plot_size)
        love.graphics.setColor(0.8, 0.8, 0.2)
        draw_plot(data.currents,1,plot_size,0,y)
        love.graphics.setColor(0.8, 0.2, 0.2)
        draw_plot(data.voltages,1,plot_size,0,y)
    end
    --top bar
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.rectangle("fill",0,0,w,top_bar_height)
    love.graphics.setColor(0.0, 0.0, 0.0)
    for _,component in ipairs(prototype_components) do
        component:render(10,0)
    end
    --Play, Pause, Stop Buttons
    buttons:draw_play_button(cvsx + 0*buttons.size,cvsy,buttons.size)
    buttons:draw_pause_button(cvsx + 1*buttons.size,cvsy,buttons.size)
    buttons:draw_stop_button(cvsx + 2*buttons.size,cvsy,buttons.size)
end

function love.load()
    love.window.setMode(1024,720,{resizable=true})
    love.window.setTitle("Lua Circuit Simulator")
    love.graphics.setBackgroundColor(1, 1, 1)
    love.graphics.setLineWidth(2)
    local component_prototypes = {
        "VoltageSource",
        "Resistor",
        "Capacitor",
        "Inductor",
        "Diode"
    }
    for i,type in pairs(component_prototypes) do
        local x, y = get_prototype_position(i)
        table.insert(prototype_components,RenderComponent.new(type,x,y,100))
    end
end

function love.draw()
    draw_ui()
    draw_components()
    draw_connections()
end
