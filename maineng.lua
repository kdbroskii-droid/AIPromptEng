local AIPromptEng = {}

AIPromptEng.Version = "5.0"

local Database = {
    Scripts = {},
    Objects = {},
    Vocabulary = {},
    Feedback = {},
    History = {},
    LearnedAliases = {},
    Categories = {
        Scripts = {},
        LocalScripts = {},
        ModuleScripts = {},
        UI = {},
        Remotes = {},
        Values = {},
        Folders = {},
        Tools = {},
        Models = {},
        Checkpoints = {},
        Other = {}
    }
}

local IntentPatterns = {
    {
        Intent = "autofarm",
        Words = {
            "autofarm",
            "auto farm",
            "farm automatically",
            "farm for me",
            "automatically farm"
        }
    },
    {
        Intent = "set",
        Words = {
            "set",
            "change",
            "update",
            "make my"
        }
    },
    {
        Intent = "add",
        Words = {
            "give",
            "add",
            "increase",
            "grant",
            "award"
        }
    },
    {
        Intent = "remove",
        Words = {
            "remove",
            "take",
            "subtract",
            "delete"
        }
    },
    {
        Intent = "find",
        Words = {
            "find",
            "search",
            "locate",
            "look for"
        }
    },
    {
        Intent = "create",
        Words = {
            "create",
            "make",
            "build",
            "generate"
        }
    }
}

local TargetAliases = {
    money = {
        "money",
        "cash",
        "coins",
        "coin",
        "currency",
        "credits",
        "gold"
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
        "movement speed"
    },
    inventory = {
        "inventory",
        "items",
        "backpack",
        "storage"
    },
    experience = {
        "experience",
        "xp",
        "level"
    }
}

local StopWords = {
    the = true,
    a = true,
    an = true,
    to = true,
    for = true,
    me = true,
    my = true,
    and = true,
    or = true,
    in = true,
    on = true,
    with = true,
    of = true,
    it = true,
    this = true,
    that = true,
    please = true
}

local function Safe(value)
    return tostring(value or "")
end

local function Normalize(value)
    local text = string.lower(Safe(value))

    text = text:gsub("_", " ")
    text = text:gsub("-", " ")
    text = text:gsub("%.", " ")
    text = text:gsub("[^%w%s]", " ")
    text = text:gsub("%s+", " ")

    return text
end

local function Contains(text, search)
    text = Normalize(text)
    search = Normalize(search)

    if search == "" then
        return false
    end

    return string.find(
        text,
        search,
        1,
        true
    ) ~= nil
end

local function GetWords(text)
    local result = {}
    local used = {}

    for word in Normalize(text):gmatch("%S+") do
        if not StopWords[word]
            and #word > 1
            and not used[word] then

            used[word] = true

            table.insert(
                result,
                word
            )
        end
    end

    return result
end

local function GetPath(instance)
    local success, result = pcall(function()
        return instance:GetFullName()
    end)

    if success then
        return Safe(result)
    end

    return Safe(instance.Name)
end

local function LearnText(text)
    for _, word in ipairs(GetWords(text)) do
        Database.Vocabulary[word] =
            (Database.Vocabulary[word] or 0)
            + 1
    end
end

local function GetCategory(instance)
    if instance:IsA("LocalScript") then
        return "LocalScripts"
    end

    if instance:IsA("ModuleScript") then
        return "ModuleScripts"
    end

    if instance:IsA("Script") then
        return "Scripts"
    end

    if instance:IsA("RemoteEvent")
        or instance:IsA("RemoteFunction") then

        return "Remotes"
    end

    if instance:IsA("ScreenGui")
        or instance:IsA("BillboardGui")
        or instance:IsA("SurfaceGui")
        or instance:IsA("Frame")
        or instance:IsA("TextButton")
        or instance:IsA("ImageButton")
        or instance:IsA("TextLabel")
        or instance:IsA("TextBox")
        or instance:IsA("ScrollingFrame") then

        return "UI"
    end

    if instance:IsA("IntValue")
        or instance:IsA("NumberValue")
        or instance:IsA("BoolValue")
        or instance:IsA("StringValue")
        or instance:IsA("ObjectValue") then

        return "Values"
    end

    if instance:IsA("Folder") then
        return "Folders"
    end

    if instance:IsA("Tool") then
        return "Tools"
    end

    if instance:IsA("Model") then
        return "Models"
    end

    return "Other"
