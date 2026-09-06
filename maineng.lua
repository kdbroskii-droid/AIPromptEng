local AIPromptEng = {}

AIPromptEng.ScriptIndex = {}
AIPromptEng.Feedback = {}
AIPromptEng.LearnedTerms = {}
AIPromptEng.Version = 2

AIPromptEng.Actions = {
    create = {"create", "make", "build", "spawn", "generate", "add"},
    find = {"find", "search", "locate", "look for", "get", "show"},
    modify = {"change", "modify", "edit", "adjust", "alter", "update"},
    set = {"set", "assign", "put", "replace"},
    increase = {"increase", "raise", "boost", "more", "faster", "higher"},
    decrease = {"decrease", "lower", "reduce", "less", "slower"},
    remove = {"remove", "delete", "destroy", "clear"},
    test = {"test", "debug", "check", "try", "simulate"},
    enable = {"enable", "turn on", "activate", "start"},
    disable = {"disable", "turn off", "deactivate", "stop"},
    move = {"move", "teleport", "travel", "go"},
    collect = {"collect", "pickup", "gather"},
    interact = {"interact", "use", "click", "activate"},
    target = {"target", "track", "follow", "focus"},
    automate = {"auto", "automatic", "automate", "autofarm", "auto farm"},
    connect = {"connect", "link", "join"},
    copy = {"copy", "duplicate", "clone"},
    inspect = {"inspect", "analyze", "analyse", "examine"}
}

AIPromptEng.Targets = {
    money = {"money", "cash", "coins", "coin", "currency", "gold", "balance", "wallet"},
    player = {"player", "players", "character", "user"},
    npc = {"npc", "npcs", "bot", "bots", "enemy", "enemies"},
    item = {"item", "items", "pickup", "collectible", "loot"},
    inventory = {"inventory", "bag", "storage"},
    weapon = {"weapon", "gun", "tool", "projectile"},
    ball = {"ball", "balls"},
    pet = {"pet", "pets"},
    vehicle = {"car", "vehicle", "vehicles"},
    round = {"round", "match", "game"},
    role = {"role", "roles", "team", "teams"},
    health = {"health", "hp", "hitpoints"},
    speed = {"speed", "walkspeed", "walk speed"},
    jump = {"jump", "jumppower", "jump power"},
    position = {"position", "location", "place"},
    gui = {"gui", "ui", "interface", "menu", "button"},
    script = {"script", "scripts", "file", "files", "module"},
    event = {"event", "events", "signal"},
    remote = {"remote", "remotes", "remoteevent", "remotefunction"},
    folder = {"folder", "directory"},
    model = {"model", "models"},
    part = {"part", "object", "instance"},
    camera = {"camera", "view"},
    npc_test = {"target test", "bot test", "aim test", "combat test"}
}

AIPromptEng.Properties = {
    speed = {"speed", "fast", "faster", "slow", "slower", "velocity"},
    health = {"health", "hp", "damage", "heal"},
    amount = {"amount", "number", "count", "quantity"},
    position = {"position", "location", "place"},
    size = {"size", "scale", "bigger", "smaller"},
    color = {"color", "colour"},
    transparency = {"transparency", "visible", "invisible"},
    enabled = {"enabled", "enable", "disabled", "disable"},
    value = {"value", "number", "amount"},
    name = {"name", "rename"},
    target = {"target", "focus", "track"},
    cooldown = {"cooldown", "delay", "wait"},
    range = {"range", "distance"},
    damage = {"damage", "power"}
}

local function normalize(text)
    text = string.lower(tostring(text or ""))
    text = text:gsub("[%p]", " ")
    text = text:gsub("%s+", " ")
    return text:match("^%s*(.-)%s*$")
end

local function words(text)
    local result = {}
    for word in string.gmatch(normalize(text), "%S+") do
        table.insert(result, word)
    end
    return result
end

