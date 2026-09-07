local AIPromptEng = {}

AIPromptEng.Version = "2.0"

AIPromptEng.Database = {
    Scripts = {},
    GameObjects = {},
    Vocabulary = {},
    Feedback = {},
    LearnedAliases = {},
    History = {}
}

AIPromptEng.Config = {
    MaxMatches = 25,
    MinimumConfidence = 25,
    FeedbackConfidence = 40,
    LearnFromGame = true
}

AIPromptEng.Intents = {
    set = {
        "set",
        "change",
        "make",
        "put",
        "update"
    },

    add = {
        "add",
        "increase",
        "give",
        "gain",
        "grant",
        "boost"
    },

    remove = {
        "remove",
        "take",
        "subtract",
        "decrease",
        "delete",
        "clear"
    },

    get = {
        "get",
        "find",
        "show",
        "search",
        "locate",
        "look for"
    },

    create = {
        "create",
        "make",
        "build",
        "generate",
        "spawn",
        "add"
    },

    gui = {
        "gui",
        "button",
        "menu",
        "interface",
        "ui",
        "screen"
    },

    autofarm = {
        "autofarm",
        "auto farm",
        "farm automatically",
        "automatic farm",
        "grind automatically",
        "farm"
    },

    goto = {
        "goto",
        "go to",
        "move to",
        "travel to",
        "teleport to",
        "navigate to"
    },

    script = {
        "script",
        "code",
        "function",
        "system",
        "mechanic"
    }
}

AIPromptEng.Aliases = {
    money = {
        "money",
        "cash",
        "coins",
        "coin",
        "currency",
        "credits",
        "gold",
        "balance",
        "bucks"
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
        "movement speed",
        "velocity"
    },

    inventory = {
        "inventory",
        "items",
        "item",
        "bag",
        "backpack",
        "storage"
    },

    experience = {
        "experience",
        "xp",
        "level",
        "levels"
    },

    player = {
        "player",
        "me",
        "my",
        "self",
        "user"
    },

    gui = {
        "gui",
        "ui",
        "button",
        "menu",
        "interface",
        "screen"
    },

    autofarm = {
        "autofarm",
        "auto farm",
        "farm",
        "automatic farm",
        "grind"
    },

    rare = {
        "rare",
        "rare zone",
        "rare area",
        "rare place"
    },

    value = {
        "value",
        "best",
        "highest",
        "most",
        "maximum",
        "max"
    }
}

local function SafeString(value)
    return tostring(value or "")
end

local function Normalize(text)
    text = string.lower(SafeString(text))

    text = text:gsub("[%c]", " ")
    text = text:gsub("[_%-%.%(%){%}%[%],:;!%?]", " ")
    text = text:gsub("%s+", " ")

    return text
end

local function GetWords(text)
    local words = {}
    local used = {}

    for word in Normalize(text):gmatch("%S+") do
        if #word >= 2 and not used[word] then
            used[word] = true
            table.insert(words, word)
        end
    end

    return words
end

local function Contains(text, search)
    return string.find(
        Normalize(text),
        Normalize(search),
        1,
        true
    ) ~= nil
end

local function SplitName(text)
    local result = {}

    for word in SafeString(text):gmatch("[A-Za-z0-9]+") do
        if #word >= 2 then
            table.insert(
                result,
                string.lower(word)
            )
        end
    end

    return result
end

local function WordSimilarity(a, b)
    a = Normalize(a)
    b = Normalize(b)

    if a == b then
        return 100
    end

    if a == "" or b == "" then
        return 0
    end

    if string.find(a, b, 1, true)
        or string.find(b, a, 1, true) then
        return 80
    end

    local aWords = GetWords(a)
    local bWords = GetWords(b)

    local score = 0

    for _, wordA in ipairs(aWords) do
        for _, wordB in ipairs(bWords) do

            if wordA == wordB then
                score = score + 20

            elseif string.find(
                wordA,
                wordB,
                1,
                true
            ) then
                score = score + 12

            elseif string.find(
                wordB,
                wordA,
                1,
                true
            ) then
                score = score + 12
            end

        end
    end

    return math.min(
        score,
        100
    )
