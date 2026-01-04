local math = require("math")
---@class GivensRotation
---@field i integer
---@field j integer
---@field c number
---@field s number
local GivensRotation = {}
GivensRotation.__index = GivensRotation

---@return GivensRotation
---@param i integer
---@param j integer
---@param c number
---@param s number
function GivensRotation.new(i,j,c,s)
    ---@type GivensRotation
    local self = setmetatable({i=i,j=j,c=c,s=s},GivensRotation)
    return self
end

--Let v be a VectorF32 with v.data[i] = a, v.data[j] = b.
--The function returns a Givens rotation R such that for w = R:apply_inplace(v) we have w[j] = 0.
---@return GivensRotation
---@param i integer
---@param j integer
---@param a number
---@param b number
function GivensRotation:eliminate(i,j,a,b)
    if a == 0 then
        return GivensRotation.new(i,j,0,1)
    end
    local r = a/math.abs(a) * math.sqrt(a*a + b*b)
    return GivensRotation.new(i,j,a/r,-b/r)
end

---@return number[] 
---@param v number[]
function GivensRotation:apply_inplace(v)
    local vi = self.c * v[self.i] - self.s * v[self.j]
    local vj = self.s * v[self.i] + self.c * v[self.j]
    v[self.i],v[self.j] = vi,vj
    return v
end

---@class GMResSolver
---@field private arnoldiH number[][]
---@field private arnoldiQ number[][]
---@field private givens_rots GivensRotation[]
---@field private givens_e1 number[]
---@field private y number[]
GMResSolver = {}
GMResSolver.__index = GMResSolver
function GMResSolver.new()
    ---@type GMResSolver
    local self = setmetatable({arnoldiH={},
                 arnoldiQ={},
                 givens_e1 = {},
                 givens_rots = {},
                 y = {}},GMResSolver)
    return self
end

function GMResSolver:linmap(dst,q)
    error("Attempting to calll unimplemented abstract method GMResSolver:linmap")
end

---@return number
---@param q1 number[]
---@param q2 number[]
local function dot_product(q1,q2)
    local sum = 0
    for i=1,#q1 do
        sum = sum + q1[i] * q2[i]
    end
    return sum
end

local function zeros(n)
    local x = {}
    for j=1,n do
        x[j] = 0
    end
    return x
end

---@return number
---@param q number[]
local function normalize(q)
    local norm = math.sqrt(dot_product(q,q))
    if norm == 0 then
        return 0
    end
    for j=1,#q do
        q[j] = q[j] / norm
    end
    return norm
end

---@return nil
---@param b number[]
function GMResSolver:arnoldi_init(b,xinit,eps)
    if not self.arnoldiQ[1] then
        self.arnoldiQ[1] = {}
        for j=1,#b do
            self.arnoldiQ[1][j] = 0
        end
    end
    local q = self.arnoldiQ[1]
    self:linmap(q,xinit)
    for j=1,#b do
        q[j] = b[j] - q[j]
    end
    self.givens_e1[1] = normalize(q)
end

--Assume that arnoldiQ contains the first k basis vectors.
--The method computes the basis vector k+1 in the arnoldi process.
--It is stored in arnoldiQ[k].
---@return number[]
---@param k integer
function GMResSolver:arnoldi_iter(k)
    local n = #self.arnoldiQ[k]
    if self.arnoldiQ[k+1] == nil then
        self.arnoldiQ[k+1] = zeros(n)
    end
    if self.arnoldiH[k] == nil then
        self.arnoldiH[k] = {}
    end
    local q, h = self.arnoldiQ[k+1], self.arnoldiH[k]
    self:linmap(q,self.arnoldiQ[k])
    for i=1,k do
        h[i] = dot_product(q,self.arnoldiQ[i])
        for j=1,n do
            q[j] = q[j] - h[i] * self.arnoldiQ[i][j]
        end
    end
    h[k+1] = normalize(q)
    return h
end

function GMResSolver:backsubstitute(x,k)
    for i=1,k do
        local row = k+1-i
        self.y[row] = self.givens_e1[row]
        for j=1,i-1 do
            local col = k+1-j
            --Note that self.arnoldiH is an array of columns 
            self.y[row] = self.y[row] - self.arnoldiH[col][row] * self.y[col]
        end
        self.y[row] = self.y[row] / self.arnoldiH[row][row]
    end
    for i=1,#x do
        local sum = 0
        for j=1,k do
            sum = sum + self.arnoldiQ[j][i] * self.y[j]
        end
        x[i] = x[i] + sum
    end
    return x
end

---@return number[],integer,number
---@param b number[]
---@param x number[]
---@param maxiter integer | nil
---@param eps number | nil
function GMResSolver:solve(b,x,eps,maxiter)
    local n = #b
    maxiter = maxiter or 64
    maxiter = math.min(maxiter,n)
    eps = eps or 1e-6
    if not x then
       x = zeros(n)
    end
    local nb = math.sqrt(dot_product(b,b))
    if nb == 0 then
        for i=1,n do
            x[i] = 0
        end
        return x,0,0
    end
    self:arnoldi_init(b,x)
    local res = math.abs(self.givens_e1[1]/nb)
    if  res < eps then
        return x,0,res
    end
    for k=1,maxiter do
        local h = self:arnoldi_iter(k)
        for l=1,k-1 do
            self.givens_rots[l]:apply_inplace(h)
        end
        self.givens_rots[k] = GivensRotation:eliminate(k,k+1,h[k],h[k+1])
        self.givens_rots[k]:apply_inplace(h)
        self.givens_e1[k+1] = 0
        self.givens_rots[k]:apply_inplace(self.givens_e1)
        res = math.abs(self.givens_e1[k+1]/nb)
        if res ~= res then
            error("Encountered nan value in GMResSolver:solve possibly due to singular matrix!")
        end
        if  res <= eps then
            return self:backsubstitute(x,k),k,res
        end
    end
    return self:backsubstitute(x,maxiter),maxiter,eps
end

return {GMResSolver = GMResSolver}
