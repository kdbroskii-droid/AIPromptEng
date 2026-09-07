local AIPromptEng = {}

AIPromptEng.Version = "7.0"

local Database = {
Scripts = {},
Objects = {},
Vocabulary = {},
Feedback = {},
History = {},
Aliases = {},
Categories = {}
}

local StopWords = {
the = true,
a = true,
an = true,
to = true,
me = true,
my = true,
and = true,
["or"] = true,
["in"] = true,
["on"] = true,
with = true,
of = true,
it = true,
this = true,
that = true,
please = true
}

StopWords["for"] = true

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
    "hitpoints"
},

speed = {
    "speed",
    "walkspeed",
    "walk speed"
},

inventory = {
    "inventory",
    "items",
    "backpack",
    "storage"
},

experience = {
    "experience",
    "xp"
}

}

local function Safe(value)
if value == nil then
return ""
end

return tostring(value)

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
local normalizedText = Normalize(text)
local normalizedSearch = Normalize(search)

if normalizedSearch == "" then
    return false
end

return string.find(
    normalizedText,
    normalizedSearch,
    1,
    true
) ~= nil

end

local function GetWords(text)
local words = {}
local used = {}
local normalized = Normalize(text)

for word in normalized:gmatch("%S+") do
    if not StopWords[word] and #word > 1 and not used[word] then
        used[word] = true
        table.insert(words, word)
    end
end

return words

end

local function LearnText(text)
local words = GetWords(text)

for _, word in ipairs(words) do
    Database.Vocabulary[word] =
        (Database.Vocabulary[word] or 0) + 1
end

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

local function GetCategory(instance)
if instance:IsA("LocalScript") then
return "LocalScripts"
elseif instance:IsA("ModuleScript") then
return "ModuleScripts"
elseif instance:IsA("Script") then
return "Scripts"
elseif instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") then
return "Remotes"
elseif instance:IsA("IntValue")
or instance:IsA("NumberValue")
or instance:IsA("BoolValue")
or instance:IsA("StringValue")
or instance:IsA("ObjectValue") then
return "Values"
elseif instance:IsA("Folder") then
return "Folders"
elseif instance:IsA("Tool") then
return "Tools"
elseif instance:IsA("Model") then
return "Models"
elseif instance:IsA("ScreenGui")
or instance:IsA("Frame")
or instance:IsA("TextButton")
or instance:IsA("TextLabel")
or instance:IsA("TextBox")
or instance:IsA("ImageButton") then
return "UI"
end

return "Other"

end

local function IsCheckpoint(instance)
local name = Normalize(instance.Name)

local checkpointWords = {
    "checkpoint",
    "waypoint",
    "zone",
    "spawn",
    "destination",
    "base"
}

for _, word in ipairs(checkpointWords) do
    if Contains(name, word) then
        return true
    end
end

return false

end

local function CreateObjectInfo(instance)
if instance:IsA("BasePart") and not IsCheckpoint(instance) then
return nil
end

local category = GetCategory(instance)

if instance:IsA("BasePart") and IsCheckpoint(instance) then
    category = "Checkpoints"
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

local path = Safe(info.Path or info.Name)

for _, existing in ipairs(Database.Objects) do
    local existingPath = Safe(existing.Path or existing.Name)

    if existingPath == path then
        return false
    end
end

table.insert(Database.Objects, info)

local category = Safe(info.Category)

if Database.Categories[category] == nil then
    Database.Categories[category] = {}
end

table.insert(Database.Categories[category], info)

if category == "Scripts"
    or category == "LocalScripts"
    or category == "ModuleScripts" then

    table.insert(Database.Scripts, info)
end

LearnText(info.Name)
LearnText(info.Path)
LearnText(info.ClassName)

return true

end

local function DetectIntent(prompt)
if Contains(prompt, "autofarm")
or Contains(prompt, "auto farm")
or Contains(prompt, "farm for me") then
return "autofarm"
end

if Contains(prompt, "give")
    or Contains(prompt, "add")
    or Contains(prompt, "increase")
    or Contains(prompt, "grant") then
    return "add"
end

if Contains(prompt, "set")
    or Contains(prompt, "change")
    or Contains(prompt, "update") then
    return "set"
end

if Contains(prompt, "remove")
    or Contains(prompt, "take")
    or Contains(prompt, "subtract") then
    return "remove"
end

if Contains(prompt, "find")
    or Contains(prompt, "search")
    or Contains(prompt, "locate") then
    return "find"
end

if Contains(prompt, "create")
    or Contains(prompt, "make")
    or Contains(prompt, "build") then
    return "create"
end

return "unknown"

end

local function DetectTarget(prompt)
for target, aliases in pairs(TargetAliases) do
for _, alias in ipairs(aliases) do
if Contains(prompt, alias) then
return target
end
end
end

for alias, target in pairs(Database.Aliases) do
    if Contains(prompt, alias) then
        return target
    end
end

local words = GetWords(prompt)

for _, word in ipairs(words) do
    if Database.Vocabulary[word] then
        return word
    end
end

return "unknown"

end

local function ExtractNumber(prompt)
local number = string.match(Safe(prompt), "(%d[%d,]*)")

if number then
    return number:gsub(",", "")
end

return nil

end

local function DetectGUI(prompt)
return Contains(prompt, "gui")
or Contains(prompt, "ui")
or Contains(prompt, "button")
or Contains(prompt, "menu")
end

local function DetectRayfield(prompt)
return Contains(prompt, "rayfield")
end

