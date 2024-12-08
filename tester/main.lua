FFT = require("fft")

function lovr.load()
    local vertex_shader_code = lovr.filesystem.read("out.vert")
    --print(vertex_shader_code)
    shader = lovr.graphics.newShader(vertex_shader_code, "vertex_art.frag", {})
    indexCount = 1000000
    mesh_mode_index = 1
    mesh_modes = {"points", "lines", "triangles"}

    fft_samples = 2048
    time_samples = 240
    sample_rate = 44100 --music:getSampleRate()
    frame_size = sample_rate / 60
    audio_offset = 0
    sound_image = lovr.data.newImage(fft_samples, time_samples, "rgba32f")
    -- sound has values 0-255 linearly
    sound_texture = lovr.graphics.newTexture(sound_image,
        { format = "rgba32f", linear = false, samples = 1, mipmaps = false, usage = { "sample", "render", "transfer" } })
    float_sound_texture = lovr.graphics.newTexture(fft_samples, 240,
        { format = "rgba32f", linear = true, samples = 1, mipmaps = false, usage = { "sample", "render", "transfer" } })
    volume_texture = lovr.graphics.newTexture(4, 240,
        { format = "rgba8", linear = true, samples = 1, mipmaps = false, usage = { "sample", "render", "transfer" } })
    touch_texture = lovr.graphics.newTexture(32, 240,
        { format = "rgba8", linear = true, samples = 1, mipmaps = false, usage = { "sample", "render", "transfer" } })


    for x = 1, fft_samples do
        for y = 1, time_samples do
            
            sound_image:setPixel(x-1, y-1,
            1, 1, 1, 1)
        end
    end
        --local factor = 255 --255 -- even rgba8 textures are [0, 1]
    -- for x = 1, fft_samples do
        -- sound_image:setPixel(fft_samples - x, 0,
            -- 0, 0, 0, 0)
    -- end

    sound_texture:setPixels(sound_image)


    music = lovr.data.newSound(
    "digboy - Ed Wrecked (Ruined By digboy) - 02 Touch & Go & Rinse & Repeat.ogg",
    true)
    music_source = lovr.audio.newSource(music)
    music_source:play()
    material = lovr.graphics.newMaterial({ texture = sound_texture })
end

function lovr.keypressed(key, scancode, repeating)
    if key == "j" then
        indexCount = math.floor(indexCount * 1.1)
        print(indexCount)
    end
    if key == "k" then
        if indexCount > 1000 then
            indexCount = math.floor(indexCount / 1.1)
        end
        print(indexCount)
    end
    if key == "l" then
        mesh_mode_index = ((mesh_mode_index + 1) % #mesh_modes) +1
    end
end

function lovr.draw(pass)
    audio_offset = audio_offset + frame_size

    local temp_image = lovr.data.newImage(sound_image)
    sound_image:paste(temp_image, 0, 1, 0, 0, fft_samples, time_samples - 1)
    --for x = 1, time_samples do
    local sound_buf, _ = music:getFrames(fft_samples,
        audio_offset)
    -- print(Utils.dump(sound_buf))
    -- aa()
    --+ frame_size * (time_samples- 1)
    local byte_fft = FFT.byte_real_fft(sound_buf)
    --print(math.max(unpack(byte_fft)))
    -- for i, elem in ipairs(byte_fft) do
    --     byte_fft[i] = math.log(math.abs(byte_fft[i]), 10)
    --
    -- end
    local factor = 255 --255 -- even rgba8 textures are [0, 1]
    for x = 1, fft_samples do
        sound_image:setPixel(fft_samples - x, 0,
            byte_fft[x] / factor,
            byte_fft[x] / factor,
            byte_fft[x] / factor,
            --((math.sin(lovr.timer.getTime())+1)/2))
            byte_fft[x] / factor)
    end
    sound_texture:setPixels(sound_image)

    pass:transform(vec3(0, 1.7, -3), vec3(1, 1, 1), quat())
    --pass:text("LOADED")
    pass:setShader(shader)
    --pass:cube()
    pass:setMeshMode(mesh_modes[mesh_mode_index])
    pass:send("vertexCount", indexCount);
    local buffer = lovr.graphics.getBuffer(indexCount, "vec3")
    pass:mesh(buffer)
    --pass:setColor(1, 1, 1, 1)
    pass:send("time", lovr.timer.getTime())
    pass:send("resolution", vec2(1000, 1000))
    pass:send("mouse", vec2(0, 0));
    pass:send("background", vec4(1, 1, 1, 1))
    pass:send("soundRes", vec2(1000, 1000))
    pass:send("_dontUseDirectly_pointSize", 1.)
    pass:send("touch", touch_texture)
    pass:send("sound", sound_texture)
    pass:send("floatSound", float_sound_texture)
    pass:send("volume", volume_texture)
    pass:setShader()
    pass:setMaterial(material)
    pass:cube(vec3(0.5, 2, 0))
    pass:setMaterial()
end

function lovr.errhand(message)
    print(message)
end