end

local function ExtractNumber(text)
    local number = string.match(
        SafeString(text),
        "(%d[%d,]*)"
    )

    if number then
        return number:gsub(",", "")
    end

    return nil
end

local function DetectSubject(prompt)
    local text = Normalize(prompt)

    if Contains(text, "me")
        or Contains(text, "my")
        or Contains(text, "myself") then
        return "me"
    end

    if Contains(text, "all players") then
        return "allPlayers"
    end

    if Contains(text, "player") then
        return "player"
    end

    return "me"
end

local function DetectGUI(prompt)
    local text = Normalize(prompt)

    if Contains(text, "gui")
        or Contains(text, "button")
        or Contains(text, "menu")
        or Contains(text, "ui")
        or Contains(text, "interface") then
        return true
    end

    return false
end

local function DetectRayfield(prompt)
    local text = Normalize(prompt)

    if Contains(text, "rayfield") then
        return true
    end

    return false
end

local function DetectBestValue(prompt)
    local text = Normalize(prompt)

    if Contains(text, "best")
        or Contains(text, "highest")
        or Contains(text, "most valuable")
        or Contains(text, "highest value")
        or Contains(text, "best value") then
        return true
    end

    return false
end

local function DetectIntent(prompt)
    local text = Normalize(prompt)

    local scores = {}

    for intent, words in pairs(
        AIPromptEng.Intents
    ) do

        scores[intent] = 0

        for _, word in ipairs(words) do

            if Contains(text, word) then
                scores[intent] =
                    scores[intent] + 20
            end

        end

    end

    if Contains(text, "every time")
        and DetectGUI(text) then

        scores.gui =
            (scores.gui or 0) + 25

        scores.add =
            (scores.add or 0) + 20
    end

    if Contains(text, "autofarm")
        or Contains(text, "auto farm") then

        scores.autofarm = 100
    end

    local bestIntent = "unknown"
    local bestScore = 0

    for intent, score in pairs(scores) do

        if score > bestScore then
            bestIntent = intent
            bestScore = score
        end

    end

    return bestIntent, bestScore
end

local function DetectAction(prompt, intent)
    local text = Normalize(prompt)

    if intent == "autofarm" then
        return "autofarm"
    end

    if Contains(text, "set") then
        return "setTarget"
    end

    if Contains(text, "give")
        or Contains(text, "add")
        or Contains(text, "increase")
        or Contains(text, "gain")
        or Contains(text, "grant") then

        return "addTarget"
    end

    if Contains(text, "remove")
        or Contains(text, "take")
        or Contains(text, "subtract")
        or Contains(text, "decrease") then

        return "removeTarget"
    end

    if DetectGUI(text) then
        return "createGUI"
    end

    if Contains(text, "find")
        or Contains(text, "search")
        or Contains(text, "locate") then

        return "findTarget"
    end

    if intent == "create" then
        return "create"
    end

    return "unknown"
end

local function DetectTarget(prompt)
    local text = Normalize(prompt)

    local bestTarget = "unknown"
    local bestScore = 0

    for target, aliases in pairs(
        AIPromptEng.Aliases
    ) do

        for _, alias in ipairs(aliases) do

            if Contains(text, alias) then

                local score =
                    #alias * 5

                if score > bestScore then
                    bestTarget = target
                    bestScore = score
                end

            end

        end

    end

    for alias, target in pairs(
        AIPromptEng.Database.LearnedAliases
    ) do

        if Contains(text, alias) then
            bestTarget = target
            bestScore = 100
        end

    end

    return bestTarget
end

local function LearnWord(word, source)
    word = Normalize(word)

    if word == ""
        or #word < 2 then
        return
    end

    local entry =
        AIPromptEng.Database.Vocabulary[word]

    if not entry then

        AIPromptEng.Database.Vocabulary[word] = {
            Count = 1,
            Sources = {
                [source] = true
            }
        }

    else

        entry.Count =
            entry.Count + 1

        entry.Sources[source] = true

    end
