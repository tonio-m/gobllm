local M = {}
local vim = vim or {}
local curl = require('plenary.curl')

local CHAT_SYSTEM_PROMPT = [[
You are a helpful, knowledgeable assistant focused on supporting users with any task or question. 

Key guidelines:
- Provide clear, direct answers without unnecessary caveats
- Break down complex problems step by step
- Be concise for simple questions, thorough for complex ones
- Use appropriate formatting (bullet points, numbered lists, etc.) for clarity 
- Include relevant examples when helpful
- State limitations of knowledge when applicable
- Ask clarifying questions only when truly needed
- Maintain a warm, professional tone without being overly casual

When handling requests:
1. First understand the core need/question
2. Consider the most effective way to structure the response
3. Provide the answer/solution
4. Offer to elaborate only if additional detail would be genuinely helpful

Your responses should be practical and actionable while avoiding unnecessary length or repetition.
]]

local REPLACE_SYSTEM_PROMPT = [[
You're a specialized code completion assistant with expertise in all programming languages. 
When given a code block and modification instructions:
1. Output ONLY the modified code with proper indentation and spacing
2. Do not include backticks, comments about the changes, or any non-code text
3. Maintain the original code's language and style conventions
4. Preserve any language-specific formatting requirements
5. Handle any programming language without changing the input language
6. Do not add explanatory text before or after the code
7. Think through the changes step by step before outputting
8. Ensure the output is complete, accurate, and production-ready
]]

function M.setup(opts)
    M.config = {
        provider = "anthropic",
        api_key_name = "ANTHROPIC_API_KEY",
        model = "claude-3-5-sonnet-latest",
        url = "https://api.anthropic.com/v1/messages",
        system_prompt = CHAT_SYSTEM_PROMPT,
        chat_keymap = "<leader>go",
        replace_keymap = "<leader>gr",
    }
    if opts then
        for key, value in pairs(opts) do
            M.config[key] = value
        end
    end
    M.config.api_key = os.getenv(M.config.api_key_name)
    if not M.config.api_key then
        error(string.format("Missing API key: Please set the %s environment variable", M.config.api_key_name))
    end

    vim.keymap.set("n", chat_keymap, M.open_chat, {noremap = true, silent=false})
    vim.keymap.set("v", replace_keymap, M.replace, {noremap = true, silent=false})
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "gobllm",
      callback = function()
        vim.keymap.set('i', '-', function()
            local current_line = vim.fn.line('.')
            local lines = vim.api.nvim_buf_get_lines(0, 0, current_line, false)
            for i = #lines, 1, -1 do
                if lines[i]:match("^### F:%s*") then
                    return '<ESC>:lua pick_file(vim.fn.getcwd())<CR>'
                elseif lines[i]:match("^### %w+:%s*") then
                    return '-'
                end
            end
            return '-'
        end, { expr = true, buffer = true })
      end
    })
end

function split_into_lines(str)
    local lines = {}
    for line in str:gmatch("([^\r\n]*)\r?\n?") do
        table.insert(lines, line)
    end
    return lines
end

function read_file(filepath)

    local full_path
    if filepath:sub(1,1) == "/" then
        full_path = filepath
    else
        local current_dir = io.popen("pwd"):read("*l")
        full_path = current_dir .. "/" .. filepath
    end

    local file = io.open(full_path, "r")
    if not file then
        error("File not found: " .. full_path)
    end
    local content = file:read("*all")
    file:close()
    return content
end

