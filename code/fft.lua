-- Inspired by the code at Rosetta Stone https://rosettacode.org/wiki/Fast_Fourier_transform#Lua
-- How tf did Gauss think of this in 1806

-- operations on complex number
local complex = { __mt = {__index = {}} }

function complex.new(r, i)
    local new = { r = r, i = i or 0 }
    setmetatable(new, complex.__mt)
    return new
end

local ffi = require "ffi"
ffi.cdef[[
    typedef struct {double r, i;} C_Complex_t;
]]
C_Complex = ffi.metatype("C_Complex_t", complex.__mt)

function complex.__mt.__add(c1, c2)
    return complex.new(c1.r + c2.r, c1.i + c2.i)
end

function complex.__mt.__sub(c1, c2)
    return complex.new(c1.r - c2.r, c1.i - c2.i)
end

function complex.__mt.__mul(c1, c2)
    return complex.new(c1.r * c2.r - c1.i * c2.i,
        c1.r * c2.i + c1.i * c2.r)
end

function complex.expi(i)
    return complex.new(math.cos(i), math.sin(i))
end

function complex.__mt.__tostring(c)
    return "(" .. c.r .. "," .. c.i .. ")"
end

function complex.__mt.__index.magnitude(self)
    local magnitude = math.sqrt(self.i*self.i + self.r * self.r)
    return magnitude
end

local FFT = {}

---Compute FFT of COMPLEX number table
---@param vector table
---@return table fft_vector
function FFT.fft(vector)
    local len = #vector
    -- Base case
    if len <= 1 then
        return vector
    end
    -- Divide phase of FFT
    local odd, even = {}, {}
    for i = 1, len, 2 do 
        odd[#odd+1] = vector[i]
        even[#even+1] = vector[i+1]
    end
    -- Conquer
    FFT.fft(odd)
    FFT.fft(even)
    -- Combine
    for k = 1, len / 2 do
        local t = even[k] * complex.expi(-2 * math.pi * (k - 1) / len)
        vector[k] = odd[k] + t;
        vector[k + len / 2] = odd[k] - t;
    end
    return vector
end

---Convert table of Real numbers to Complex equivalent
---@param real_vector table
---@return table complex_vector
function FFT._to_complex(real_vector)
    local complex_vector={}
    for i,r in ipairs(real_vector) do
        complex_vector[i]=complex.new(r)
    end
    return complex_vector
end

function FFT._vector_magnitude(complex_vector)
    local magnitude_vector = {}
    for i, c in ipairs(complex_vector) do
        magnitude_vector[i] = c:magnitude()
    end
    return magnitude_vector
end

---Compute FFT of real valued table
---@param real_vector table
---@return table fft_vector
function FFT.real_fft(real_vector)
    assert(type(real_vector)=="table", "The vector must be a table!")
    local complex_vector = FFT._to_complex(real_vector)
    local fftd_complex = FFT.fft(complex_vector)
    local result = FFT._vector_magnitude(fftd_complex)
    return result
end

function FFT._byte_normalize(vector)
    local max_val = math.max(unpack(vector))
    local min_val = math.min(unpack(vector))
    for i, v in ipairs(vector) do
        vector[i] = math.floor(((vector[i] - min_val) / (max_val - min_val)) * 255)
    end
    return vector
end

function FFT.byte_real_fft(samples)
    local result = FFT.real_fft(samples)
    print("PRE " .. math.max(unpack(result)))
    print(math.min(unpack(result)))
    for i, elem in ipairs(result) do
        result[i] = math.log((result[i]), 10)
    end
    print("Post ".. math.max(unpack(result)))
    print(math.min(unpack(result)))
    local normalized_result = FFT._byte_normalize(result)
    print("normalized " .. math.max(unpack(normalized_result)))
    print(math.min(unpack(normalized_result)))
    return normalized_result
end

return FFT