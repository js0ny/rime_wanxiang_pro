
--万象为了降低1位辅助码权重保证分词，提升2位辅助码权重为了4码高效，但是有些时候单字超越了词组，如自然码中：jmma 睑 剑麻，于是调序 剑麻 睑
--abbrev下根据辅助码提权匹配编码的单字
local M = {}
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
    if not pattern then return "" end

    local matches = {}
    for segment in initial_comment:gmatch("[^%s]+") do
        local match = segment:match(pattern)
        if match then table.insert(matches, match) end
    end

    return #matches > 0 and table.concat(matches, ",") or ""
end

-- **初始化函数，确保 `env.settings` 先初始化**
function M.init(env)
    local config = env.engine.schema.config
    env.settings = {
        fuzhu_type = config:get_string("pro_comment_format/fuzhu_type") or ""
    }
end

function M.func(input, env)
    local context = env.engine.context
    local input_code = context.input -- 获取输入码

    -- 只有当输入码长度等于 4 时才处理
    if utf8.len(input_code) ~= 4 then
        for cand in input:iter() do
            yield(cand) -- 直接按原顺序输出
        end
        return
    end

    local candidates = {} -- 存储前 10 个符合条件的候选词
    local others = {} -- 存储剩余的候选词
    local single_char_cands = {} -- 存储单字候选
    local double_char_cands = {} -- 存储双字候选

    -- 判断是否是数字或字母
    local function is_alnum(text)
        return text:match("^[%w]+$") ~= nil
    end

    -- **修改 `get_comment()`，使用 `M.run_fuzhu()` 获取辅助码**
    local function get_comment(cand, env)
        return M.run_fuzhu(cand, env, cand.comment or "")
    end

    -- 获取输入码的后两个字符
    local last_two_chars = input_code:sub(-2)

    -- 读取所有候选词
    local count = 0
    for cand in input:iter() do
        local len = utf8.len(cand.text)

        if len == 2 and not is_alnum(cand.text) then
            if count < 10 then
                table.insert(double_char_cands, cand) -- 只存前 10 个双字词
            else
                table.insert(others, cand) -- 超过 10 个的，按原顺序放入 others
            end
            count = count + 1
        elseif len == 1 and not is_alnum(cand.text) then
            table.insert(single_char_cands, cand) -- 存储单字
        else
            table.insert(others, cand) -- 不符合长度要求或是字母/数字的，按原顺序存储
        end
    end

    -- 处理单字的排序逻辑
    local reordered_singles = {}
    local moved_single = nil

    for _, cand in ipairs(single_char_cands) do
        local comment = get_comment(cand, env) -- **调用 `M.run_fuzhu()` 解析辅助码**
        if comment == last_two_chars then
            moved_single = cand -- 记录这个单字
        else
            table.insert(reordered_singles, cand)
        end
    end

    -- 输出双字词
    for _, cand in ipairs(double_char_cands) do
        yield(cand)
    end

    -- 如果找到匹配的单字，先输出双字词，再放到单字的第一位
    if moved_single then
        yield(moved_single)
    end

    -- 输出其余单字
    for _, cand in ipairs(reordered_singles) do
        yield(cand)
    end

    -- 输出其余候选词
    for _, cand in ipairs(others) do
        yield(cand)
    end
end

return M