end

local function LearnObject(info)
    if type(info) ~= "table" then
        return
    end

    local name =
        SafeString(info.Name)

    local path =
        SafeString(info.Path)

    local category =
        SafeString(info.Category)

    for _, word in ipairs(
        SplitName(name)
    ) do

        LearnWord(
            word,
            "name"
        )

    end

    for _, word in ipairs(
        SplitName(path)
    ) do

        LearnWord(
            word,
            "path"
        )

    end

    for _, word in ipairs(
        SplitName(category)
    ) do

        LearnWord(
            word,
            "category"
        )

    end
end

local function ObjectSearchText(info)
    return Normalize(
        SafeString(info.Name)
        .. " "
        .. SafeString(info.Path)
        .. " "
        .. SafeString(info.ClassName)
        .. " "
        .. SafeString(info.Category)
        .. " "
        .. SafeString(info.ParentName)
    )
end

local function IsCheckpointObject(info)
    local category =
        Normalize(info.Category)

    if category == "checkpoints" then
        return true
    end

    local text =
        ObjectSearchText(info)

    local words = {
        "checkpoint",
        "waypoint",
        "zone",
        "route",
        "spawn",
        "portal",
        "teleport"
    }

    for _, word in ipairs(words) do

        if Contains(text, word) then
            return true
        end

    end

    return false
end

function AIPromptEng.ClearScripts()
    AIPromptEng.Database.Scripts = {}
end

function AIPromptEng.ClearGameIndex()
    AIPromptEng.Database.GameObjects = {}
    AIPromptEng.Database.Vocabulary = {}
end

function AIPromptEng.RegisterScript(data)
    if type(data) ~= "table" then
        return false
    end

    table.insert(
        AIPromptEng.Database.Scripts,
        data
    )

    LearnObject(data)

    return true
end

function AIPromptEng.RegisterGameObject(data)
    if type(data) ~= "table" then
        return false
    end

    table.insert(
        AIPromptEng.Database.GameObjects,
        data
    )

    if AIPromptEng.Config.LearnFromGame then
        LearnObject(data)
    end

    return true
end

function AIPromptEng.RegisterGameIndex(list)
    if type(list) ~= "table" then
        return false
    end

    for _, data in ipairs(list) do
        AIPromptEng.RegisterGameObject(data)
    end

    return true
end

function AIPromptEng.AddAlias(alias, target)
    alias = Normalize(alias)
    target = Normalize(target)

    if alias == ""
        or target == "" then

        return false
    end

    AIPromptEng.Database.LearnedAliases[
        alias
    ] = target

    return true
end

function AIPromptEng.FindMatches(query, intent)
    query = SafeString(query)

    local results = {}
    local normalizedQuery =
        Normalize(query)

    local searchCheckpoints =
        intent == "autofarm"
        or intent == "goto"

    local allObjects = {}

    for _, info in ipairs(
        AIPromptEng.Database.GameObjects
    ) do

        table.insert(
            allObjects,
            info
        )

    end

    for _, info in ipairs(
        AIPromptEng.Database.Scripts
    ) do

        table.insert(
            allObjects,
            info
        )

    end

    for _, info in ipairs(allObjects) do

        local category =
            Normalize(info.Category)

        if category ~= "parts"
            or searchCheckpoints
            or IsCheckpointObject(info) then

            local text =
                ObjectSearchText(info)

            local score =
                WordSimilarity(
                    normalizedQuery,
                    text
                )

            local queryWords =
                GetWords(normalizedQuery)

            for _, word in ipairs(queryWords) do

                if string.find(
                    text,
                    word,
                    1,
                    true
                ) then

                    score =
                        score + 15

                end

            end

            local name =
                Normalize(info.Name)

            if name ~= ""
                and string.find(
                    name,
                    normalizedQuery,
                    1,
                    true
                ) then

                score =
                    score + 50

            end

            if string.find(
                normalizedQuery,
                name,
                1,
                true
            ) then

                score =
                    score + 40

            end

            if intent == "autofarm"
                and IsCheckpointObject(info) then

                score =
                    score + 25

            end

            if score > 10 then

                table.insert(
                    results,
                    {
                        Score = score,
                        Object = info,
                        Script = info
                    }
                )

            end

        end

    end

    table.sort(
        results,
        function(a, b)
            return a.Score > b.Score
        end
    )

    local limited = {}

    for index, result in ipairs(results) do

        if index >
            AIPromptEng.Config.MaxMatches then
            break
        end

        table.insert(
            limited,
            result
        )

    end

    return limited
