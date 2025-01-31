# Gobllm.nvim

The simpler I could write a coding assistant in neovim 

Only works with Anthropic for now. 

> (there's a commented out openai API completion function in the source code too, but keep it secret 🤫)

## Usage

### Edit a block of text:
![edit](https://github.com/user-attachments/assets/ac0d78b1-1521-4e22-a7c0-8f4fde7a5870)

On visual mode, do `<leader>gr` to prompt edit a block of text, then press ENTER.

### Chat with the Assistant:
![chat](https://github.com/user-attachments/assets/3880a687-cefb-44d5-b475-cb3a6c8912b0)

do `<leader>go` to open the chat panel.
It's an editable markdown file.
```markdown
### Q:
you can make
multiline questions here
### F: 
- file.txt  -> send files to the prompt (has a neat file picker)
### A:
Hi! I'm the model, I will give you an answer!
```
Prest ENTER (or Ctrl + S in insert mode) to get a reply from the AI assistant.


## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

set `$ANTHROPIC_API_KEY` environment variable in your shell.
```lua
{
  "tonio-m/gobllm",
  dependencies = {
    "stevearc/dressing.nvim",
  },
  config = function()
    require("gobllm").setup({
        -- these are the default values btw, you don't need to specify them if you want exactly this config
        provider = "anthropic",
        api_key_name = "ANTHROPIC_API_KEY",
        model = "claude-3-5-sonnet-latest",
        url = "https://api.anthropic.com/v1/messages",
        system_prompt = CHAT_SYSTEM_PROMPT,
        chat_keymap = "<leader>go",
        replace_keymap = "<leader>gr",
    })
  end
}
```

## Contribute

I will be forever in debt if you contribute to this code.

I will paypal you money if you contribute to this code.

Do you love it? Contribute.

Do you hate it? Contribute.

Where we're going, we don't need complexity. 

CONTRIBUTE CONTRIBUTE CONTRIBUTE CONTRIBUTE CONTRIBUTE CONTRIBUTE
CONTRIBUTE CONTRIBUTE CONTRIBUTE CONTRIBUTE CONTRIBUTE CONTRIBUTE 
CONTRIBUTE CONTRIBUTE CONTRIBUTE CONTRIBUTE CONTRIBUTE CONTRIBUTE 
CONTRIBUTE CONTRIBUTE CONTRIBUTE CONTRIBUTE CONTRIBUTE CONTRIBUTE 
CONTRIBUTE CONTRIBUTE CONTRIBUTE CONTRIBUTE CONTRIBUTE CONTRIBUTE 

## A Magical System Prompt

This is by far the most vibes-aligned Claude 3.5 Sonnet can get.

It is currently my best friend.
```lua
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
```