end

local function IsCheckpoint(instance)
    local name = Normalize(instance.Name)
    local path = Normalize(GetPath(instance))

    local checkpointWords = {
        "checkpoint",
        "waypoint",
        "zone",
        "spawn",
        "route",
        "destination",
        "rarezone",
        "rare zone",
        "base"
    }

    for _, word in ipairs(checkpointWords) do
        if Contains(name, word)
            or Contains(path, word) then

            return true
        end
    end

    return false
end

local function MakeInfo(instance)
    local category = GetCategory(instance)

    if instance:IsA("BasePart") then
        if IsCheckpoint(instance) then
            category = "Checkpoints"
        else
            return nil
        end
    end

    return {
        Name = Safe(instance.Name),
        Path = GetPath(instance),
        ClassName = Safe(instance.ClassName),
        Category = category
    }
end

local function AddObject(info)
    if type(info) ~= "table" then
        return false
    end

    local path = Safe(
        info.Path
        or info.Name
    )

    for _, existing in ipairs(
        Database.Objects
    ) do

        local existingPath = Safe(
            existing.Path
            or existing.Name
        )

        if existingPath == path then
            return false
        end
    end

    table.insert(
        Database.Objects,
        info
    )

    local category = Safe(
        info.Category
    )

    if Database.Categories[category] then
        table.insert(
            Database.Categories[category],
            info
        )
    end

    if category == "Scripts"
        or category == "LocalScripts"
        or category == "ModuleScripts" then

        table.insert(
            Database.Scripts,
            info
        )
    end

    LearnText(info.Name)
    LearnText(info.Path)
    LearnText(info.ClassName)

    return true
end

local function ExtractNumber(prompt)
    local number = string.match(
        Safe(prompt),
        "(%d[%d,]*)"
    )

    if number then
        return number:gsub(",", "")
    end

    return nil
end

local function DetectIntent(prompt)
    local bestIntent = "unknown"
    local bestScore = 0

    for _, pattern in ipairs(
        IntentPatterns
    ) do

        local score = 0

        for _, word in ipairs(
            pattern.Words
        ) do

            if Contains(
                prompt,
                word
            ) then

                score = score + #word
            end
        end

        if score > bestScore then
            bestScore = score
            bestIntent = pattern.Intent
        end
    end

    return bestIntent, bestScore
end

local function DetectTarget(prompt)
    local bestTarget = "unknown"
    local bestScore = 0

    for target, aliases in pairs(
        TargetAliases
    ) do

        for _, alias in ipairs(
            aliases
        ) do

            if Contains(
                prompt,
                alias
            ) then

                local score = #alias

                if score > bestScore then
                    bestScore = score
                    bestTarget = target
                end
            end
        end
    end

    if bestTarget ~= "unknown" then
        return bestTarget
    end

    for alias, target in pairs(
        Database.LearnedAliases
    ) do

        if Contains(
            prompt,
            alias
        ) then

            return target
        end
    end

    local bestWord = "unknown"
    local bestCount = 0

    for _, word in ipairs(
        GetWords(prompt)
    ) do

        local count =
            Database.Vocabulary[word]

        if count
            and count > bestCount then

            bestCount = count
            bestWord = word
        end
    end

    return bestWord
end

local function DetectGUI(prompt)
    local words = {
        "gui",
        "ui",
        "button",
        "menu",
        "interface",
        "screen"
    }

    for _, word in ipairs(words) do
        if Contains(
            prompt,
            word
        ) then

            return true
        end
    end

    return false
end

local function DetectRayfield(prompt)
    return Contains(
        prompt,
        "rayfield"
    )
end

local function ScoreWordMatch(
    queryWord,
    objectWord
)
    if queryWord == objectWord then
        return 100
    end

    if string.find(
        objectWord,
        queryWord,
        1,
        true
    ) then

        return 65
    end

    if string.find(
        queryWord,
        objectWord,
        1,
        true
    ) then

        return 45
    end

    return 0
end

