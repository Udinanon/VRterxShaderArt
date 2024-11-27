function lovr.load()
    local vertex_shader_code = lovr.filesystem.read("out.vert")
    --print(vertex_shader_code)
    shader = lovr.graphics.newShader(vertex_shader_code, "vertex_art.frag", {})
end

function lovr.draw(pass)
    pass:transform(vec3(0, 1.7, -3), vec3(1, 1, 1), quat())
    pass:text("LOADED")
    pass:setShader(shader)
    pass:cube()
    local indexCount = 18000
    pass:send("vertexCount", indexCount);
    local buffer = lovr.graphics.getBuffer(indexCount, "vec3")
    pass:mesh(buffer)
    pass:setColor(1, 1, 1, 1)
    pass:send("time", lovr.timer.getTime())
    pass:send("resolution", vec2(1000, 1000))
    pass:send("mouse", vec2(0, 0));
    pass:send("background", vec4(1, 1, 1, 1))
    pass:send("soundRes", vec2(1000, 1000))
    pass:send("_dontUseDirectly_pointSize", 1.)
end

function lovr.errhand(message)
    print(message)
end