function parse_blocks(text)
    local blocks= {}
    local cur_elem = ""
    local lines = split_into_lines(text)
    for i, line in ipairs(lines) do
        if (line:match("^### %a+:%s*") or i  == #lines) and i ~= 1 then
            table.insert(blocks,cur_elem)
            cur_elem = ""
        end
        cur_elem = cur_elem .. line .. "\n"
    end
    return blocks
end

function handle_file_block(block)
    lines = split_into_lines(block)
    file_paths = {}
    for _, line in ipairs(lines) do
        local item = line:match("^%s*-%s*(.+)")
        if item then
            table.insert(file_paths, item)
        end
    end

    content = {}
    for _, path in ipairs(file_paths) do
        file_content = read_file(path)
        table.insert(content, {type = "text", text = file_content})
    end

    return {role = "user", content = content}
end

function chat_to_messages(buffer_str)
    local handlers = {
        F = handle_file_block,
        Q = function (block)
            return {role = "user", content = block }
        end,
        A = function (block)
            return {role = "assistant", content = block}
        end,
    }
    local blocks = parse_blocks(buffer_str)
    local messages = {}
    for index,block in ipairs(blocks) do
        local lines = split_into_lines(block)
        local content_type = lines[1]:match("^### (%a+):")
        local content = table.concat(table.move(lines, 2, #lines, 1, {}), "\n")
        local message = handlers[content_type](content)
        table.insert(messages, message)
    end
    return messages
end

function pick_file(dir)
    local function format_item(item)
      if vim.fn.isdirectory(dir .. '/' .. item) == 1 then
        return item .. "/"
      end
      return item
    end

  local function on_choice(choice)
    local path = dir == '/' and dir .. choice or dir .. '/' .. choice
    if vim.fn.isdirectory(path) == 1 then
      pick_file(path)
    else
      -- Insert the path at current_line
    local current_line = vim.fn.line('.')
    vim.api.nvim_buf_set_lines(0, current_line - 1, current_line, false, {"- " .. path})

    end
  end

  local items = vim.fn.readdir(dir)
  vim.ui.select(items, { prompt = "Select file or directory:", format_item = format_item, }, on_choice)
end

function completion_request_openai(messages,system_prompt,config)
    table.insert(messages, 1, {
        role = "system",
        content = system_prompt
    })
    local response = curl.post(config.url, {
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. config.api_key,
        },
        body = vim.fn.json_encode({
            model = config.model,
            messages = messages,
        }),
        timeout = 60000
    })

    if response.status ~= 200 then
        vim.notify("HTTP ERROR:" .. response.status)
        vim.notify(response.body)
        error("Failed to get a valid response from the API")
    end
    local answer = vim.fn.json_decode(response.body).choices[1].message.content
    return answer
end

function completion_request_anthropic(messages,system_prompt,config)
    local response = curl.post(config.url, {
        headers = {
            ["Content-Type"] = "application/json",
            ["anthropic-version"] = "2023-06-01",
            ["x-api-key"] = config.api_key,
        },
        body = vim.fn.json_encode({
            system = system_prompt,
            messages = messages,
            model = config.model,
            max_tokens = 4000,
        }),
        timeout = 60000
    })
    if response.status ~= 200 then
        vim.notify("HTTP ERROR:" .. response.status)
        vim.notify(response.body)
        error("Failed to get a valid response from the API")
    end
    local answer = vim.fn.json_decode(response.body).content[1].text
    return answer
end

function completion_request(messages, system_prompt)
    if M.config.provider == "openai" then
        return completion_request_openai(messages, system_prompt,M.config)
    elseif M.config.provider == "anthropic" then
        return completion_request_anthropic(messages, system_prompt,M.config)
    else
        error("Invalid provider specified. Must be 'openai' or 'anthropic'")
    end
end

function M.replace()
    local current_buffer = vim.fn.bufnr('%')
    local buffer_str = table.concat(vim.api.nvim_buf_get_lines(current_buffer, 0, -1, false),"\n")

    -- Using vim.ui.input instead of vim.fn.input
    vim.ui.input({
        prompt = "task: ",
    }, function(task)
        if task == nil or task == "" then -- Check if user cancelled or input is empty
            print("Operation cancelled")
            return
        end

        local start_line = vim.fn.line("'<")
        local end_line = vim.fn.line("'>")
        -- Iterate over the selected range
        local lines = {}
        for line = start_line, end_line do
            local text = vim.fn.getline(line)
            table.insert(lines,text)
        end
        local code_block = table.concat(lines,"\n")
        -- TODO: I think there might be a better way to pass the entire file context, but this works for now
        local messages = {
            {role = "user", content = "for context, this is the entire file: \n```\n" .. buffer_str .. "\n```"},
            {role = "user", content = "this is the code you need to replace: \n```\n" .. code_block .. "\n```\n\n" .. task}
        }
        local completion = completion_request(messages,REPLACE_SYSTEM_PROMPT)

        -- set the lines to be those of completion
        local current_buffer = vim.fn.bufnr('%')
        vim.api.nvim_buf_set_lines(current_buffer, start_line - 1, end_line, false, split_into_lines(completion))
    end)
end

function M.open_chat()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "gobllm",
    callback = function()
        vim.api.nvim_buf_set_keymap(0, 'n', '<CR>', ":lua require('gobllm').chat_complete()<CR>", { noremap = true, silent = true })
        vim.api.nvim_buf_set_keymap(0, 'n', '<C-s>', ":lua require('gobllm').chat_complete()<CR>", { noremap = true, silent = true })
    end
  })
  vim.cmd("enew")
  vim.cmd("set filetype=gobllm")
  vim.cmd("set syntax=markdown")
  vim.api.nvim_buf_set_lines(0, 0, 0, false, { "### Q:" })
  vim.api.nvim_buf_set_option(0, "buftype", "nofile")
end

function M.chat_complete()
    local current_buffer = vim.fn.bufnr('%')
    local buffer_str = table.concat(vim.api.nvim_buf_get_lines(current_buffer, 0, -1, false),"\n")
    local messages = chat_to_messages(buffer_str)
    local answer = completion_request(messages,M.config.system_prompt)
    local line_count = vim.api.nvim_buf_line_count(current_buffer)
    vim.api.nvim_buf_set_lines(current_buffer, line_count, line_count, false, split_into_lines("### A:\n" .. answer .. "\n### Q:"))
    -- go to last line of the buffer
    vim.api.nvim_win_set_cursor(0, {vim.api.nvim_buf_line_count(0), 0})
end

return M
