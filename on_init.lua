ON_INIT = {}

function on_init()
    if ON_INIT then
        for i, f in ipairs(ON_INIT) do
            f()
        end
    end
end
script.on_init(on_init)
script.on_configuration_changed(on_init)