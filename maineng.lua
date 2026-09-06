--========================================================--
-- AIPromptEng
-- File: maineng.lua
--
-- Prompt understanding engine for LuaCoderAI.
-- Understands common English requests and matches them
-- against registered script/file metadata.
--========================================================--

local AIPromptEng = {}

--========================================================--
-- CONFIGURATION
--========================================================--

AIPromptEng.ScriptIndex = {}

AIPromptEng.Synonyms = {

    -- Actions
    give = {
        "give",
        "get",
        "add",
        "grant",
        "put",
        "make me",
        "give me",
        "get me"
    },

    set = {
        "set",
        "change",
        "make",
        "update",
        "put my",
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
