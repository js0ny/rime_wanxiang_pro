
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
    if not pattern then return {}, {} end  -- **返回两个空表**

    local full_fuzhu_list = {}   -- **存储完整的辅助码片段**
    local first_fuzhu_list = {}  -- **存储每个片段的第一位**

    for segment in initial_comment:gmatch("[^%s]+") do
        local match = segment:match(pattern)
        if match then
            -- **处理 `,` 分割的多个辅助码**
            for sub_match in match:gmatch("[^,]+") do
                table.insert(full_fuzhu_list, sub_match) -- **存储完整辅助码**
                local first_char = sub_match:sub(1, 1)   -- **获取首字母**
                if first_char and first_char ~= "" then
                    table.insert(first_fuzhu_list, first_char) -- **存储片段的第一位**
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
    local input_code = context.input -- **获取输入码**
    local input_len = utf8.len(input_code)

    -- **只有当输入码长度为 3 或 4 时才处理**
    if input_len < 3 or input_len > 4 then
        for cand in input:iter() do
            yield(cand) -- **直接按原顺序输出**
        end
        return
    end

    local single_char_cands = {} -- **存储单字候选**
    local other_cands = {}  -- **存储其他所有候选词（包括长度 ≥ 2）**

    -- **获取输入码的最后 2 个字符**
    local last_two_chars = input_code:sub(-2)
    local last_one_char = input_code:sub(-1)

    -- **读取所有候选词**
    for cand in input:iter() do
        local len = utf8.len(cand.text)
        if len == 1 and not is_alnum(cand.text) then
            table.insert(single_char_cands, cand)  -- **存储单字（排除字母、数字）**
        else
            table.insert(other_cands, cand)  -- **存储所有非单字候选词**
        end
    end

    -- **处理单字的排序逻辑**
    local reordered_singles = {}
    local moved_singles = {}  -- **存储所有匹配的单字**

    for _, cand in ipairs(single_char_cands) do
        -- **获取完整辅助码列表和首字母列表**
        local full_fuzhu_list, first_fuzhu_list = M.run_fuzhu(cand, env, cand.comment or "")

        -- **匹配逻辑**
        local matched = false
        if input_len == 4 then
            -- **4 码输入时，匹配完整辅助码**
            for _, segment in ipairs(full_fuzhu_list) do
                if segment == last_two_chars then
                    matched = true
                    break
                end
            end
        elseif input_len == 3 then
            -- **3 码输入时，匹配辅助码的第一位**
            for _, segment in ipairs(first_fuzhu_list) do
                if segment == last_one_char then
                    matched = true
                    break
                end
            end
        end

        if matched then
            table.insert(moved_singles, cand) -- **存入所有匹配的单字**
        else
            table.insert(reordered_singles, cand)
        end
    end

    -- **先输出所有非单字候选词**
    for _, cand in ipairs(other_cands) do
        yield(cand)
    end

    -- **然后输出所有匹配的单字**
    for _, cand in ipairs(moved_singles) do
        yield(cand)
    end

    -- **最后输出剩余的单字**
    for _, cand in ipairs(reordered_singles) do
        yield(cand)
    end
end

return M