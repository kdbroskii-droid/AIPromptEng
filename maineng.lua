local AIPromptEng = {}

AIPromptEng.Version = 4
AIPromptEng.ScriptIndex = {}
AIPromptEng.GameIndex = {}
AIPromptEng.Feedback = {}
AIPromptEng.LearnedTerms = {}

local function Normalize(text)
    text = string.lower(tostring(text or ""))
    text = text:gsub("[%p_]", " ")
    text = text:gsub("%s+", " ")
    return text:match("^%s*(.-)%s*$") or ""
end

local function Words(text)
    local result = {}

    for word in Normalize(text):gmatch("%S+") do
        table.insert(result, word)
    end

    return result
end

local function Contains(text, phrase)
    text = Normalize(text)
    phrase = Normalize(phrase)

    return phrase ~= "" and string.find(text, phrase, 1, true) ~= nil
end

local function ExtractNumber(text)
    local number = tostring(text or ""):match("(%-?%d+%.?%d*)")

    if number then
        return tonumber(number)
    end

    return nil
end

local function HasAny(text, list)
    for _, phrase in ipairs(list) do
        if Contains(text, phrase) then
            return true
        end
    end

    return false
end

local function GetSimilarity(a, b)
    a = Normalize(a)
    b = Normalize(b)

    if a == "" or b == "" then
        return 0
    end

    if a == b then
        return 100
    end

    if a:find(b, 1, true) or b:find(a, 1, true) then
        return 90
    end

    local aWords = Words(a)
    local bWords = Words(b)

    local matches = 0

    for _, aWord in ipairs(aWords) do
        for _, bWord in ipairs(bWords) do
            if aWord == bWord then
                matches = matches + 1
                break
            end

            if #aWord >= 4 and #bWord >= 4 then
                if aWord:find(bWord, 1, true) or bWord:find(aWord, 1, true) then
                    matches = matches + 0.75
                    break
                end
            end
        end
    end

    local total = math.max(#aWords, #bWords)

    if total == 0 then
        return 0
    end

    return math.floor((matches / total) * 100)
end

function AIPromptEng.ClearScripts()
    AIPromptEng.ScriptIndex = {}
end

function AIPromptEng.ClearGameIndex()
    AIPromptEng.GameIndex = {}
end

function AIPromptEng.RegisterScript(data)
    if type(data) ~= "table" then
        return false
    end

    table.insert(AIPromptEng.ScriptIndex, {
        Name = tostring(data.Name or ""),
        Path = tostring(data.Path or ""),
        ClassName = tostring(data.ClassName or ""),
        Tags = data.Tags or {},
        Category = tostring(data.Category or "SCRIPTS")
    })

    return true
end

function AIPromptEng.RegisterGameObject(data)
    if type(data) ~= "table" then
        return false
    end

    table.insert(AIPromptEng.GameIndex, {
        Name = tostring(data.Name or ""),
        Path = tostring(data.Path or ""),
        ClassName = tostring(data.ClassName or ""),
        Category = tostring(data.Category or "OBJECTS"),
        ParentName = tostring(data.ParentName or ""),
        Attributes = data.Attributes or {}
    })

    return true
end

function AIPromptEng.RegisterGameIndex(list)
    for _, item in ipairs(list or {}) do
        AIPromptEng.RegisterGameObject(item)
    end
end

local function DetectTarget(text)
    local targets = {
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
            "walk speed"
        },

        brainrot = {
            "brainrot",
            "brainrots"
        },

        pet = {
            "pet",
            "pets"
        },

        item = {
            "item",
            "items",
            "loot",
            "collectible"
        },

        inventory = {
            "inventory",
            "bag",
            "storage"
        },

        player = {
            "player",
            "players",
            "character"
        },

        base = {
            "base",
            "plot",
            "home"
        },

        zone = {
            "zone",
            "area",
            "region"
        }
    }

    local bestTarget = "unknown"
    local bestScore = 0

    for target, aliases in pairs(targets) do
        for _, alias in ipairs(aliases) do
            if Contains(text, alias) then
                local score = #alias

                if score > bestScore then
                    bestTarget = target
                    bestScore = score
                end
            end
        end
    end

    return bestTarget
