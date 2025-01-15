local M = {}
local jir_calc = require('jir_calc.jir_calc_setup')
local expr_prep_module = require('jir_calc.expr_prep')
local common= require('jir_calc.common')

local function is_empty_or_spaces(str)
    return str:match('^%s*$') ~= nil
end

local function err_check_and_convert(err)
    if type(err) == "boolean" then
        return tostring(err)
    elseif err == nil then
        return "nil"
    else
        return "Value is neither boolean nor nil"
    end
end

local function handle_history(expr)
    local temp_expr = expr:sub(3) -- Strip the leading '> ' from the expression
    temp_expr = (temp_expr:gsub(' ', ''))
    if not is_empty_or_spaces(temp_expr) then
        local cmd_history = string.gsub(expr, "%s+$", "")
        table.insert(_G.jir_calc_cmd_history, cmd_history)
        _G.jir_calc_cmd_history_indx = 0
    end
end

local function evaluate_math_env(expression)
    local env = {
        math = math,
        abs   = math.abs,
        exp   = math.exp,
        log   = math.log,
        log10 = math.log10,
        sin   = math.sin,
        cos   = math.cos,
        tan   = math.tan,
        asin  = math.asin,
        sqrt  = math.sqrt,
        random = math.random,
        pi    = math.pi,
        log2 = function(x) return math.log(x) / math.log(2) end
    }
    return load('return ' .. expression, 'expression', 't', env)
end

local function print_to_calc(cmd_buf, main_win, output_string, output_string_w_results, result_color)
    local main_buf
    local line_count

    main_buf = vim.api.nvim_win_get_buf(main_win)
    line_count = vim.api.nvim_buf_line_count(main_buf)
    vim.api.nvim_buf_set_lines(main_buf, line_count, line_count, false, { output_string_w_results })
    vim.api.nvim_buf_add_highlight(main_buf, -1, result_color, line_count, #output_string + 3, #output_string_w_results)
    vim.api.nvim_win_set_cursor(main_win, { line_count + 1, 0 })

    table.insert(_G.jir_calc_result_history, output_string_w_results)

    -- Clear the command buffer and keep it in insert mode
    vim.api.nvim_buf_set_lines(cmd_buf, 0, -1, false, { '> ' })
    vim.api.nvim_command('startinsert')
    vim.api.nvim_win_set_cursor(0, { 1, 3 }) -- Position cursor after '> '
end

local function calculate(expr, cmd_buf, main_win, in_calc)
    local output_string = ''
    local processed_expr, result_color, result_base
    local mem_name = ''
    local output_string_w_results = ''
    local result_string = ''
    result_color = common.HL_Normal

    if is_empty_or_spaces(expr) then
        output_string_w_results = ' '
    else
        output_string, processed_expr, result_color, result_base, mem_name = expr_prep_module.expr_prep(expr)
--        vim.api.nvim_err_writeln("output_string: " .. output_string)
--        vim.api.nvim_err_writeln("processed_expr: " .. processed_expr)
--        vim.api.nvim_err_writeln("result_color: " .. result_color)
--        vim.api.nvim_err_writeln("result_base: " .. result_base)
--        vim.api.nvim_err_writeln("mem_name: " .. mem_name)
        local result_expr, err = evaluate_math_env(processed_expr)
        if processed_expr == '' then
            output_string_w_results = output_string
        elseif err then
            output_string_w_results = 'Loading Error: ' .. result_expr .. " \n" .. err_check_and_convert(err)
        else
            local success, value = pcall(result_expr)
            if success then
                result_string = expr_prep_module.convert_result(value, result_base)
                if jir_calc.settings.print_processed then
                    output_string_w_results = processed_expr .. ' = ' .. result_string
                else
                    output_string_w_results = output_string .. ' = ' .. result_string
                end
                if mem_name ~= '' then
                    expr_prep_module.store_in_memory(mem_name, result_string)
                end
                _G.jir_calc_last_result = result_string
            else
                output_string_w_results = 'Input: ' .. processed_expr .. ", Error: ".. err_check_and_convert(err)
                output_string = output_string_w_results
            end
        end
    end

    if in_calc then
        print_to_calc(cmd_buf, main_win, output_string, output_string_w_results, result_color)
    else
        return result_string
    end
end

function M.handle_command(main_win)
    local cmd_buf = vim.api.nvim_get_current_buf()
    local expr = vim.api.nvim_buf_get_lines(cmd_buf, 0, -1, false)[1]
    handle_history(expr)
    expr = expr:sub(3) -- Strip the leading '> ' from the expression
    calculate(expr, cmd_buf, main_win, true)
end

function M.windowless(visual_mode)
    local current_buf = vim.api.nvim_get_current_buf()
    local start_line
    local end_line
    local string_result = ''

    if visual_mode then
        start_line = vim.fn.line("v")
        end_line = vim.fn.line(".")
    else
        start_line = vim.fn.line(".")
        end_line = start_line
    end

    local lines = vim.api.nvim_buf_get_lines(current_buf, start_line - 1, end_line, false)
    for _, line in ipairs(lines) do
        if not is_empty_or_spaces(line) then
            string_result = calculate(line, nil, nil, false)
        end
    end

    vim.api.nvim_buf_set_lines(current_buf, end_line, end_line, false, { "Result: " .. string_result })
end

function M.debug()
    local start_line = vim.fn.line("v")
    local end_line = vim.fn.line(".")
    vim.api.nvim_err_writeln("start_line: " .. start_line .. " end_line: " .. end_line)
end

return M

