local AIPromptEng = {}

AIPromptEng.Version = 3

AIPromptEng.ScriptIndex = {}
AIPromptEng.Feedback = {}
AIPromptEng.LearnedTerms = {}

AIPromptEng.Actions = {
    create = {
        "create",
        "make",
        "build",
        "spawn",
        "generate",
        "add"
    },

    find = {
        "find",
        "search",
        "locate",
        "look",
        "look for",
        "get",
        "show"
    },

    set = {
        "set",
        "give",
        "change",
        "put",
        "assign"
    },

    increase = {
        "increase",
        "raise",
        "boost",
        "more",
        "higher",
        "faster"
    },

    decrease = {
        "decrease",
        "lower",
        "reduce",
        "less",
        "slower"
    },

    remove = {
        "remove",
        "delete",
        "destroy",
        "clear"
    },

    enable = {
        "enable",
        "turn on",
        "activate",
        "start"
    },

    disable = {
        "disable",
        "turn off",
        "deactivate",
        "stop"
    },

    test = {
        "test",
        "debug",
        "check",
        "simulate",
        "try"
    },

    move = {
        "move",
        "teleport",
        "travel",
        "go"
    },

    collect = {
        "collect",
        "pickup",
        "pick up",
        "gather"
    },

    automate = {
        "automate",
        "automatic",
        "auto",
        "auto farm",
        "autofarm"
    },

    inspect = {
        "inspect",
        "analyse",
        "analyze",
        "examine"
    }
}

AIPromptEng.Targets = {
    money = {
        "money",
        "cash",
        "coins",
        "coin",
        "currency",
        "gold",
        "balance",
        "wallet"
    },

    health = {
        "health",
        "hp",
        "hitpoints",
        "hit points"
    },

    speed = {
        "speed",
        "walkspeed",
        "walk speed",
        "fast"
    },

    jump = {
        "jump",
        "jumppower",
        "jump power"
    },

    ball = {
        "ball",
        "balls",
        "football",
        "soccer ball"
    },

    pet = {
        "pet",
        "pets"
    },

    brainrot = {
        "brainrot",
        "brainrots"
    },

    player = {
        "player",
        "players",
        "character",
        "characters",
        "user"
    },

    npc = {
        "npc",
        "npcs",
        "bot",
        "bots",
        "enemy",
        "enemies"
    },

    item = {
        "item",
        "items",
        "pickup",
        "loot",
        "collectible"
    },

    inventory = {
        "inventory",
        "bag",
        "storage"
    },

    vehicle = {
        "vehicle",
        "vehicles",
        "car",
        "cars"
    },

    weapon = {
        "weapon",
        "weapons",
        "gun",
        "guns",
        "tool",
        "tools"
    },

    folder = {
        "folder",
        "directory"
    },

    script = {
        "script",
        "scripts",
        "module",
        "modules",
        "file",
        "files"
    },

    gui = {
        "gui",
        "ui",
        "interface",
        "menu"
    },

    button = {
        "button",
        "buttons"
    },

    round = {
        "round",
        "rounds",
        "match",
        "matches",
        "game"
    },

    role = {
        "role",
        "roles",
        "team",
        "teams"
    },

    value = {
        "value",
        "number",
        "amount",
        "quantity"
    }
}

AIPromptEng.Properties = {
    speed = {
        "speed",
        "faster",
        "slower",
        "velocity"
    },

    health = {
        "health",
        "hp",
        "damage",
        "heal"
    },

    value = {
        "value",
        "amount",
        "number",
        "quantity"
    },

    position = {
        "position",
        "location",
        "place"
    },

    size = {
        "size",
        "bigger",
        "smaller",
        "scale"
    },

    enabled = {
        "enabled",
        "enable",
        "disabled",
        "disable"
    },

    name = {
        "name",
        "rename"
    },

    cooldown = {
        "cooldown",
        "delay",
        "wait"
    },

    range = {
        "range",
        "distance"
    }
}

local function Normalize(text)
    text = string.lower(tostring(text or ""))
    text = text:gsub("[%p]", " ")
    text = text:gsub("%s+", " ")

    return text:match("^%s*(.-)%s*$")
end

local function GetWords(text)
    local result = {}

    for word in string.gmatch(Normalize(text), "%S+") do
        table.insert(result, word)
    end

    return result
end

local function Contains(text, phrase)
    return string.find(
        Normalize(text),
        Normalize(phrase),
        1,
        true
    ) ~= nil
end

