local obsidian = vim.fs.find('.obsidian/', {
    upward = true,
    type = 'directory',
    path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
})

if next(obsidian) == nil then
    return
end

local obsidian_link_text = function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2] + 1
    local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
    for s, text, e in line:gmatch("()(%b[])()") do
        if s <= col and col <= e then
            return text:sub(3, -3)
        end
    end
    return nil
end

string.split_by_lines = function(text)
    local result = {}
    for line in text:gmatch("([^\n]+)\n?") do
        table.insert(result, line)
    end
    return result
end

local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local themes = require("telescope.themes")

local go_to_obsidian_link = function()
    local link_text = obsidian_link_text()
    if link_text == nil then
        print('no obsidian link found on current line')
        return
    end
    local search_results =
        vim.fn.system({ 'fdfind', link_text, '--type=file' }):split_by_lines()
    if #search_results == 0 then
        print('no file found matching that link')
        return
    elseif #search_results == 1 then
        vim.cmd('e ' .. search_results[1])
    else
        pickers.new({}, {
            prompt_title = "Select matching link",
            finder = finders.new_table(search_results),
            sorter = sorters.get_substr_matcher()
        }):find()
    end
end

vim.keymap.set(
    'n',
    'gd',
    go_to_obsidian_link,
    { noremap = true, buffer = true }
)

local insert_obsidian_link = function()
    local enter = function(prompt_bufnr)
        local selected = action_state.get_selected_entry()[1]
        local extracted = selected:gsub("[^/]*/", ""):gsub("%.md", "")
        local link = "[[".. extracted .. "]]"
        actions.close(prompt_bufnr)
        vim.api.nvim_put({ link }, "c", false, true)
        vim.cmd("normal i")
        vim.cmd([[call cursor(line('.'), col('.') + 1)]])
    end
    pickers.new(themes.get_cursor(), {
        prompt_title = "Select the file to insert a link to.",
        finder = finders.new_oneshot_job({ "fdfind", "--type=file" }, {}),
        sorter = sorters.get_fuzzy_file {},
        attach_mappings = function(_, map)
            map("i", "<cr>", enter)
            map("n", "<cr>", enter)
            return true
        end,
    }):find()
end

vim.keymap.set(
    'i',
    '<c-x><c-f>',
    insert_obsidian_link,
    { noremap = true, buffer = true }
)