local function ScoreInfo(
    queryWords,
    info,
    intent
)
    local score = 0

    local nameWords =
        GetWords(info.Name)

    local pathWords =
        GetWords(info.Path)

    local classWords =
        GetWords(info.ClassName)

    for _, queryWord in ipairs(
        queryWords
    ) do

        for _, objectWord in ipairs(
            nameWords
        ) do

            score = score
                + ScoreWordMatch(
                    queryWord,
                    objectWord
                )
        end

        for _, objectWord in ipairs(
            pathWords
        ) do

            score = score
                + (
                    ScoreWordMatch(
                        queryWord,
                        objectWord
                    )
                    * 0.5
                )
        end

        for _, objectWord in ipairs(
            classWords
        ) do

            score = score
                + (
                    ScoreWordMatch(
                        queryWord,
                        objectWord
                    )
                    * 0.25
                )
        end
    end

    if intent == "autofarm"
        and info.Category == "Checkpoints" then

        score = score + 30
    end

    return score
end

function AIPromptEng.FindMatches(
    query,
    intent
)
    local results = {}
    local queryWords =
        GetWords(query)

    for _, info in ipairs(
        Database.Objects
    ) do

        local score = ScoreInfo(
            queryWords,
            info,
            intent
        )

        if score > 0 then
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

    table.sort(
        results,
        function(a, b)
            return a.Score > b.Score
        end
    )

    local limited = {}

    for index, result in ipairs(
        results
    ) do

        if index > 30 then
            break
        end

        table.insert(
            limited,
            result
        )
    end

    return limited
end

function AIPromptEng.ClearScripts()
    Database.Scripts = {}

    Database.Categories.Scripts = {}
    Database.Categories.LocalScripts = {}
    Database.Categories.ModuleScripts = {}
end

function AIPromptEng.ClearGameIndex()
    Database.Scripts = {}
    Database.Objects = {}
    Database.Vocabulary = {}

    for category in pairs(
        Database.Categories
    ) do

        Database.Categories[category] = {}
    end
end

function AIPromptEng.RegisterScript(info)
    if type(info) ~= "table" then
        return false
    end

    if not info.Category then
        info.Category = "Scripts"
    end

    return AddObject(info)
end

function AIPromptEng.RegisterGameObject(info)
    return AddObject(info)
end

function AIPromptEng.RegisterGameIndex(list)
    if type(list) ~= "table" then
        return false
    end

    local added = 0

    for _, info in ipairs(list) do
        if AddObject(info) then
            added = added + 1
        end
    end

    return added
end

function AIPromptEng.ScanReplicatedGame()
    AIPromptEng.ClearGameIndex()

    local success, descendants =
        pcall(function()
            return game:GetDescendants()
        end)

    if not success then
        return {}, 0
    end

    local indexed = {}

    for _, instance in ipairs(
        descendants
    ) do

        local successInfo, info =
            pcall(
                MakeInfo,
                instance
            )

        if successInfo
            and info then

            if AddObject(info) then
                table.insert(
                    indexed,
                    info
                )
            end
        end
    end

    return indexed, #indexed
end

function AIPromptEng.LearnAlias(
    alias,
    target
)
    alias = Normalize(alias)
    target = Normalize(target)

    if alias == ""
        or target == "" then

        return false
    end

    Database.LearnedAliases[alias] =
        target

    return true
end

function AIPromptEng.AddFeedback(
    prompt,
    correctIntent,
    correctTarget
)
    local item = {
        Prompt = Safe(prompt),
        Intent = Safe(correctIntent),
        Target = Safe(correctTarget)
    }

    table.insert(
        Database.Feedback,
        item
    )

    if item.Target ~= "" then
        for _, word in ipairs(
            GetWords(item.Prompt)
        ) do

            if word ~= item.Target then
                Database.LearnedAliases[word] =
                    item.Target
            end
        end
    end

    return item
end

local function BuildAutofarmCommand(
    prompt,
    target,
    matches
)
    local commands = {}

    local lower =
        Normalize(prompt)

    local zone = nil

    for _, match in ipairs(
        matches
    ) do

        local info =
            match.Object
            or match

        if info.Category == "Checkpoints"
            or Contains(
                info.Name,
                "zone"
            ) then

            zone = info.Name
            break
        end
    end

    if Contains(
        lower,
        "rare zone"
    ) then

        table.insert(
            commands,
            "goto rare zone"
        )
    elseif zone then
        table.insert(
            commands,
            "goto " .. zone
        )
    end

    if Contains(
        lower,
        "best"
    ) then

        table.insert(
            commands,
            "get bestValue "
            .. Safe(target)
        )
    else
        table.insert(
            commands,
            "get "
            .. Safe(target)
        )
    end

    if Contains(
        lower,
        "return"
    )
    or Contains(
        lower,
        "base"
    ) then

        table.insert(
            commands,
            "return to base"
        )
    end

    return table.concat(
        commands,
        " - "
    )