local function Similarity(a, b)
    a = Normalize(a)
    b = Normalize(b)

    if a == "" or b == "" then
        return 0
    end

    if a == b then
        return 100
    end

    if string.find(a, b, 1, true) then
        return 90
    end

    if string.find(b, a, 1, true) then
        return 90
    end

    local matches = 0

    for i = 1, #a do
        local character = a:sub(i, i)

        if string.find(b, character, 1, true) then
            matches = matches + 1
        end
    end

    return math.floor(
        (matches / math.max(#a, #b)) * 100
    )
end

local function Detect(prompt, groups)
    local bestName = "unknown"
    local bestScore = 0

    for name, aliases in pairs(groups) do
        for _, alias in ipairs(aliases) do
            if Contains(prompt, alias) then
                local score = 100 + #alias

                if score > bestScore then
                    bestName = name
                    bestScore = score
                end
            end
        end
    end

    return bestName, bestScore
end

function AIPromptEng.ClearScripts()
    AIPromptEng.ScriptIndex = {}
end

function AIPromptEng.RegisterScript(data)
    if type(data) ~= "table" then
        return false
    end

    table.insert(
        AIPromptEng.ScriptIndex,
        {
            Name = tostring(data.Name or ""),
            Path = tostring(data.Path or ""),
            ClassName = tostring(data.ClassName or ""),
            Tags = data.Tags or {}
        }
    )

    return true
end

function AIPromptEng.RegisterScripts(list)
    local count = 0

    for _, item in ipairs(list or {}) do
        if AIPromptEng.RegisterScript(item) then
            count = count + 1
        end
    end

    return count
end

function AIPromptEng.GetNumber(prompt)
    local number = string.match(
        tostring(prompt or ""),
        "%-?%d+%.?%d*"
    )

    if number then
        return tonumber(number)
    end

    return nil
end

function AIPromptEng.FindMatches(prompt)
    local results = {}
    local queryWords = GetWords(prompt)

    for _, scriptInfo in ipairs(AIPromptEng.ScriptIndex) do
        local score = 0

        local searchable = {
            scriptInfo.Name,
            scriptInfo.Path
        }

        for _, tag in ipairs(scriptInfo.Tags or {}) do
            table.insert(searchable, tag)
        end

        for _, queryWord in ipairs(queryWords) do
            if #queryWord >= 3 then
                local bestWordScore = 0

                for _, text in ipairs(searchable) do
                    local currentScore = Similarity(
                        queryWord,
                        tostring(text)
                    )

                    if currentScore > bestWordScore then
                        bestWordScore = currentScore
                    end
                end

                score = score + bestWordScore
            end
        end

        if score > 0 then
            table.insert(
                results,
                {
                    Script = scriptInfo,
                    Score = math.floor(score)
                }
            )
        end
    end

    table.sort(
        results,
        function(a, b)
            return a.Score > b.Score
        end
    )

    return results
end

function AIPromptEng.AddFeedback(
    prompt,
    reason,
    unknownTerms
)
    table.insert(
        AIPromptEng.Feedback,
        {
            Prompt = tostring(prompt or ""),
            Reason = tostring(reason or "UNKNOWN"),
            UnknownTerms = unknownTerms or {},
            Time = os.time()
        }
    )
end

function AIPromptEng.GetFeedback()
    return AIPromptEng.Feedback
end

function AIPromptEng.Learn(
    prompt,
    selectedPath
)
    local key = Normalize(prompt)

    if not AIPromptEng.LearnedTerms[key] then
        AIPromptEng.LearnedTerms[key] = {}
    end

    table.insert(
        AIPromptEng.LearnedTerms[key],
        tostring(selectedPath)
    )

    return true
end

function AIPromptEng.Parse(prompt)
    local original = tostring(prompt or "")
    local clean = Normalize(original)

    local action = Detect(
        clean,
        AIPromptEng.Actions
    )

    local target = Detect(
        clean,
        AIPromptEng.Targets
    )

    local property = Detect(
        clean,
        AIPromptEng.Properties
    )

    local value = AIPromptEng.GetNumber(original)

    local matches = AIPromptEng.FindMatches(clean)

    local confidence = 0

    if action ~= "unknown" then
        confidence = confidence + 30
    end

    if target ~= "unknown" then
        confidence = confidence + 30
    end

    if property ~= "unknown" then
        confidence = confidence + 15
    end

    if value ~= nil then
        confidence = confidence + 10
    end

    if #matches > 0 then
        confidence = confidence + 15
    end

    if confidence > 100 then
        confidence = 100
    end

    local unknownTerms = {}

    if target == "unknown" then
        for _, word in ipairs(GetWords(clean)) do
            if #word >= 4 then
                table.insert(
                    unknownTerms,
                    word
                )
            end
        end
    end

    local parsed = {
        Version = AIPromptEng.Version,
        OriginalPrompt = original,
        Prompt = clean,
        Intent = action,
        Action = action,
        Target = target,
        Property = property,
        Value = value,
        Subject = "self",
        Matches = matches,
        MatchCount = #matches,
        Confidence = confidence,
        UnknownTerms = unknownTerms,
        FeedbackNeeded = false
    }

    if confidence < 50 or #unknownTerms > 0 then
        parsed.FeedbackNeeded = true

        AIPromptEng.AddFeedback(
            original,
            "LOW_CONFIDENCE_OR_UNKNOWN_TERMS",
            unknownTerms
        )
    end

    return parsed
end

function AIPromptEng.BuildContext(parsed)
    local lines = {}

    table.insert(
        lines,
        "AIPROMPTENG_TRANSLATED_REQUEST"
    )

    table.insert(
        lines,
        "INTENT=" .. tostring(parsed.Intent)
    )

    table.insert(
        lines,
        "ACTION=" .. tostring(parsed.Action)
    )

    table.insert(
        lines,
        "TARGET=" .. tostring(parsed.Target)
    )

    table.insert(
        lines,
        "PROPERTY=" .. tostring(parsed.Property)
    )

    table.insert(
        lines,
        "VALUE=" .. tostring(parsed.Value)
    )

    table.insert(
        lines,
        "SUBJECT=" .. tostring(parsed.Subject)
    )

    table.insert(
        lines,
        "CONFIDENCE=" .. tostring(parsed.Confidence)
    )

    table.insert(
        lines,
        "ORIGINAL=" .. tostring(parsed.OriginalPrompt)
    )

    table.insert(lines, "MATCHES=")

    for _, match in ipairs(parsed.Matches or {}) do
        local info = match.Script or {}

        table.insert(
            lines,
            tostring(match.Score)
                .. "|"
                .. tostring(
                    info.Path
                    or info.Name
                    or "unknown"
                )
        )
    end

    return table.concat(lines, "\n")
end

function AIPromptEng.Process(prompt)
    local parsed = AIPromptEng.Parse(prompt)

    local context = AIPromptEng.BuildContext(
        parsed
    )

    return parsed, context
end

return AIPromptEng 
