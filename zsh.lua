-- =====================================================
-- ZSH-подобная оболочка для CC: Tweaked
-- Версия 4.0 (ASCII, правильный ввод)
-- =====================================================

local fs = fs
local term = term
local os = os
local colors = colors
local textutils = textutils
local io = io

-- =====================================================
-- НАСТРОЙКИ
-- =====================================================
local config = {
    prompt_symbol = ">",
    history_file = ".zsh_history",
    max_history = 100,
    aliases = {
        ["ll"] = "ls -l",
        ["la"] = "ls -a",
        [".."] = "cd ..",
        ["..."] = "cd ../..",
        ["cls"] = "clear",
        ["edit"] = "edit",
        ["reboot"] = "reboot",
        ["shutdown"] = "shutdown"
    }
}

-- =====================================================
-- ОСНОВНЫЕ ПЕРЕМЕННЫЕ
-- =====================================================
local history = {}
local current_dir = "/"
local previous_dir = nil
local history_index = 0

-- =====================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- =====================================================

local function load_history()
    if fs.exists(config.history_file) then
        local file = io.open(config.history_file, "r")
        if file then
            for line in file:lines() do
                if #history < config.max_history then
                    table.insert(history, line)
                end
            end
            file:close()
        end
    end
end

local function save_history()
    local file = io.open(config.history_file, "w")
    if file then
        local start = math.max(1, #history - config.max_history + 1)
        for i = start, #history do
            file:write(history[i] .. "\n")
        end
        file:close()
    end
end

local function add_to_history(cmd)
    if cmd and cmd ~= "" then
        table.insert(history, cmd)
        if #history > config.max_history then
            table.remove(history, 1)
        end
        save_history()
    end
end

local function find_command(cmd)
    local builtins_list = {"cd", "ls", "pwd", "echo", "cat", "clear", "help", 
                           "alias", "unalias", "history", "export", "unset"}
    for _, b in ipairs(builtins_list) do
        if b == cmd then
            return "builtin"
        end
    end
    
    -- Текущая директория
    local full_path = fs.combine(current_dir, cmd)
    if fs.exists(full_path) and not fs.isDirectory(full_path) then
        return full_path
    end
    
    -- /rom/programs
    if fs.exists("/rom/programs") then
        local prog_path = fs.combine("/rom/programs", cmd)
        if fs.exists(prog_path) and not fs.isDirectory(prog_path) then
            return prog_path
        end
    end
    
    return nil
end

local function complete_command(partial)
    local matches = {}
    local partial_lower = partial:lower()
    
    local builtins_list = {"cd", "ls", "pwd", "echo", "cat", "clear", "help", 
                           "alias", "unalias", "history", "export", "unset"}
    for _, cmd in ipairs(builtins_list) do
        if cmd:sub(1, #partial_lower):lower() == partial_lower then
            table.insert(matches, cmd)
        end
    end
    
    if fs.exists(current_dir) then
        for file in fs.list(current_dir) do
            if file:lower():sub(1, #partial_lower) == partial_lower then
                local full_path = fs.combine(current_dir, file)
                if fs.isDirectory(full_path) then
                    table.insert(matches, file .. "/")
                else
                    table.insert(matches, file)
                end
            end
        end
    end
    
    if fs.exists("/rom/programs") then
        for file in fs.list("/rom/programs") do
            if file:lower():sub(1, #partial_lower) == partial_lower then
                table.insert(matches, file)
            end
        end
    end
    
    return matches
end

-- =====================================================
-- ВСТРОЕННЫЕ КОМАНДЫ
-- =====================================================

local builtins = {}

function builtins.cd(args)
    local target = args[1] or "/"
    if target == "~" then target = "/" end
    if target == "-" then
        target = previous_dir or "/"
    end
    
    if fs.exists(target) and fs.isDirectory(target) then
        previous_dir = current_dir
        current_dir = fs.canonical(target)
        return true
    else
        print(colors.red .. "cd: " .. target .. ": No such directory" .. colors.white)
        return false
    end
end

function builtins.ls(args)
    local show_all = false
    local long_format = false
    local target = current_dir
    
    for _, arg in ipairs(args) do
        if arg == "-a" then show_all = true
        elseif arg == "-l" then long_format = true
        elseif arg:sub(1, 1) ~= "-" then
            target = fs.combine(current_dir, arg)
        end
    end
    
    if not fs.exists(target) then
        print(colors.red .. "ls: " .. target .. ": No such file or directory" .. colors.white)
        return false
    end
    
    if not fs.isDirectory(target) then
        print(fs.getName(target))
        return true
    end
    
    local items = {}
    for file in fs.list(target) do
        if show_all or file:sub(1, 1) ~= "." then
            table.insert(items, file)
        end
    end
    
    table.sort(items)
    
    if long_format then
        for _, file in ipairs(items) do
            local full_path = fs.combine(target, file)
            local is_dir = fs.isDirectory(full_path)
            local size = fs.getSize(full_path) or 0
            local color = is_dir and colors.blue or colors.white
            local icon = is_dir and "/" or ""
            print(string.format("%s%s%-20s%s %8d", color, file .. icon, "", colors.white, size))
        end
    else
        local line = ""
        for i, file in ipairs(items) do
            local full_path = fs.combine(target, file)
            local is_dir = fs.isDirectory(full_path)
            local color = is_dir and colors.blue or colors.white
            local icon = is_dir and "/" or ""
            line = line .. color .. file .. icon .. colors.white
            if i % 5 == 0 then line = line .. "\n" else line = line .. "  " end
        end
        print(line)
    end
    
    return true
end

function builtins.pwd()
    print(current_dir)
    return true
end

function builtins.echo(args)
    local output = table.concat(args, " ")
    print(output)
    return true
end

function builtins.cat(args)
    for _, file in ipairs(args) do
        local path = fs.combine(current_dir, file)
        if fs.exists(path) and not fs.isDirectory(path) then
            local f = io.open(path, "r")
            if f then
                print(f:read("*a"))
                f:close()
            end
        else
            print(colors.red .. "cat: " .. file .. ": No such file" .. colors.white)
        end
    end
    return true
end

function builtins.clear()
    term.clear()
    term.setCursorPos(1, 1)
    return true
end

function builtins.help()
    print(colors.cyan .. "=== ZSH Shell for CC: Tweaked ===" .. colors.white)
    print("")
    print(colors.yellow .. "Built-in commands:" .. colors.white)
    print("  cd [dir]     - Change directory")
    print("  ls [-a] [-l] - List directory contents")
    print("  pwd          - Print working directory")
    print("  echo [text]  - Print text")
    print("  cat [file]   - Print file contents")
    print("  clear        - Clear screen")
    print("  help         - Show this help")
    print("  alias [name] [cmd] - Create alias")
    print("  unalias [name] - Remove alias")
    print("  history      - Show command history")
    print("  export NAME=value - Set environment variable")
    print("  unset NAME   - Unset environment variable")
    print("")
    print(colors.yellow .. "Features:" .. colors.white)
    print("  * Tab completion")
    print("  * Command history (Up/Down arrows)")
    print("  * Aliases")
    print("  * Environment variables")
    return true
end

function builtins.alias(args)
    if #args == 0 then
        for name, cmd in pairs(config.aliases) do
            print(string.format("%s = '%s'", name, cmd))
        end
        return true
    end
    
    local name = args[1]
    local cmd = table.concat(args, " ", 2)
    if cmd ~= "" then
        config.aliases[name] = cmd
        print("Alias created: " .. name .. " -> " .. cmd)
    else
        if config.aliases[name] then
            print(name .. " = '" .. config.aliases[name] .. "'")
        else
            print("Alias not found: " .. name)
        end
    end
    return true
end

function builtins.unalias(args)
    if #args == 0 then
        print("Usage: unalias [name]")
        return false
    end
    
    local name = args[1]
    if config.aliases[name] then
        config.aliases[name] = nil
        print("Alias removed: " .. name)
    else
        print("Alias not found: " .. name)
    end
    return true
end

function builtins.history()
    local start = math.max(1, #history - 20)
    for i = start, #history do
        print(string.format("%5d  %s", i, history[i]))
    end
    return true
end

function builtins.export(args)
    for _, arg in ipairs(args) do
        local name, value = arg:match("^([%w_]+)=(.+)$")
        if name then
            os.setenv(name, value)
            print("Variable set: " .. name .. "=" .. value)
        else
            print(colors.red .. "export: invalid format. Use NAME=value" .. colors.white)
        end
    end
    return true
end

function builtins.unset(args)
    for _, name in ipairs(args) do
        os.setenv(name, nil)
        print("Variable unset: " .. name)
    end
    return true
end

-- =====================================================
-- ВВОД СТРОКИ
-- =====================================================

local function read_line()
    local line = ""
    local cursor = 1
    history_index = #history + 1
    
    while true do
        term.setCursorPos(1, 1)
        term.clearLine()
        term.write(config.prompt_symbol .. " ")
        term.write(line)
        
        local event, key, arg = os.pullEvent("key")
        
        if key == 28 then -- Enter
            term.write("\n")
            return line
        elseif key == 14 then -- Backspace
            if #line > 0 then
                line = line:sub(1, -2)
            end
        elseif key == 15 then -- Tab
            if #line > 0 then
                local matches = complete_command(line)
                if #matches > 0 then
                    line = matches[1]
                end
            end
        elseif key == 200 then -- Up arrow
            if history_index > 1 then
                history_index = history_index - 1
                line = history[history_index] or ""
            end
        elseif key == 208 then -- Down arrow
            if history_index < #history then
                history_index = history_index + 1
                line = history[history_index] or ""
            else
                history_index = #history + 1
                line = ""
            end
        elseif key == 203 then -- Left arrow
            -- Простая реализация, можно улучшить
        elseif key == 205 then -- Right arrow
            -- Простая реализация, можно улучшить
        else
            -- Печатаемые символы (ASCII)
            local char = string.char(key)
            if key >= 32 and key <= 126 then
                line = line .. char
            end
        end
    end
end

-- =====================================================
-- ОСНОВНОЙ ЦИКЛ
-- =====================================================

local function get_prompt()
    local dir_name = fs.getName(current_dir)
    if dir_name == "" then dir_name = "/" end
    
    return string.format(
        "%s[%s%s%s] ",
        colors.cyan,
        colors.green,
        dir_name,
        colors.cyan
    )
end

local function execute_command(cmd)
    if cmd == "" then return true end
    
    local parts = {}
    for part in cmd:gmatch("%S+") do
        table.insert(parts, part)
    end
    
    local command = parts[1]
    local args = {table.unpack(parts, 2)}
    
    if config.aliases[command] then
        local alias_cmd = config.aliases[command]
        local alias_parts = {}
        for part in alias_cmd:gmatch("%S+") do
            table.insert(alias_parts, part)
        end
        command = alias_parts[1]
        args = {table.unpack(alias_parts, 2)}
        for _, arg in ipairs(parts) do
            table.insert(args, arg)
        end
    end
    
    if builtins[command] then
        return builtins[command](args)
    end
    
    local program_path = find_command(command)
    if program_path and program_path ~= "builtin" then
        local full_cmd = program_path
        if #args > 0 then
            full_cmd = full_cmd .. " " .. table.concat(args, " ")
        end
        local result = os.execute(full_cmd)
        return result == 0 or result == true
    else
        print(colors.red .. "zsh: command not found: " .. command .. colors.white)
        return false
    end
end

-- =====================================================
-- ЗАПУСК
-- =====================================================

load_history()

print(colors.cyan .. "+===============================================+")
print("|     ZSH-like Shell for CC: Tweaked         |")
print("|          Version 4.0  |  Type 'help'        |")
print(colors.cyan .. "+===============================================+" .. colors.white)
print("")

local running = true
while running do
    term.write(get_prompt())
    local cmd = read_line()
    
    if cmd then
        add_to_history(cmd)
        if cmd == "exit" or cmd == "logout" then
            running = false
            print("Exiting shell...")
        else
            execute_command(cmd)
        end
    end
end