local function contains(text, phrase)
    return string.find(text, phrase, 1, true) ~= nil
end

local function levenshtein(a, b)
    a = tostring(a or "")
    b = tostring(b or "")

    local matrix = {}

    for i = 0, #a do
        matrix[i] = {[0] = i}
    end

    for j = 0, #b do
        matrix[0][j] = j
    end

    for i = 1, #a do
        for j = 1, #b do
            local cost = a:sub(i, i) == b:sub(j, j) and 0 or 1

            matrix[i][j] = math.min(
                matrix[i - 1][j] + 1,
                matrix[i][j - 1] + 1,
                matrix[i - 1][j - 1] + cost
            )
        end
    end

    return matrix[#a][#b]
end

local function similarity(a, b)
    a = normalize(a)
    b = normalize(b)

    if a == b then
        return 100
    end

    if a == "" or b == "" then
        return 0
    end

    if contains(a, b) or contains(b, a) then
        return 90
    end

    local distance = levenshtein(a, b)
    local length = math.max(#a, #b)

    return math.max(
        0,
        math.floor((1 - distance / length) * 100)
    )
end

local function detectFromGroups(prompt, groups)
    local bestName = "unknown"
    local bestScore = 0

    for name, aliases in pairs(groups) do
        for _, alias in ipairs(aliases) do
            if contains(prompt, alias) then
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

    table.insert(AIPromptEng.ScriptIndex, {
        Name = tostring(data.Name or ""),
        Path = tostring(data.Path or data.Name or ""),
        ClassName = tostring(data.ClassName or ""),
        Tags = data.Tags or {},
        API = data.API or {}
    })

    return true
end

function AIPromptEng.RegisterScripts(list)
    local count = 0

    for _, item in ipairs(list or {}) do
        if AIPromptEng.RegisterScript(item) then
            count += 1
        end
    end

    return count
end

function AIPromptEng.GetNumber(prompt)
    local value = string.match(
        tostring(prompt or ""),
        "%-?%d+%.?%d*"
    )

    return value and tonumber(value) or nil
end

function AIPromptEng.FindMatches(prompt)
    local queryWords = words(prompt)
    local matches = {}

    for _, entry in ipairs(AIPromptEng.ScriptIndex) do
        local score = 0
        local name = normalize(entry.Name)
        local path = normalize(entry.Path)

        for _, queryWord in ipairs(queryWords) do
            if #queryWord >= 3 then
                local nameScore = similarity(queryWord, name)
                local pathScore = similarity(queryWord, path)

                score += math.max(nameScore, pathScore) / 2

                for _, tag in ipairs(entry.Tags or {}) do
                    score += similarity(queryWord, tag) / 2
                end
            end
        end

        for _, learned in ipairs(AIPromptEng.LearnedTerms[normalize(prompt)] or {}) do
            if learned == entry.Path then
                score += 100
            end
        end

        if score > 0 then
            table.insert(matches, {
                Script = entry,
                Score = math.floor(score)
            })
        end
    end

    table.sort(matches, function(a, b)
        return a.Score > b.Score
    end)

    return matches
end

function AIPromptEng.AddFeedback(prompt, reason, unknownTerms)
    table.insert(AIPromptEng.Feedback, {
        Prompt = tostring(prompt or ""),
        Reason = tostring(reason or "UNKNOWN"),
        UnknownTerms = unknownTerms or {},
        Time = os.time()
    })
end

function AIPromptEng.Learn(prompt, selectedPath)
    local key = normalize(prompt)

    AIPromptEng.LearnedTerms[key] =
        AIPromptEng.LearnedTerms[key] or {}

    table.insert(
        AIPromptEng.LearnedTerms[key],
        tostring(selectedPath)
    )

    return true
end

function AIPromptEng.GetFeedback()
    return AIPromptEng.Feedback
end

function AIPromptEng.Parse(prompt)
    local original = tostring(prompt or "")
    local clean = normalize(original)

    local intent = detectFromGroups(clean, AIPromptEng.Actions)
    local target = detectFromGroups(clean, AIPromptEng.Targets)
    local property = detectFromGroups(clean, AIPromptEng.Properties)

    local value = AIPromptEng.GetNumber(clean)
    local matches = AIPromptEng.FindMatches(clean)

    local unknownTerms = {}

    if target == "unknown" then
        for _, word in ipairs(words(clean)) do
            if #word >= 4 then
                table.insert(unknownTerms, word)
            end
        end
    end

    local confidence = 0

    if intent ~= "unknown" then
        confidence += 25
    end

    if target ~= "unknown" then
        confidence += 25
    end

    if property ~= "unknown" then
        confidence += 15
    end

    if #matches > 0 then
        confidence += math.min(35, matches[1].Score)
    end

    confidence = math.min(100, confidence)

    local result = {
        Version = AIPromptEng.Version,
        OriginalPrompt = original,
        Prompt = clean,
        Intent = intent,
        Action = intent,
        Target = target,
        Property = property,
        Value = value,
        Subject = contains(clean, " me ") and "self" or "unknown",
        Matches = matches,
        MatchCount = #matches,
        Confidence = confidence,
        UnknownTerms = unknownTerms,
        FeedbackNeeded = confidence < 50 or #unknownTerms > 0
    }

    if result.FeedbackNeeded then
        AIPromptEng.AddFeedback(
            original,
            "LOW_CONFIDENCE_OR_UNKNOWN_TERMS",
            unknownTerms
        )
    end

    return result
end

function AIPromptEng.BuildContext(parsed)
    local lines = {
        "AIPROMPTENG_TRANSLATED_REQUEST",
        "INTENT=" .. tostring(parsed.Intent),
        "ACTION=" .. tostring(parsed.Action),
        "TARGET=" .. tostring(parsed.Target),
        "PROPERTY=" .. tostring(parsed.Property),
        "VALUE=" .. tostring(parsed.Value),
        "SUBJECT=" .. tostring(parsed.Subject),
        "CONFIDENCE=" .. tostring(parsed.Confidence),
        "ORIGINAL=" .. tostring(parsed.OriginalPrompt),
        "MATCHES="
    }

    for _, match in ipairs(parsed.Matches or {}) do
        local info = match.Script

        table.insert(
            lines,
            tostring(match.Score)
                .. "|"
                .. tostring(info.Path)
        )
    end

    return table.concat(lines, "\n")
end

function AIPromptEng.Process(prompt)
    local parsed = AIPromptEng.Parse(prompt)
    local context = AIPromptEng.BuildContext(parsed)

    return parsed, context
end

return AIPromptEng        "put my",
        "change my"
    },

    find = {
        "find",
        "look for",
        "search",
        "show",
        "locate",
        "where is",
        "where are"
    },

    create = {
        "create",
        "make",
        "build",
        "spawn",
        "add"
    },

    automate = {
        "auto",
        "automatically",
        "autofarm",
        "auto farm",
        "auto collect",
        "farm"
    },

    -- Targets
    money = {
        "money",
        "cash",
        "coin",
        "coins",
        "currency",
        "gold",
        "balance",
        "wallet",
        "economy"
    },

    brainrot = {
        "brainrot",
        "brainrots"
    },

    pet = {
        "pet",
        "pets"
    },

    base = {
        "base",
        "bases",
        "home",
        "house"
    },

    plot = {
        "plot",
        "plots",
        "farm plot",
        "land"
    },

    item = {
        "item",
        "items",
        "collectible",
        "collectibles",
        "pickup",
        "pickups"
    },

    player = {
        "player",
        "players",
        "me",
        "myself",
        "character"
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

    jump = {
        "jump",
        "jump power",
        "jumppower"
    }

}

--========================================================--
-- NORMALIZE PROMPT
--========================================================--

function AIPromptEng.Normalize(prompt)

    prompt = tostring(prompt or "")

    prompt = string.lower(prompt)

    -- Remove repeated spaces
    prompt = prompt:gsub("%s+", " ")

    -- Remove basic punctuation
    prompt = prompt:gsub("[%.%,%!%?]", "")

    -- Trim spaces
    prompt = prompt:match("^%s*(.-)%s*$")

    return prompt

end

--========================================================--
-- REGISTER SCRIPT / FILE
--========================================================--

function AIPromptEng.RegisterScript(data)

    if type(data) ~= "table" then
        return false
    end

    local entry = {
        Name = tostring(data.Name or ""),
        Path = tostring(data.Path or ""),
        ClassName = tostring(data.ClassName or "Script"),
        Tags = data.Tags or {}
    }

    table.insert(
        AIPromptEng.ScriptIndex,
        entry
    )

    return true

end

--========================================================--
-- REGISTER MANY SCRIPTS
--========================================================--

function AIPromptEng.RegisterScripts(list)

    if type(list) ~= "table" then
        return 0
    end

    local count = 0

    for _, data in ipairs(list) do

        if AIPromptEng.RegisterScript(data) then
            count += 1
        end

    end

    return count

end

--========================================================--
-- CLEAR SCRIPT INDEX
--========================================================--

function AIPromptEng.ClearScripts()

    AIPromptEng.ScriptIndex = {}

end

--========================================================--
-- GET NUMBER
--========================================================--

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

--========================================================--
-- CONTAINS PHRASE
--========================================================--

function AIPromptEng.Contains(text, phrase)

    return string.find(
        text,
        phrase,
        1,
        true
    ) ~= nil

end

--========================================================--
-- FIND CATEGORY
--========================================================--

function AIPromptEng.FindCategory(
    prompt,
    category
)

    local words =
        AIPromptEng.Synonyms[category]

    if not words then
        return false
    end

    for _, word in ipairs(words) do

        if AIPromptEng.Contains(
            prompt,
            word
        ) then

            return true, word

        end

    end

    return false

end

--========================================================--
-- DETECT ACTION
--========================================================--

function AIPromptEng.DetectAction(prompt)

    local actions = {
        "automate",
        "find",
        "give",
        "set",
        "create"
    }

    for _, action in ipairs(actions) do

        local found =
            AIPromptEng.FindCategory(
                prompt,
                action
            )

        if found then
            return action
        end

    end

    return "unknown"

end

--========================================================--
-- DETECT TARGET
--========================================================--

function AIPromptEng.DetectTarget(prompt)

    local targets = {
        "money",
        "brainrot",
        "pet",
        "base",
        "plot",
        "item",
        "health",
        "speed",
        "jump",
        "player"
    }

    for _, target in ipairs(targets) do

        local found =
            AIPromptEng.FindCategory(
                prompt,
                target
            )

        if found then
            return target
        end

    end

    return "unknown"

end

--========================================================--
-- SCORE A SCRIPT MATCH
--========================================================--

function AIPromptEng.ScoreScript(
    scriptInfo,
    keywords
)

    local score = 0

    local text =
        string.lower(
            tostring(scriptInfo.Name)
            .. " "
            .. tostring(scriptInfo.Path)
            .. " "
            .. tostring(scriptInfo.ClassName)
        )

    for _, keyword in ipairs(keywords) do

        keyword =
            string.lower(keyword)

        if string.find(
            text,
            keyword,
            1,
            true
        ) then

            score += 10

        end

    end

    for _, tag in ipairs(
        scriptInfo.Tags or {}
    ) do

        local tagText =
            string.lower(
                tostring(tag)
            )

        for _, keyword in ipairs(
            keywords
        ) do

            if tagText == string.lower(keyword) then

                score += 20

            end

        end

    end

    return score

end

--========================================================--
-- GET SEARCH WORDS
--========================================================--

function AIPromptEng.GetKeywords(
    action,
    target,
    prompt
)

    local keywords = {}

    -- Target synonyms
    if AIPromptEng.Synonyms[target] then

        for _, word in ipairs(
            AIPromptEng.Synonyms[target]
        ) do

            table.insert(
                keywords,
                word
            )

        end

    end

    -- Action synonyms
    if AIPromptEng.Synonyms[action] then

        for _, word in ipairs(
            AIPromptEng.Synonyms[action]
        ) do

            table.insert(
                keywords,
                word
            )

        end

    end

    -- Add words from prompt
    for word in string.gmatch(
        prompt,
        "%S+"
    ) do

        if #word >= 3 then

            table.insert(
                keywords,
                word
            )

        end

    end

    return keywords

end

--========================================================--
-- FIND RELEVANT SCRIPTS
--========================================================--

function AIPromptEng.FindScripts(
    keywords
)

    local results = {}

    for _, scriptInfo in ipairs(
        AIPromptEng.ScriptIndex
    ) do

        local score =
            AIPromptEng.ScoreScript(
                scriptInfo,
                keywords
            )

        if score > 0 then

            table.insert(
                results,
                {
                    Score = score,
                    Script = scriptInfo
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

--========================================================--
-- BUILD MATCH SUMMARY
--========================================================--

function AIPromptEng.FormatMatches(
    matches
)

    local lines = {}

    for _, result in ipairs(matches) do

        local info =
            result.Script

        table.insert(
            lines,

            "["
            .. tostring(result.Score)
            .. "] "
            .. tostring(info.Path)

        )

    end

    if #lines == 0 then
        return "No matching scripts found."
    end

    return table.concat(
        lines,
        "\n"
    )

end

--========================================================--
-- PARSE PROMPT
--========================================================--

function AIPromptEng.Parse(prompt)

    local normalized =
        AIPromptEng.Normalize(
            prompt
        )

    local action =
        AIPromptEng.DetectAction(
            normalized
        )

    local target =
        AIPromptEng.DetectTarget(
            normalized
        )

    local value =
        AIPromptEng.GetNumber(
            normalized
        )

    local keywords =
        AIPromptEng.GetKeywords(
            action,
            target,
            normalized
        )

    local matches =
        AIPromptEng.FindScripts(
            keywords
        )

    return {

        OriginalPrompt =
            tostring(prompt or ""),

        Prompt =
            normalized,

        Action =
            action,

        Target =
            target,

        Value =
            value,

        Keywords =
            keywords,

        Matches =
            matches,

        MatchCount =
            #matches

    }

end

--========================================================--
-- FORMAT FOR LuaCoderAI
--========================================================--

function AIPromptEng.BuildContext(
    parsed
)

    local lines = {

        "-- AIPromptEng Context",

        "Prompt: "
        .. tostring(
            parsed.OriginalPrompt
        ),

        "Action: "
        .. tostring(
            parsed.Action
        ),

        "Target: "
        .. tostring(
            parsed.Target
        )

    }

    if parsed.Value then

        table.insert(
            lines,

            "Value: "
            .. tostring(
                parsed.Value
            )
        )

    end

    table.insert(
        lines,
        ""
    )

    table.insert(
        lines,
        "-- Relevant Scripts"
    )

    for _, match in ipairs(
        parsed.Matches
    ) do

        local scriptInfo =
            match.Script

        table.insert(
            lines,

            tostring(
                scriptInfo.Path
            )

        )

    end

    return table.concat(
        lines,
        "\n"
    )

end

--========================================================--
-- PROCESS
-- Parse + Build Context
--========================================================--

function AIPromptEng.Process(prompt)

    local parsed =
        AIPromptEng.Parse(
            prompt
        )

    local context =
        AIPromptEng.BuildContext(
            parsed
        )

    return parsed, context

end

--========================================================--
-- RETURN ENGINE
--========================================================--

return AIPromptEng
