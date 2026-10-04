function love.conf(t)
    t.identity = "m3u-editor"
    t.window.title = "M3U Editor"
    t.window.width = 640
    t.window.height = 480
    t.window.resizable = false
    t.window.fullscreen = true
    t.modules.joystick = true
    t.modules.physics = false
    t.modules.video = false
end