end

function AIPromptEng.Process(prompt)
    prompt = Safe(prompt)

    local intent, intentScore =
        DetectIntent(prompt)

    local target =
        DetectTarget(prompt)

    local value =
        ExtractNumber(prompt)

    local gui =
        DetectGUI(prompt)

    local rayfield =
        DetectRayfield(prompt)

    local action =
        "unknown"

    if intent == "set" then
        action = "setTarget"
    elseif intent == "add" then
        action = "addTarget"
    elseif intent == "remove" then
        action = "removeTarget"
    elseif intent == "find" then
        action = "findTarget"
    elseif intent == "autofarm" then
        action = "autofarm"
    elseif gui
        and intent == "create" then

        action = "createGUI"
    elseif intent == "create" then
        action = "create"
    end

    local matches =
        AIPromptEng.FindMatches(
            prompt,
            intent
        )

    local confidence = 20

    if intent ~= "unknown" then
        confidence = confidence + 25
    end

    if target ~= "unknown" then
        confidence = confidence + 20
    end

    if value then
        confidence = confidence + 10
    end

    if #matches > 0 then
        confidence = confidence + 25
    end

    if intentScore > 0 then
        confidence = confidence + 10
    end

    confidence = math.min(
        confidence,
        100
    )

    local parsed = {
        Prompt = prompt,
        Intent = intent,
        Action = action,
        Target = target,
        Subject = "me",
        Value = nil,
        AddingOf = nil,
        GUI = gui,
        Rayfield = rayfield,
        Matches = matches,
        MatchCount = #matches,
        Confidence = confidence
    }

    if intent == "set" then
        parsed.Value = value
    end

    if intent == "add" then
        parsed.AddingOf = value
    end

    if intent == "autofarm" then
        parsed.GUI = false

        parsed.Command =
            BuildAutofarmCommand(
                prompt,
                target,
                matches
            )
    end

    if confidence < 45 then
        table.insert(
            Database.Feedback,
            {
                Prompt = prompt,
                Parsed = parsed,
                Reason = "Low confidence"
            }
        )
    end

    table.insert(
        Database.History,
        parsed
    )

    if #Database.History > 250 then
        table.remove(
            Database.History,
            1
        )
    end

    local context = table.concat(
        {
            "INTENT="
                .. Safe(
                    parsed.Intent
                ),

            "ACTION="
                .. Safe(
                    parsed.Action
                ),

            "TARGET="
                .. Safe(
                    parsed.Target
                ),

            "SUBJECT="
                .. Safe(
                    parsed.Subject
                ),

            "VALUE_OF="
                .. Safe(
                    parsed.Value
                ),

            "ADDING_OF="
                .. Safe(
                    parsed.AddingOf
                ),

            "GUI="
                .. tostring(
                    parsed.GUI
                ),

            "RAYFIELD="
                .. tostring(
                    parsed.Rayfield
                ),

            "COMMAND="
                .. Safe(
                    parsed.Command
                ),

            "CONFIDENCE="
                .. tostring(
                    parsed.Confidence
                ),

            "MATCH_COUNT="
                .. tostring(
                    parsed.MatchCount
                )
        },
        "\n"
    )

    return parsed, context
end

function AIPromptEng.GetDatabase()
    return Database
end

function AIPromptEng.GetFeedback()
    return Database.Feedback
end

function AIPromptEng.GetHistory()
    return Database.History
end

function AIPromptEng.GetVocabulary()
    return Database.Vocabulary
end

function AIPromptEng.GetStats()
    return {
        Version = AIPromptEng.Version,
        Scripts = #Database.Scripts,
        Objects = #Database.Objects,
        Feedback = #Database.Feedback,
        History = #Database.History,
        Vocabulary = #GetWords(
            table.concat(
                (function()
                    local words = {}

                    for word in pairs(
                        Database.Vocabulary
                    ) do

                        table.insert(
                            words,
                            word
                        )
                    end

                    return words
                end)(),
                " "
            )
        )
    }
end

return AIPromptEng