end

local function DetectGUI(text)
    if HasAny(text, {
        "rayfield",
        " gui",
        "make a gui",
        "create a gui",
        "interface",
        "menu",
        "button",
        "toggle"
    }) then
        return true
    end

    return false
end

local function DetectIntent(text)
    if HasAny(text, {
        "autofarm",
        "auto farm",
        "farm automatically",
        "automatic farm"
    }) then
        return "autofarm"
    end

    if HasAny(text, {
        "make a gui",
        "create a gui",
        "rayfield gui",
        "interface",
        "menu"
    }) then
        return "create_gui"
    end

    if HasAny(text, {
        "give me",
        "set my",
        "set ",
        "change my",
        "change "
    }) then
        return "set"
    end

    if HasAny(text, {
        "add ",
        "increase ",
        "every time",
        "each time"
    }) then
        return "add"
    end

    if HasAny(text, {
        "find ",
        "search ",
        "locate "
    }) then
        return "find"
    end

    if HasAny(text, {
        "make ",
        "create ",
        "build "
    }) then
        return "create"
    end

    return "unknown"
end

local function DetectAction(text, intent)
    if intent == "set" then
        return "setTarget"
    end

    if intent == "add" then
        return "addTarget"
    end

    if Contains(text, "give me") then
        if Contains(text, "every time")
            or Contains(text, "each time")
            or Contains(text, "click") then
            return "addTarget"
        end

        return "setTarget"
    end

    return "none"
end

local function DetectSubject(text)
    if HasAny(text, {
        "me",
        "my ",
        "myself"
    }) then
        return "me"
    end

    return "unknown"
end

local function DetectTrigger(text)
    if HasAny(text, {
        "click",
        "button"
    }) then
        return "buttonClick"
    end

    if Contains(text, "every time") then
        return "repeat"
    end

    if Contains(text, "when player joins") then
        return "playerJoined"
    end

    return "none"
end

local function DetectZone(text)
    local zones = {
        "rare",
        "common",
        "epic",
        "legendary",
        "mythic",
        "secret"
    }

    for _, zone in ipairs(zones) do
        if Contains(text, zone .. " zone")
            or Contains(text, zone .. " area") then
            return zone
        end
    end

    return "unknown"
end

local function DetectBestValue(text)
    if HasAny(text, {
        "best",
        "highest value",
        "most valuable",
        "rarest"
    }) then
        return "best"
    end

    return "unknown"
end

local function IsPartCategory(category)
    return category == "CHECKPOINTS"
        or category == "PARTS"
end

function AIPromptEng.FindMatches(query, intent)
    local results = {}

    local searchParts = intent == "autofarm"
        or intent == "navigation"
        or intent == "move"

    for _, item in ipairs(AIPromptEng.GameIndex) do
        local category = tostring(item.Category or "")

        if not IsPartCategory(category) or searchParts then
            local searchable = table.concat({
                item.Name,
                item.Path,
                item.ClassName,
                item.ParentName
            }, " ")

            local score = GetSimilarity(query, searchable)

            local queryWords = Words(query)

            for _, word in ipairs(queryWords) do
                if #word >= 3 then
                    if Contains(searchable, word) then
                        score = score + 25
                    end
                end
            end

            if score >= 15 then
                table.insert(results, {
                    Object = item,
                    Score = score
                })
            end
        end
    end

    for _, item in ipairs(AIPromptEng.ScriptIndex) do
        local searchable = table.concat({
            item.Name,
            item.Path,
            item.ClassName
        }, " ")

        local score = GetSimilarity(query, searchable)

        if score >= 15 then
            table.insert(results, {
                Script = item,
                Score = score
            })
        end
    end

    table.sort(results, function(a, b)
        return a.Score > b.Score
    end)

    local limited = {}

    for index, result in ipairs(results) do
        if index <= 20 then
            table.insert(limited, result)
        end
    end

    return limited
end

