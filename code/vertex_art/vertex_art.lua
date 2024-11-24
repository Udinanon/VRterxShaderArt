
local vertex_art = {}

vertex_art.FFT = require("fft")

-- json = require("json")
pprint = require("pprint")
---TODO:
-- Fix issues with soud data
-- Showcase and share
-- Contact Gman

---Adapt WebGL shader to OpenGL
---@param shader_filename string
---@return string
function vertex_art:prepare_shader(shader_filename)
    local shader_code = lovr.filesystem.read(shader_filename)
    
    pprint.pprint(lovr.filesystem.getDirectoryItems(
    "./vertex_art/art/"))
    -- shader_code = json.decode(lovr.filesystem.read(
        -- "./vertex_art/art/2AAPaBjMMEbZF3peq/art.json"))["settings"]["shader"]
    print(shader_code)
    -- remmeber to escape ( in the match strings but not in the substitute strings!
    shader_code = shader_code:gsub("#define PI", "// #define PI") -- Pi is already defined\
    shader_code = shader_code:gsub("void main%(", "vec4 lovrmain(") -- change function main\
    shader_code = shader_code:gsub("texture2D%(", "getPixel(") -- texture2D is WebGL, not compatible
    shader_code = shader_code:gsub("varying ", "// varying") -- deprecated in 130 OpenGL
    shader_code = shader_code:gsub("}%s*$", "\treturn Projection * View * Transform * gl_Position;\n}") -- return position and add geometry transforms
    local header_shader = lovr.filesystem.read("vertex_art/header.vert")
    return header_shader .. shader_code
end


function vertex_art:init()
    vertex_art.shader_file = "vertex_art/shaders/slash.vert"
    vertex_art.shader_file = "vertex_art/tmp.vert"
    local prepared_shader = self:prepare_shader(vertex_art.shader_file)
    print(prepared_shader)

    print("Get the application data directory.")
    print(lovr.filesystem.getAppdataDirectory())
    print("Get the path of the LÖVR executable.")
    print(lovr.filesystem.getExecutablePath())
    print("Get the location of the save directory.")
    print(lovr.filesystem.getSaveDirectory())
    print("Get the location of the project source.")
    print(lovr.filesystem.getSource())
    print("Get the location of the user's home directory.")
    print(lovr.filesystem.getUserDirectory())
    print("Get the current working directory.")
    print(lovr.filesystem.getWorkingDirectory())

    lovr.filesystem.write("vertex_art_processed.vert", prepared_shader) -- not working?
    vertex_art.shader = lovr.graphics.newShader(prepared_shader, "vertex_art/vertex_art.frag", {})

    --vertex_art.shader = lovr.graphics.newShader("unlit", "vertex_art/shadersspectrogram.frag", {})
    vertex_art.music = lovr.data.newSound(
        "vertex_art/music/digboy - Ed Wrecked (Ruined By digboy) - 02 Touch & Go & Rinse & Repeat.ogg",
        true)
    vertex_art.music = lovr.data.newSound(
        "vertex_art/music/Ken Ishii - Play Biting (Cristian Varela Remix) [Pornographic Recordings].mp3",
        true)    
    vertex_art.fft_samples = 2048
    vertex_art.time_samples = 240
    vertex_art.sample_rate = vertex_art.music:getSampleRate()
    vertex_art.frame_size = vertex_art.sample_rate / 60
    vertex_art.audio_offset = 0
    vertex_art.sound_image = lovr.data.newImage(vertex_art.fft_samples, vertex_art.time_samples, "rgba8")
    -- sound has values 0-255 linearly
    vertex_art.sound_texture = lovr.graphics.newTexture(vertex_art.sound_image,
        { format = "rgba8", linear = false, samples = 1, mipmaps = false, usage = { "sample", "render", "transfer" } })
    vertex_art.float_sound_texture = lovr.graphics.newTexture(vertex_art.fft_samples, 240,
        { format = "rgba32f", linear = true, samples = 1, mipmaps = false, usage = { "sample", "render", "transfer" } })
    vertex_art.volume_texture = lovr.graphics.newTexture(4, 240,
        { format = "rgba8", linear = true, samples = 1, mipmaps = false, usage = { "sample", "render", "transfer" } })
    vertex_art.touch_texture = lovr.graphics.newTexture(32, 240,
        { format = "rgba8", linear = true, samples = 1, mipmaps = false, usage = { "sample", "render", "transfer" } })


    material = lovr.graphics.newMaterial({texture = vertex_art.sound_texture})
    vertex_art.music_source = lovr.audio.newSource(vertex_art.music)
    vertex_art.music_source:play()
end

function vertex_art:load(pass)
    --vertex_art.audio_offset = vertex_art.audio_offset + lovr.headset.getDeltaTime()
    vertex_art.audio_offset = vertex_art.audio_offset + vertex_art.frame_size
 
    local temp_image = lovr.data.newImage(vertex_art.sound_image)
    vertex_art.sound_image:paste(temp_image, 0, 1, 0, 0, vertex_art.fft_samples, vertex_art.time_samples - 1)
    --for x = 1, vertex_art.time_samples do
    local sound_buf, _ = vertex_art.music:getFrames(vertex_art.fft_samples,
            vertex_art.audio_offset )
    -- print(Utils.dump(sound_buf))
    -- aa()
    --+ vertex_art.frame_size * (vertex_art.time_samples- 1)
    local byte_fft = vertex_art.FFT.byte_real_fft(sound_buf)
    --print(math.max(unpack(byte_fft)))
    -- for i, elem in ipairs(byte_fft) do
    --     byte_fft[i] = math.log(math.abs(byte_fft[i]), 10)
    --     
    -- end
    local factor = 255 --255 -- even rgba8 textures are [0, 1]
    for x = 1, vertex_art.fft_samples do
        vertex_art.sound_image:setPixel(vertex_art.fft_samples - x, 0,
        byte_fft[x] / factor, 
        byte_fft[x] / factor,
        byte_fft[x] / factor,
        byte_fft[x] / factor)
    end
    --end


-- empty image
    --local sound_texture = lovr.graphics.newTexture(fft_samples, 240,        { format = "r8", linear = true, samples = 1, mipmaps = false, usage = { "sample", "render", "transfer" } })
    -- floatSound instad uses negative decibels, which is bullshit

    pass:setShader(vertex_art.shader)
    pass:setColor(1, 1, 1, 1)
    pass:send("time", lovr.timer.getTime())
    pass:send("resolution", vec2(1000, 1000))
    pass:send("mouse", vec2(0, 0));
    pass:send("background", vec4(1, 1, 1, 1));
    pass:send("touch", vertex_art.touch_texture)
    pass:send("sound", vertex_art.sound_texture)
    pass:send("floatSound", vertex_art.float_sound_texture)
    pass:send("volume", vertex_art.volume_texture)
    pass:send("soundRes", vec2(1000, 1000));
    pass:send("_dontUseDirectly_pointSize", 1.);
end


function vertex_art.update_textures(transfer_pass)
    --transfer_pass:copy(vertex_art.sound_image, vertex_art.sound_texture) -- v0.16
    vertex_art.sound_texture:setPixels(vertex_art.sound_image) -- v0.17
end


function vertex_art:demo(pass, transfer_pass)

    vertex_art:load(pass)
    vertex_art.update_textures(transfer_pass)
    local indexCount = 18000
    pass:send("vertexCount", indexCount);

    
    --- This creates what i think looks like the TRIANGLES, LINES and POINTS mode
    pass:setMeshMode("triangles")

    --- Allows for arbitrary number of vertices with minimal work (and cost?)
    local buffer = lovr.graphics.getBuffer(indexCount, "vec3")
    pass:mesh(buffer)

    --- This creates the effect of LINE_STRIP
    --local points = {}
    --for i = 1, indexCount do
    --    points[i]= {vec3(0)}
    --end
    --pass:line(points)

   -- pass:plane(mat4(), "line", 10, 9)
    --- nothing different from line
    --pass:circle(mat4(vec3(1, 1, 1)), "line", 0, 2 * math.pi, indexCount)
    pass:setShader()
    pass:setMaterial(material)
    pass:cube(vec3(0, 1, 0))
    pass:setMaterial()
end

return vertex_art

