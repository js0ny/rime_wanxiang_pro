
--万象为了降低1位辅助码权重保证分词，提升2位辅助码权重为了4码高效，但是有些时候单字超越了词组，如自然码中：jmma 睑 剑麻，于是调序 剑麻 睑
--abbrev下根据辅助码提权匹配编码的单字
local M = {}

-- **获取辅助码**
function M.run_fuzhu(cand, env, initial_comment)
    local patterns = {
        tone = "([^;]*);",
        moqi = "[^;]*;([^;]*);",
        flypy = "[^;]*;[^;]*;([^;]*);",
        zrm = "[^;]*;[^;]*;[^;]*;([^;]*);",
        jdh = "[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);",
        cj = "[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);",
        tiger = "[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);",
        wubi = "[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);",
        hanxin = "[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;[^;]*;([^;]*);"
    }

    local pattern = patterns[env.settings.fuzhu_type]
    if not pattern then return {}, {} end

    local full_fuzhu_list = {}
    local first_fuzhu_list = {}

    for segment in initial_comment:gmatch("[^%s]+") do
        local match = segment:match(pattern)
        if match then
            for sub_match in match:gmatch("[^,]+") do
                table.insert(full_fuzhu_list, sub_match)
                local first_char = sub_match:sub(1, 1)
                if first_char and first_char ~= "" then
                    table.insert(first_fuzhu_list, first_char)
                end
            end
        end
    end

    return full_fuzhu_list, first_fuzhu_list
end

-- **初始化函数**
function M.init(env)
    local config = env.engine.schema.config
    env.settings = {
        fuzhu_type = config:get_string("pro_comment_format/fuzhu_type") or ""
    }
end

-- **判断是否为数字或字母**
local function is_alnum(text)
    return text:match("^[%w]+$") ~= nil
end

-- **主逻辑**
function M.func(input, env)
    local context = env.engine.context
    local input_code = context.input
    local input_len = utf8.len(input_code)

    -- **只有当输入码长度为 3 或 4 时才处理**
    if input_len < 3 or input_len > 4 then
        for cand in input:iter() do
            yield(cand)
        end
        return
    end

    local single_char_cands = {}
    local alnum_cands = {}
    local other_cands = {}

    -- **获取输入码的最后 2 个字符**
    local last_two_chars = input_code:sub(-2)
    local last_one_char = input_code:sub(-1)

    -- **读取所有候选词**
    for cand in input:iter() do
        local len = utf8.len(cand.text)
        if is_alnum(cand.text) then
            table.insert(alnum_cands, cand) -- **存储双字汉字**
        elseif len == 1 and not is_alnum(cand.text) then
            table.insert(single_char_cands, cand) -- **存储单字**
        else
            table.insert(other_cands, cand) -- **存储字母/数字/其他**
        end
    end

    -- **处理单字排序逻辑**
    local reordered_singles = {}
    local moved_singles = {}

    for _, cand in ipairs(single_char_cands) do
        local full_fuzhu_list, first_fuzhu_list = M.run_fuzhu(cand, env, cand.comment or "")

        local matched = false
        if input_len == 4 then
            for _, segment in ipairs(full_fuzhu_list) do
                if segment == last_two_chars then
                    matched = true
                    break
                end
            end
        elseif input_len == 3 then
            for _, segment in ipairs(first_fuzhu_list) do
                if segment == last_one_char then
                    matched = true
                    break
                end
            end
        end

        if matched then
            table.insert(moved_singles, cand)
        else
            table.insert(reordered_singles, cand)
        end
    end

    -- **输入长度为 3 时，调整顺序**
    if input_len == 3 then
        -- **先输出其他汉字汉字**
        for _, cand in ipairs(other_cands) do
            yield(cand)
        end

        -- **然后输出匹配的单字**
        for _, cand in ipairs(moved_singles) do
            yield(cand)
        end

        -- **再输出未匹配的单字**
        for _, cand in ipairs(reordered_singles) do
            yield(cand)
        end

        -- **最后输出其他候选（字母/数字等）**
        for _, cand in ipairs(alnum_cands) do
            yield(cand)
        end
        return
    end

    -- **输入长度为 4 时，按原顺序**
    if input_len == 4 then
        for _, cand in ipairs(other_cands) do
            yield(cand)
        end
        for _, cand in ipairs(moved_singles) do
            yield(cand)
        end
        for _, cand in ipairs(reordered_singles) do
            yield(cand)
        end
        for _, cand in ipairs(alnum_cands) do
            yield(cand)
        end
    end
end

return M