local function ScoreMatch(query, info)
local score = 0
local name = Normalize(info.Name)
local path = Normalize(info.Path)
local queryWords = GetWords(query)

for _, word in ipairs(queryWords) do
    if Contains(name, word) then
        score = score + 100
    end

    if Contains(path, word) then
        score = score + 40
    end
end

return score

end

function AIPromptEng.FindMatches(query, intent)
local results = {}

for _, info in ipairs(Database.Objects) do
    local score = ScoreMatch(query, info)

    if intent == "autofarm"
        and info.Category == "Checkpoints" then
        score = score + 30
    end

    if score > 0 then
        table.insert(results, {
            Score = score,
            Object = info,
            Script = info
        })
    end
end

table.sort(results, function(a, b)
    return a.Score > b.Score
end)

return results

end

function AIPromptEng.ClearScripts()
Database.Scripts = {}
end

function AIPromptEng.ClearGameIndex()
Database.Scripts = {}
Database.Objects = {}
Database.Vocabulary = {}
Database.Categories = {}
end

function AIPromptEng.RegisterScript(info)
if type(info) ~= "table" then
return false
end

if info.Category == nil then
    info.Category = "Scripts"
end

return AddObject(info)

end

function AIPromptEng.RegisterGameObject(info)
return AddObject(info)
end

function AIPromptEng.RegisterObject(info)
return AddObject(info)
end

function AIPromptEng.LearnAlias(alias, target)
alias = Normalize(alias)
target = Normalize(target)

if alias == "" or target == "" then
    return false
end

Database.Aliases[alias] = target

return true

end

function AIPromptEng.AddFeedback(prompt, correctIntent, correctTarget)
local feedback = {
Prompt = Safe(prompt),
Intent = Safe(correctIntent),
Target = Safe(correctTarget)
}

table.insert(Database.Feedback, feedback)

if correctTarget and correctTarget ~= "" then
    local words = GetWords(prompt)

    for _, word in ipairs(words) do
        Database.Aliases[word] = Normalize(correctTarget)
    end
end

return feedback

end

function AIPromptEng.ScanReplicatedGame()
AIPromptEng.ClearGameIndex()

local success, descendants = pcall(function()
    return game:GetDescendants()
end)

if not success then
    return {}, 0
end

local indexed = {}

for _, instance in ipairs(descendants) do
    local successInfo, info = pcall(CreateObjectInfo, instance)

    if successInfo and info then
        if AddObject(info) then
            table.insert(indexed, info)
        end
    end
end

return indexed, #indexed

end

function AIPromptEng.Process(prompt)
prompt = Safe(prompt)

local intent = DetectIntent(prompt)
local target = DetectTarget(prompt)
local value = ExtractNumber(prompt)
local gui = DetectGUI(prompt)
local rayfield = DetectRayfield(prompt)

local action = "unknown"

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
elseif intent == "create" then
    action = "create"
end

local matches = AIPromptEng.FindMatches(prompt, intent)

local confidence = 20

if intent ~= "unknown" then
    confidence = confidence + 30
end

if target ~= "unknown" then
    confidence = confidence + 25
end

if value then
    confidence = confidence + 10
end

if #matches > 0 then
    confidence = confidence + 15
end

if confidence > 100 then
    confidence = 100
end

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
    Confidence = confidence,
    Command = ""
}

if intent == "set" then
    parsed.Value = value
end

if intent == "add" then
    parsed.AddingOf = value
end

if intent == "autofarm" then
    parsed.GUI = false

    local commandParts = {}

    if Contains(prompt, "rare zone") then
        table.insert(commandParts, "goto rare zone")
    end

    if Contains(prompt, "best") then
        table.insert(
            commandParts,
            "get bestValue " .. Safe(target)
        )
    else
        table.insert(
            commandParts,
            "get " .. Safe(target)
        )
    end

    if Contains(prompt, "return")
        or Contains(prompt, "base") then
        table.insert(commandParts, "return to base")
    end

    parsed.Command = table.concat(commandParts, " - ")
end

if confidence < 40 then
    table.insert(Database.Feedback, {
        Prompt = prompt,
        Parsed = parsed,
        Reason = "Low confidence"
    })
end

table.insert(Database.History, parsed)

local contextLines = {
    "INTENT=" .. Safe(parsed.Intent),
    "ACTION=" .. Safe(parsed.Action),
    "TARGET=" .. Safe(parsed.Target),
    "SUBJECT=" .. Safe(parsed.Subject),
    "VALUE_OF=" .. Safe(parsed.Value),
    "ADDING_OF=" .. Safe(parsed.AddingOf),
    "GUI=" .. tostring(parsed.GUI),
    "RAYFIELD=" .. tostring(parsed.Rayfield),
    "COMMAND=" .. Safe(parsed.Command),
    "CONFIDENCE=" .. tostring(parsed.Confidence),
    "MATCH_COUNT=" .. tostring(parsed.MatchCount)
}

local context = table.concat(contextLines, "\n")

return parsed, context

end

function AIPromptEng.GetStats()
local vocabularyCount = 0

for _ in pairs(Database.Vocabulary) do
    vocabularyCount = vocabularyCount + 1
end

return {
    Version = AIPromptEng.Version,
    Scripts = #Database.Scripts,
    Objects = #Database.Objects,
    Feedback = #Database.Feedback,
    History = #Database.History,
    Vocabulary = vocabularyCount
}

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

return AIPromptEng