function AIPromptEng.AddFeedback(prompt, reason, data)
    table.insert(AIPromptEng.Feedback, {
        Prompt = tostring(prompt or ""),
        Reason = tostring(reason or ""),
        Data = data or {},
        Time = os.time()
    })
end

function AIPromptEng.GetFeedback()
    return AIPromptEng.Feedback
end

function AIPromptEng.Process(prompt)
    local original = tostring(prompt or "")
    local text = Normalize(original)

    local intent = DetectIntent(text)
    local action = DetectAction(text, intent)
    local target = DetectTarget(text)
    local subject = DetectSubject(text)
    local value = ExtractNumber(original)
    local gui = DetectGUI(text)
    local trigger = DetectTrigger(text)
    local zone = DetectZone(text)
    local bestValue = DetectBestValue(text)

    if gui and intent == "set" then
        intent = "create_gui"
    end

    if gui and action == "setTarget" then
        if trigger == "buttonClick" then
            action = "addTarget"
        end
    end

    local matches = AIPromptEng.FindMatches(
        text,
        intent
    )

    local parsed = {
        OriginalPrompt = original,
        Intent = intent,
        Action = action,
        Target = target,
        Subject = subject,
        Value = value,
        GUI = gui,
        Trigger = trigger,
        Zone = zone,
        BestValue = bestValue,
        Matches = matches,
        MatchCount = #matches
    }

    if intent == "unknown" then
        AIPromptEng.AddFeedback(
            original,
            "UNKNOWN_INTENT",
            parsed
        )
    end

    if target == "unknown" then
        AIPromptEng.AddFeedback(
            original,
            "UNKNOWN_TARGET",
            parsed
        )
    end

    local lines = {}

    table.insert(
        lines,
        "AIPROMPTENG_CONTEXT"
    )

    table.insert(
        lines,
        "INTENT=" .. tostring(intent)
    )

    if action ~= "none" then
        table.insert(
            lines,
            "ACTION=" .. tostring(action)
        )
    end

    table.insert(
        lines,
        "TARGET=" .. tostring(target)
    )

    table.insert(
        lines,
        "SUBJECT=" .. tostring(subject)
    )

    if action == "setTarget" and value ~= nil then
        table.insert(
            lines,
            "VALUE-OF=" .. tostring(value)
        )
    end

    if action == "addTarget" and value ~= nil then
        table.insert(
            lines,
            "ADDING-OF=" .. tostring(value)
        )
    end

    table.insert(
        lines,
        "GUI=" .. tostring(gui)
    )

    if gui then
        table.insert(
            lines,
            "GUI-LIBRARY=Rayfield"
        )
    end

    if trigger ~= "none" then
        table.insert(
            lines,
            "TRIGGER=" .. tostring(trigger)
        )
    end

    if intent == "autofarm" then
        local command = {}

        if zone ~= "unknown" then
            table.insert(
                command,
                "goto " .. zone .. " zone"
            )
        end

        if bestValue == "best" then
            table.insert(
                command,
                "get bestValue " .. target
            )
        else
            table.insert(
                command,
                "get " .. target
            )
        end

        if Contains(text, "return to base")
            or Contains(text, "return") then
            table.insert(
                command,
                "return to base"
            )
        else
            table.insert(
                command,
                "return to base"
            )
        end

        table.insert(
            lines,
            "COMMAND=" .. table.concat(command, " - ")
        )
    end

    if zone ~= "unknown" then
        table.insert(
            lines,
            "ZONE=" .. tostring(zone)
        )
    end

    if bestValue ~= "unknown" then
        table.insert(
            lines,
            "VALUE=" .. tostring(bestValue)
        )
    end

    table.insert(
        lines,
        "MATCHES=" .. tostring(#matches)
    )

    for _, match in ipairs(matches) do
        local item = match.Object
            or match.Script
            or {}

        table.insert(
            lines,
            "MATCH="
                .. tostring(match.Score)
                .. "|"
                .. tostring(item.Category or "SCRIPT")
                .. "|"
                .. tostring(
                    item.Path
                    or item.Name
                    or "unknown"
                )
        )
    end

    local context = table.concat(lines, "\n")

    return parsed, context
end

return AIPromptEng
