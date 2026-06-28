-- =====================================================
-- Простая оболочка для CC: Tweaked
-- Версия 6.0 (использует shell.run)
-- =====================================================

local term = term
local colors = colors
local fs = fs

-- Настройки
local prompt_symbol = ">"
local history = {}
local history_file = ".history"
local history_index = 0

-- Загрузка истории
local function load_history()
    if fs.exists(history_file) then
        local file = io.open(history_file, "r")
        if file then
            for line in file:lines() do
                table.insert(history, line)
            end
            file:close()
        end
    end
end

local function save_history()
    local file = io.open(history_file, "w")
    if file then
        for _, line in ipairs(history) do
            file:write(line .. "\n")
        end
        file:close()
    end
end

local function add_to_history(cmd)
    if cmd and cmd ~= "" then
        table.insert(history, cmd)
        save_history()
    end
end

-- Чтение строки с поддержкой истории
local function read_line()
    local line = ""
    history_index = #history + 1
    
    while true do
        term.setCursorPos(1, 1)
        term.clearLine()
        term.write(prompt_symbol .. " ")
        term.write(line)
        
        local event, key = os.pullEvent("key")
        
        if key == 28 then -- Enter
            term.write("\n")
            return line
        elseif key == 14 then -- Backspace
            if #line > 0 then
                line = string.sub(line, 1, -2)
            end
        elseif key == 200 then -- Up
            if history_index > 1 then
                history_index = history_index - 1
                line = history[history_index] or ""
            end
        elseif key == 208 then -- Down
            if history_index < #history then
                history_index = history_index + 1
                line = history[history_index] or ""
            else
                history_index = #history + 1
                line = ""
            end
        else
            if key >= 32 and key <= 126 then
                line = line .. string.char(key)
            end
        end
    end
end

-- ГЛАВНЫЙ ЦИКЛ
term.clear()
term.setCursorPos(1, 1)
load_history()

print(colors.green .. "Simple Shell v6.0 - Type 'exit' to quit" .. colors.white)

while true do
    term.write(colors.cyan .. "> " .. colors.white)
    local cmd = read_line()
    
    if cmd then
        add_to_history(cmd)
        
        if cmd == "exit" or cmd == "logout" then
            print("Goodbye!")
            break
        end
        
        -- ПРОСТО ЗАПУСКАЕМ КОМАНДУ
        local success, err = pcall(function()
            shell.run(cmd)
        end)
        
        if not success then
            print(colors.red .. "Error: " .. tostring(err) .. colors.white)
        end
    end
end