end

local function ExtractZone(prompt)
    local text = Normalize(prompt)

    local patterns = {
        "to the ([%w%s]+) zone",
        "to ([%w%s]+) zone",
        "in the ([%w%s]+) zone",
        "go to ([%w%s]+)"
    }

    for _, pattern in ipairs(patterns) do

        local value =
            string.match(
                text,
                pattern
            )

        if value then

            value =
                value:gsub(
                    "^%s+",
                    ""
                )

            value =
                value:gsub(
                    "%s+$",
                    ""
                )

            return value
        end

    end

    return "unknown"
end

local function BuildAutofarmCommand(prompt)
    local text = Normalize(prompt)

    local zone =
        ExtractZone(text)

    local target = "target"

    local skip = {
        make = true,
        me = true,
        an = true,
        a = true,
        autofarm = true,
        auto = true,
        farm = true,
        that = true,
        goes = true,
        go = true,
        to = true,
        the = true,
        zone = true,
        get = true,
        best = true,
        return = true,
        base = true,
        and = true
    }

    for _, word in ipairs(
        GetWords(text)
    ) do

        if not skip[word] then

            if word ~= zone then
                target = word
            end

        end

    end

    local command = {}

    if zone ~= "unknown" then

        table.insert(
            command,
            "goto "
            .. zone
            .. " zone"
        )

    end

    if DetectBestValue(text) then

        table.insert(
            command,
            "get bestValue "
            .. target
        )

    else

        table.insert(
            command,
            "get "
            .. target
        )

    end

    if Contains(text, "return")
        or Contains(text, "base") then

        table.insert(
            command,
            "return to base"
        )

    end

    return table.concat(
        command,
        " - "
    )
end

local function AddFeedback(prompt, parsed)
    table.insert(
        AIPromptEng.Database.Feedback,
        {
            Prompt = SafeString(prompt),
            Intent = parsed.Intent,
            Action = parsed.Action,
            Target = parsed.Target,
            Confidence = parsed.Confidence,
            Time = os.time()
        }
    )
end

local function BuildContext(parsed)
    local lines = {}

    table.insert(
        lines,
        "PROMPT_DATA"
    )

    table.insert(
        lines,
        "INTENT="
        .. SafeString(parsed.Intent)
    )

    table.insert(
        lines,
        "ACTION="
        .. SafeString(parsed.Action)
    )

    table.insert(
        lines,
        "TARGET="
        .. SafeString(parsed.Target)
    )

    table.insert(
        lines,
        "SUBJECT="
        .. SafeString(parsed.Subject)
    )

    if parsed.Value then

        table.insert(
            lines,
            "VALUE_OF="
            .. SafeString(parsed.Value)
        )

    end

    if parsed.AddingOf then

        table.insert(
            lines,
            "ADDING_OF="
            .. SafeString(parsed.AddingOf)
        )

    end

    table.insert(
        lines,
        "GUI="
        .. tostring(parsed.GUI)
    )

    table.insert(
        lines,
        "RAYFIELD="
        .. tostring(parsed.Rayfield)
    )

    if parsed.Zone
        and parsed.Zone ~= "unknown" then

        table.insert(
            lines,
            "ZONE="
            .. SafeString(parsed.Zone)
        )

    end

    if parsed.Command then

        table.insert(
            lines,
            "COMMAND="
            .. SafeString(parsed.Command)
        )

    end

    table.insert(
        lines,
        "CONFIDENCE="
        .. tostring(parsed.Confidence)
    )

    table.insert(
        lines,
        "MATCH_COUNT="
        .. tostring(parsed.MatchCount)
    )

    for index, match in ipairs(
        parsed.Matches
    ) do

        local info =
            match.Object
            or match.Script
            or {}

        table.insert(
            lines,
            "MATCH_"
            .. tostring(index)
            .. "="
            .. SafeString(info.Category)
            .. "|"
            .. SafeString(info.Path)
        )

    end

    return table.concat(
        lines,
        "\n"
    )
