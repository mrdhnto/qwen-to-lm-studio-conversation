# LM Studio Chat Importer

A simple PowerShell script to convert exported chat conversations from **Qwen** (Tongyi Qianwen) into the **LM Studio** chat format. This allows you to import your Qwen history into LM Studio and continue conversations locally.

## Features
- **Create Mode**: Generate a brand new `.json` conversation file for LM Studio.
- **Merge Mode**: Append messages from a Qwen export to an existing LM Studio conversation.
- **Text-Only Filtering**: Optionally filter out non-answer phases (like "web_search" or "thinking") to keep the chat clean.
- **Deep Formatting**: Correctly handles multi-step assistant responses and user message versions.

## Prerequisites
- **PowerShell 7+ (pwsh)** is recommended for best JSON handling.
- A exported `.json` file from Qwen.
- (Optional) An existing LM Studio conversation file if you wish to merge.

## Usage

### 1. Create a New Conversation
To create a new LM Studio chat file from your Qwen export:
```powershell
.\import-qwen.ps1 -Type create -InputPath "path/to/qwen-chat.json" -OutputPath "path/to/lm-studio-chat.json"
```

### 2. Merge Into Existing Conversation
To add messages from Qwen to an existing LM Studio chat:
```powershell
.\lm-studio-chat-importer.ps1 -Type merge -InputPath "path/to/qwen-chat.json" -InputMergePath "path/to/existing-lm-chat.json" -OutputPath "path/to/final-merged-chat.json"
```

### 3. Filter for Clean Text Only
If you want to remove "Web Search" logs and only keep the final AI answers:
```powershell
.\lm-studio-chat-importer.ps1 -Type create -InputPath "qwen-export.json" -OutputPath "clean-lm-chat.json" -TextOnly $true
```

## Parameters

| Parameter | Type | Required | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-Source` | string | No | `Qwen` | The AI chat source (Qwen, Claude, ChatGPT, Z.ai, DeepSeek). |
| `-Type` | string | No | `create` | Either `create` or `merge`. |
| `-InputPath` | string | Yes | - | Path to the exported Qwen JSON file. |
| `-InputMergePath` | string | No* | - | Path to the existing LM Studio file (Required for `merge`). |
| `-OutputPath` | string | Yes | - | Path where the converted JSON will be saved. |
| `-TextOnly` | bool | No | `$false` | If `$true`, truncates non-answer phases (web search, think, etc). |

## Supported Sources
- **Qwen**: Fully supported (extracts answers and web search logs).
- **Claude / ChatGPT / Z.ai / DeepSeek / Others**: Structure ready, but the site not yet supporting Export conversation.

## How to use results in LM Studio
1. Locate your LM Studio "Local Conversations" folder (standard location is usually in `%UserProfile%\.lmstudio\conversations`).
2. Copy your generated `.json` file into that folder.
3. Restart LM Studio or refresh your chat history.

## Development
- `lm-studio-chat-importer.ps1`: Core PowerShell conversion logic.
- `qwen-chat-export.json`: Reference Qwen format.
- `lm_studio.conversation.json`: Reference LM Studio format.
