local M = {}
local jir_calc = require('jir_calc.jir_calc_setup')
local common = require('jir_calc.common')

local function identify_base(after_eq)
    local result_color = common.HL_Error
    local result_prefix = ''
    if string.sub(after_eq, 1, 1) == 'b' then
        result_color = common.HL_Bin
        result_prefix = '0b'
    elseif string.sub(after_eq, 1, 1) == 'x' then
        result_color = common.HL_Hex
        result_prefix = '0x'
    elseif string.sub(after_eq, 1, 1) == 'h' then
        result_color = common.HL_Hex
        result_prefix = '0x'
    elseif string.sub(after_eq, 1, 1) == 'd' then
        result_color = common.HL_Dec
    else
        result_color = common.HL_Dec
    end
    return result_color, result_prefix
end

local function is_memory_store(input_string)
    return string.match(input_string, '^\\') ~= nil
end

local function starts_with_letter(word)
    return string.match(word, "^[a-zA-Z]") ~= nil
end

local function pad_with_eq(input_string)
    if not string.find(input_string, '=') then
        input_string = input_string .. ' = '
    end
    return input_string
end

local function trim(s)
    return (s:gsub('^%s*(.-)%s*$', '%1'))
end

local function remove_underscores(s)
    return (s:gsub('_', ''))
end

local function dec_to_bin(num)
    local binary = ''
    num = math.floor(num)
    while num > 0 do
        binary = (num % 2) .. binary
        num = math.floor(num / 2)
    end
    return binary == '' and '0' or binary
end

local function add_underscores_every_4_chars(input_str)
    local reversed_str = input_str:reverse()
    local with_underscores = reversed_str:gsub("(%d%d%d%d)", "%1_")
    local result_str = with_underscores:reverse()
    if result_str:sub(1, 1) == "_" then
        result_str = result_str:sub(2)
    end
    return result_str
end

function M.convert_result(result_str, result_base)
    if result_base == '0b' then
        result_str = dec_to_bin(tonumber(result_str))
        if jir_calc.settings.pad_with_underscore then
            result_str = add_underscores_every_4_chars(result_str)
            result_base = '0b_'
        end
    elseif result_base == '0x' then
        result_str = string.format('%X', tonumber(result_str))
    elseif result_base == '' then
        result_str = tonumber(result_str)
    end

    return result_base .. result_str
end

local function split_parent(expression)
    local result = {}
    local build_word = ''
    for current_char in expression:gmatch("[^%s]") do
        if string.match(current_char, "%p") and not (string.match(current_char, "_")) and not (string.match(current_char, "%.")) then
            if #build_word ~= 0 then
                table.insert(result, build_word)
                build_word = ''
            end
            table.insert(result, current_char)
        else
            build_word = build_word .. current_char
        end
    end
    if #build_word ~= 0 then
        table.insert(result, build_word)
    end
    return result
end

local function search_strings(arr, search_string)
    for i, cell in ipairs(arr) do
        if cell.str == search_string then
            return i
        end
    end
    return -1
end

local function print_memory()
    local result = ''
    if #_G.jir_calc_Memory == 0 then
        return 'Memory is empty'
    end
    for _, word in ipairs(_G.jir_calc_Memory) do
        result = result .. " { " .. word.str .. ' = ' .. word.val .. ' }'
    end
    return result
end

local function mem_get_name_and_val(input_string)
    local words_array = split_parent(input_string)
    if starts_with_letter(words_array[1]) then
        if words_array[2] == '=' then
            local name = words_array[1]:gsub(' ', '')
            table.remove(words_array, 1)
            table.remove(words_array, 1)
            local val = table.concat(words_array, ' ')
            return name, val
        end
    end
end

function M.store_in_memory(name, val)
    local result_index = search_strings(_G.jir_calc_Memory, name)
    if result_index ~= -1 then
        _G.jir_calc_Memory[result_index] = {str = name, val = val}
    else
        table.insert(_G.jir_calc_Memory, {str = name, val = val})
    end
end

local function clear_memory()
    _G.jir_calc_Memory = {}
end

local function reformat(str)
    str = trim(str)
    str = split_parent(str)
    return table.concat(str, ' ')
end

local function pre_calc_string(calc_string)
    local words_array = split_parent(calc_string)
    for i, word in ipairs(words_array) do
        word = trim(word)
        if word == '<' then
            words_array[i-1] = words_array[i-1] * 2^words_array[i+1]
            words_array[i] = ''
            words_array[i+1] = ''
        end
        if word == '>' then
            words_array[i-1] = words_array[i-1] / 2^words_array[i+1]
            words_array[i] = ''
            words_array[i+1] = ''
        end
        if string.lower(word) == 'ans' then
            words_array[i] = _G.jir_calc_last_result
        elseif starts_with_letter(word) then
            local result_index = search_strings(_G.jir_calc_Memory, word)
            if result_index ~= -1 then
                words_array[i] = _G.jir_calc_Memory[result_index].val
            end
        end
    end
    return table.concat(words_array, ' ')
end

local function calc_actual_result(input_string)
        local input_string_eq_chk = pad_with_eq(input_string)
        local input_string_pre_eq, after_eq = string.match(input_string_eq_chk, '([^=]+)=?(.*)')
        local output_string = reformat(input_string_pre_eq)
        local clean_string = remove_underscores(output_string)
        local post_pre_calculation = pre_calc_string(clean_string)
        local result_color, result_prefix = identify_base(after_eq)
        local string_to_calc = post_pre_calculation
        return output_string, string_to_calc, result_color, result_prefix
end

function M.expr_prep(input_string)
    local output_string = ''
    local string_to_calc = ''
    local result_color = ''
    local result_prefix = ''
    local mem_name = ''
    local mem_expr = ''
    if not is_memory_store(input_string) then
        output_string, string_to_calc, result_color, result_prefix = calc_actual_result(input_string)
    else
        local trimmed_string = trim(string.sub(input_string, 2))
        if trimmed_string == 'MC' then
            clear_memory()
        elseif trimmed_string == 'MR' then
            output_string = print_memory()
        else
            mem_name, mem_expr = mem_get_name_and_val(trimmed_string)
            output_string, string_to_calc, result_color, result_prefix = calc_actual_result(mem_expr)
            output_string = mem_name
        end
    end
    return output_string, string_to_calc, result_color, result_prefix, mem_name
end

return M