end

function AIPromptEng.Process(prompt)
    prompt = SafeString(prompt)

    local intent, intentScore =
        DetectIntent(prompt)

    local action =
        DetectAction(
            prompt,
            intent
        )

    local target =
        DetectTarget(prompt)

    local subject =
        DetectSubject(prompt)

    local value =
        ExtractNumber(prompt)

    local gui =
        DetectGUI(prompt)

    local rayfield =
        DetectRayfield(prompt)

    local matches =
        AIPromptEng.FindMatches(
            prompt,
            intent
        )

    local confidence =
        math.min(
            intentScore,
            100
        )

    if target ~= "unknown" then
        confidence =
            confidence + 20
    end

    if value then
        confidence =
            confidence + 10
    end

    if #matches > 0 then
        confidence =
            confidence + math.min(
                matches[1].Score / 4,
                30
            )
    end

    confidence =
        math.min(
            math.floor(confidence),
            100
        )

    local parsed = {
        Prompt = prompt,
        Intent = intent,
        Action = action,
        Target = target,
        Subject = subject,
        Value = nil,
        AddingOf = nil,
        GUI = gui,
        Rayfield = rayfield,
        Zone = "unknown",
        BestValue = DetectBestValue(prompt),
        Command = nil,
        Confidence = confidence,
        Matches = matches,
        MatchCount = #matches
    }

    if action == "setTarget" then
        parsed.Value = value
    end

    if action == "addTarget" then
        parsed.AddingOf = value
    end

    if intent == "autofarm" then

        parsed.Intent = "autofarm"
        parsed.Action = "autofarm"
        parsed.Target = target
        parsed.Zone =
            ExtractZone(prompt)

        parsed.Command =
            BuildAutofarmCommand(
                prompt
            )

        parsed.GUI = false

    end

    if gui
        and action ~= "autofarm" then

        if action == "unknown"
            or action == "create" then

            parsed.Action =
                "createGUI"

        end

    end

    if parsed.Intent == "add"
        and parsed.Action == "unknown" then

        parsed.Action =
            "addTarget"

    end

    if parsed.Intent == "set"
        and parsed.Action == "unknown" then

        parsed.Action =
            "setTarget"

    end

    if parsed.Confidence <
        AIPromptEng.Config.FeedbackConfidence then

        AddFeedback(
            prompt,
            parsed
        )

    end

    table.insert(
        AIPromptEng.Database.History,
        parsed
    )

    if #AIPromptEng.Database.History > 100 then
        table.remove(
            AIPromptEng.Database.History,
            1
        )
    end

    local context =
        BuildContext(parsed)

    return parsed, context
end

function AIPromptEng.GetFeedback()
    return AIPromptEng.Database.Feedback
end

function AIPromptEng.GetVocabulary()
    return AIPromptEng.Database.Vocabulary
end

function AIPromptEng.GetHistory()
    return AIPromptEng.Database.History
end

function AIPromptEng.ClearFeedback()
    AIPromptEng.Database.Feedback = {}
end

function AIPromptEng.LearnAliasFromFeedback(
    alias,
    target
)
    return AIPromptEng.AddAlias(
        alias,
        target
    )
end

function AIPromptEng.GetStats()
    return {
        Scripts =
            #AIPromptEng.Database.Scripts,

        GameObjects =
            #AIPromptEng.Database.GameObjects,

        Feedback =
            #AIPromptEng.Database.Feedback,

        History =
            #AIPromptEng.Database.History,

        Version =
            AIPromptEng.Version
    }
end

return AIPromptEng
