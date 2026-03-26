[CmdletBinding()]
Param(
    [ValidateSet('create', 'merge')]
    [string]$Type = 'create',
    
    [Parameter(Mandatory=$true)]
    [string]$InputPath,
    
    [string]$InputMergePath,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputPath,
    
    [bool]$TextOnly = $false,

    [ValidateSet('Qwen', 'Claude', 'ChatGPT', 'Z.ai', 'DeepSeek')]
    [string]$Source = 'Qwen'
)

if ($Type -eq 'merge' -and [string]::IsNullOrWhiteSpace($InputMergePath)) {
    Write-Error "-InputMergePath is required when -Type is 'merge'"
    exit 1
}

if (-not (Test-Path $InputPath)) {
    Write-Error "Input file not found at: $InputPath"
    exit 1
}

# Normalize OutputPath to always end with .conversation.json
if ($OutputPath -notlike "*.conversation.json") {
    if ($OutputPath -like "*.json") {
        $OutputPath = $OutputPath -replace "\.json$", ".conversation.json"
    } else {
        $OutputPath = "$OutputPath.conversation.json"
    }
}

# Read Input export
try {
    $inputContent = Get-Content -Path $InputPath -Raw -ErrorAction Stop
    $inputJson = $inputContent | ConvertFrom-Json -Depth 100
} catch {
    Write-Error "Failed to read or parse input JSON: $_"
    exit 1
}

$lmStudioMessages = New-Object System.Collections.ArrayList
$ConversationTitle = ""

switch ($Source) {
    'Qwen' {
        # Qwen export is typically an array of chat objects
        $allMessages = @()
        foreach ($chat in $inputJson) {
            # Extract title if not already set
            if ([string]::IsNullOrWhiteSpace($ConversationTitle) -and $null -ne $chat.title) {
                $ConversationTitle = $chat.title
            }
            if ($null -ne $chat.chat -and $null -ne $chat.chat.messages) {
                # Qwen chat.messages is an already-ordered array
                foreach ($msg in $chat.chat.messages) {
                    $allMessages += $msg
                }
            }
        }

        foreach ($msg in $allMessages) {
            if ($msg.role -eq 'user') {
                $textContent = if ($null -ne $msg.content) { $msg.content } else { "" }
                
                $userMsg = @{
                    versions = @(
                        @{
                            type = "singleStep"
                            role = "user"
                            content = @(
                                @{ type = "text"; text = $textContent }
                            )
                            preprocessed = @{
                                role = "user"
                                content = @(
                                    @{ type = "text"; text = $textContent }
                                )
                            }
                        }
                    )
                    currentlySelected = 0
                }
                [void]$lmStudioMessages.Add($userMsg)
            }
            elseif ($msg.role -eq 'assistant') {
                $textContent = ""
                
                if ($null -ne $msg.content_list -and $msg.content_list.Count -gt 0) {
                    $contents = New-Object System.Collections.ArrayList
                    foreach ($item in $msg.content_list) {
                        if ($TextOnly) {
                            if ($item.phase -eq 'answer' -or $item.phase -eq $null) {
                                if (-not [string]::IsNullOrEmpty($item.content)) {
                                    [void]$contents.Add($item.content)
                                }
                            }
                        } else {
                            if (-not [string]::IsNullOrEmpty($item.content)) {
                                $prefix = ""
                                if ($item.phase -eq 'web_search') {
                                    $prefix = "`n*(Web Search)*`n"
                                }
                                [void]$contents.Add($prefix + $item.content)
                            } elseif ($item.phase -eq 'web_search' -and $null -ne $item.extra.tool_observation) {
                                [void]$contents.Add("`n*(Web Search Observation)*`n" + $item.extra.tool_observation)
                            }
                        }
                    }
                    $textContent = $contents -join "`n`n"
                } else {
                    $textContent = if ($null -ne $msg.content) { $msg.content } else { "" }
                }
                
                $assistantMsg = @{
                    versions = @(
                        @{
                            type = "multiStep"
                            role = "assistant"
                            senderInfo = @{ senderName = "Qwen" }
                            steps = @(
                                @{
                                    type = "contentBlock"
                                    stepIdentifier = ([guid]::NewGuid().ToString())
                                    content = @(
                                        @{
                                            type = "text"
                                            text = $textContent
                                        }
                                    )
                                    defaultShouldIncludeInContext = $true
                                    shouldIncludeInContext = $true
                                }
                            )
                        }
                    )
                    currentlySelected = 0
                }
                [void]$lmStudioMessages.Add($assistantMsg)
            }
        }
    }
    
    'Claude' {
        Write-Warning "Claude is not (yet) supporting Export conversation"
        # Placeholder for Claude conversion logic
    }

    'ChatGPT' {
        Write-Warning "ChatGPT is not (yet) supporting Export conversation"
        # Placeholder for ChatGPT conversion logic
    }

    'Z.ai' {
        Write-Warning "Z.ai is not (yet) supporting Export conversation"
        # Placeholder for Z.ai conversion logic
    }

    'DeepSeek' {
        Write-Warning "DeepSeek is not (yet) supporting Export conversation"
        # Placeholder for DeepSeek conversion logic
    }
}

if ($lmStudioMessages.Count -eq 0) {
    Write-Warning "No messages were extracted. Check if the source format matches the selected Source: $Source"
}

if ([string]::IsNullOrWhiteSpace($ConversationTitle)) {
    $ConversationTitle = "$Source Chat"
}

if ($Type -eq 'create') {
    $createdAt = [long][Math]::Round((Get-Date).ToUniversalTime().Subtract([datetime]'1970-01-01T00:00:00Z').TotalMilliseconds)
    
    $lmStudioData = [ordered]@{
        name = "[Imported] $ConversationTitle"
        pinned = $false
        createdAt = $createdAt
        preset = "@local:general-empty"
        tokenCount = 0
        userLastMessagedAt = $createdAt
        assistantLastMessagedAt = $createdAt
        systemPrompt = ""
        messages = $lmStudioMessages
        usePerChatPredictionConfig = $true
        perChatPredictionConfig = @{ fields = @() }
        clientInput = ""
        clientInputFiles = @()
        userFilesSizeBytes = 0
        notes = @()
        plugins = @("lmstudio/rag-v1")
        pluginConfigs = @{}
        disabledPluginTools = @()
        looseFiles = @()
    }
    
    try {
        $lmStudioData | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
        Write-Host "Successfully created new LM Studio chat file from $Source at $OutputPath"
    } catch {
        Write-Error "Failed to write output file: $_"
    }
}
elseif ($Type -eq 'merge') {
    if (-not (Test-Path $InputMergePath)) {
        Write-Error "Merge file not found at: $InputMergePath"
        exit 1
    }

    try {
        $lmMergeContent = Get-Content -Path $InputMergePath -Raw -ErrorAction Stop
        $lmMergeData = $lmMergeContent | ConvertFrom-Json -Depth 100
        
        $existingMessages = New-Object System.Collections.ArrayList
        if ($null -ne $lmMergeData.messages) {
            foreach ($m in $lmMergeData.messages) {
                [void]$existingMessages.Add($m)
            }
        }
        
        foreach ($m in $lmStudioMessages) {
            [void]$existingMessages.Add($m)
        }
        
        $lmMergeData.messages = $existingMessages
        
        $lmMergeData | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
        Write-Host "Successfully merged $Source chat into LM Studio chat file at $OutputPath"
    } catch {
        Write-Error "Failed to merge and write output file: $_"
    }
}

