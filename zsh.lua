-- =====================================================
-- ZSH-подобная оболочка для CC: Tweaked
-- Версия 2.0 (исправленная)
-- =====================================================

-- Глобальные API (доступны всегда)
local fs = fs or require("filesystem")
local term = term or require("term")
local os = os or require("os")
local colors = colors or require("colors")
local textutils = textutils or require("textutils")
local shell = shell or require("shell")

-- =====================================================
-- НАСТРОЙКИ
-- =====================================================
local config = {
    prompt_color = colors.lime,
    prompt_symbol = "❯",
    show_git_status = false,  -- Отключено для скорости
    history_file = ".zsh_history",
    max_history = 100,
    aliases = {
        ["ll"] = "ls -l",
        ["la"] = "ls -a",
        [".."] = "cd ..",
        ["..."] = "cd ../..",
        ["grep"] = "find",
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
local current_dir = os.getenv("PWD") or "/"
local previous_dir = nil

-- =====================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- =====================================================

-- Чтение истории из файла
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

-- Сохранение истории в файл
local function save_history()
    local file = io.open(config.history_file, "w")
    if file then
        for i = #history - math.min(#history, config.max_history) + 1, #history do
            file:write(history[i] .. "\n")
        end
        file:close()
    end
end

-- Добавление команды в историю
local function add_to_history(cmd)
    if cmd and cmd ~= "" then
        table.insert(history, cmd)
        save_history()
    end
end

-- Поиск команд в PATH
local function find_command(cmd)
    -- Проверяем встроенные команды
    local builtins_list = {"cd", "ls", "pwd", "echo", "cat", "clear", "help", 
                           "alias", "unalias", "history", "export", "unset"}
    for _, b in ipairs(builtins_list) do
        if b == cmd then
            return "builtin"
        end
    end
    
    -- Проверка внешних программ
    local paths = {
        "",
        "/rom/programs/",
        "/rom/programs/",
        "/rom/programs/",
        "/rom/programs/"
    }
    
    for _, path in ipairs(paths) do
        local full_path = fs.combine(path, cmd)
        if fs.exists(full_path) and not fs.isDirectory(full_path) then
            return full_path
        end
    end
    
    return nil
end

-- Автодополнение
local function complete_command(partial)
    local matches = {}
    local partial_lower = partial:lower()
    
    -- Поиск встроенных команд
    local builtins_list = {"cd", "ls", "pwd", "echo", "cat", "clear", "help", 
                           "alias", "unalias", "history", "export", "unset"}
    for _, cmd in ipairs(builtins_list) do
        if cmd:sub(1, #partial_lower):lower() == partial_lower then
            table.insert(matches, cmd)
        end
    end
    
    -- Поиск файлов в текущей директории
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
    
    -- Поиск программ в /rom/programs
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
    
    previous_dir = current_dir
    
    if fs.exists(target) and fs.isDirectory(target) then
        current_dir = fs.canonical(target)
        os.setenv("PWD", current_dir)
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
    -- Обработка переменных $VAR
    output = output:gsub("%$([%w_]+)", function(var)
        return os.getenv(var) or "$" .. var
    end)
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
    print(colors.cyan .. "=== ZSH для CC: Tweaked ===" .. colors.white)
    print("")
    print(colors.yellow .. "Встроенные команды:" .. colors.white)
    print("  cd [dir]     - Перейти в директорию")
    print("  ls [-a] [-l] - Показать содержимое")
    print("  pwd          - Показать текущую директорию")
    print("  echo [text]  - Вывести текст")
    print("  cat [file]   - Показать содержимое файла")
    print("  clear/cls    - Очистить экран")
    print("  help         - Показать эту справку")
    print("  alias [name] [cmd] - Создать алиас")
    print("  unalias [name] - Удалить алиас")
    print("  history      - Показать историю команд")
    print("  export NAME=value - Установить переменную")
    print("  unset NAME   - Удалить переменную")
    print("")
    print(colors.yellow .. "Особенности:" .. colors.white)
    print("  • Автодополнение по Tab")
    print("  • История команд (↑/↓)")
    print("  • Алиасы (см. config.aliases)")
    print("  • Переменные окружения")
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
        print("Алиас создан: " .. name .. " -> " .. cmd)
    else
        if config.aliases[name] then
            print(name .. " = '" .. config.aliases[name] .. "'")
        else
            print("Алиас не найден: " .. name)
        end
    end
    return true
end

function builtins.unalias(args)
    if #args == 0 then
        print("Использование: unalias [name]")
        return false
    end
    
    local name = args[1]
    if config.aliases[name] then
        config.aliases[name] = nil
        print("Алиас удалён: " .. name)
    else
        print("Алиас не найден: " .. name)
    end
    return true
end

function builtins.history()
    for i = math.max(1, #history - 20), #history do
        print(string.format("%5d  %s", i, history[i]))
    end
    return true
end

function builtins.export(args)
    for _, arg in ipairs(args) do
        local name, value = arg:match("^([%w_]+)=(.+)$")
        if name then
            os.setenv(name, value)
            print("Переменная установлена: " .. name .. "=" .. value)
        else
            print(colors.red .. "export: неправильный формат. Используйте NAME=value" .. colors.white)
        end
    end
    return true
end

function builtins.unset(args)
    for _, name in ipairs(args) do
        os.setenv(name, nil)
        print("Переменная удалена: " .. name)
    end
    return true
end

-- =====================================================
-- ГЛАВНЫЙ ЦИКЛ ОБОЛОЧКИ
-- =====================================================

local function get_prompt()
    local dir_name = fs.getName(current_dir)
    if dir_name == "" then dir_name = "/" end
    
    return string.format(
        "%s[%s%s%s] %s%s ",
        colors.cyan,
        colors.green,
        dir_name,
        colors.cyan,
        colors.white,
        config.prompt_symbol
    )
end

local function execute_command(cmd)
    if cmd == "" then return true end
    
    -- Проверка на алиас
    local parts = {}
    for part in cmd:gmatch("%S+") do
        table.insert(parts, part)
    end
    
    local command = parts[1]
    local args = {table.unpack(parts, 2)}
    
    -- Замена алиаса
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
    
    -- Проверка встроенных команд
    if builtins[command] then
        return builtins[command](args)
    end
    
    -- Попытка запустить внешнюю программу
    local program_path = find_command(command)
    if program_path and program_path ~= "builtin" then
        -- Запуск программы с аргументами
        local cmd_str = command .. " " .. table.concat(args, " ")
        local result = os.execute(cmd_str)
        return result == 0 or result == true
    else
        print(colors.red .. "zsh: command not found: " .. command .. colors.white)
        return false
    end
end

-- Загрузка истории
load_history()

-- =====================================================
-- ВВОД С АВТОДОПОЛНЕНИЕМ И ИСТОРИЕЙ
-- =====================================================

local function read_line_with_features()
    local line = ""
    local history_pos = #history + 1
    local completion_matches = {}
    local completion_index = 0
    
    while true do
        -- Показываем промпт
        term.setCursorPos(1, 1)
        term.clearLine()
        term.write(get_prompt())
        term.write(line)
        
        local char = term.read()
        
        if char == "\n" or char == "\r" then
            term.write("\n")
            return line
        elseif char == "\t" then -- Tab - автодополнение
            if #line > 0 then
                local partial = line
                if #completion_matches > 0 and completion_index <= #completion_matches then
                    completion_index = completion_index + 1
                    if completion_index > #completion_matches then
                        completion_index = 1
                        completion_matches = complete_command(partial)
                    end
                    line = completion_matches[completion_index] or partial
                else
                    completion_matches = complete_command(partial)
                    completion_index = 1
                    if #completion_matches > 0 then
                        line = completion_matches[1]
                    end
                end
            end
        elseif char == "\127" then -- Backspace
            if #line > 0 then
                line = line:sub(1, -2)
            end
        elseif char == "\27" then -- Escape sequence
            local seq = term.read() .. term.read()
            if seq == "[A" then -- Up arrow
                if history_pos > 1 then
                    history_pos = history_pos - 1
                    line = history[history_pos] or ""
                end
            elseif seq == "[B" then -- Down arrow
                if history_pos < #history then
                    history_pos = history_pos + 1
                    line = history[history_pos] or ""
                else
                    history_pos = #history + 1
                    line = ""
                end
            end
        else
            line = line .. char
        end
    end
end

local running = true
while running do
    local cmd = read_line_with_features()
    
    if cmd then
        add_to_history(cmd)
        if cmd == "exit" or cmd == "logout" then
            running = false
            print("Выход из оболочки...")
        else
            execute_command(cmd)
        end
    end
end
