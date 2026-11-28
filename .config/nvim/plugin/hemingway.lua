-- Hemingway mode (Space H, :Hemingway): hard sentences, adverbs, passive voice and words with a simpler choice are
-- highlighted, with the grade level on top; Space A (or a click) on a purple word offers simpler ones
local api = vim.api
local M = { state = {}, delay = 200, key = '<leader>A' }
package.loaded.hemingway = M

local NS = api.nvim_create_namespace('hemingway')
local NS_SIMPLE = api.nvim_create_namespace('hemingway_simple')
local NS_PARA = api.nvim_create_namespace('hemingway_para')
local NS_DIRTY = api.nvim_create_namespace('hemingway_dirty')
local BAR = '%#HemingwayBar#'
local DELETE = '(delete it)'

local function set(s)
    local t = {}
    for w in s:gmatch('%S+') do t[w] = true end
    return t
end

local BE = set([[am is are was were be been being isn't aren't wasn't weren't]])
local SKIP = set([[not never also often always still just already usually generally then being]])

local IRREG = set([[
arisen awoken beaten begotten begun bent bet bidden bitten bled blown born borne bought bound bred broken brought
built burnt burst cast caught chosen clung cut dealt done drawn dreamt driven drunk dug eaten fallen fed felt
fled flung flown forbidden forecast foreseen forgiven forgotten forsaken fought found frozen given ground grown
held hewn hidden hit hung hurt kept knelt knit known laid led left lent lit lost made meant met misheard mislaid
misled misread mistaken misunderstood mown overcome overdone overheard overrun overseen overtaken overthrown
paid proven put quit read rewritten rid ridden risen run rung said seen sent set sewn shaken shaven shed shone
shorn shot shown shrunk shut slain slung sold sought sown sped spent spilt split spoken spread sprung spun stolen
strewn stricken struck strung stuck stung sung sunk sworn swept swollen taken taught thought thrown thrust told
torn trodden undergone understood undertaken undone upheld withdrawn withheld woken won worn woven wound wrought
written wrung]])

local ADJ = set([[
advanced aged alarmed amazed amused annoyed ashamed astonished beloved bewildered blessed bored committed
complicated concerned confused convinced crowded cursed dedicated delighted depressed detailed determined devoted
disappointed disgusted distressed educated embarrassed employed engaged excited exhausted experienced fascinated
frightened horrified impressed inspired interested involved irritated learned limited married motivated
overwhelmed pleased puzzled qualified relaxed related retired satisfied scared shocked skilled sophisticated
startled stressed stunned supposed surprised talented terrified thrilled tired unemployed united upset used
worried]])

local ED_NOT = set([[
bleed breed creed deed exceed feed greed hatred heed hundred indeed kindred need proceed reed seed shed shred
sled speed steed succeed weed crooked jagged naked ragged rugged sacred wicked wretched]])

local LY = set([[
ally anomaly apply assembly beastly belly beverly billy bodily brolly brotherly bubbly bully burly butterfly
chilly comely comply costly courtly cowardly crinkly crumbly cuddly curly daily dally dastardly deadly deathly
dilly doily dolly dragonfly early earthly elderly emily family fatherly filly firefly fly folly fortnightly
friendly frilly gadfly gangly ghastly ghostly giggly gnarly godly golly goodly gravelly grisly gristly gully
heavenly hillbilly hilly holly holy homely homily horsefly hourly housefly imply italy jelly jolly jowly july
kelly kimberly kingly knobbly leisurely likely lily lively lolly lonely lovely lowly manly masterly mayfly
mealy measly melancholy miserly misapply molly monopoly monthly motherly multiply neighborly neighbourly
nightly oily only orderly otherworldly oversupply panoply pearly pebbly ply polly portly prickly princely
quarterly queenly rally rascally reapply rely reply resupply sally saintly scaly scholarly seemly shapely
shelly sicily sickly silly sisterly sly smelly sparkly sprightly squiggly stately steely sully supply surly
tally telly timely tingly treacly trolly ugly underbelly unearthly unfriendly ungodly unlikely unmanly
unruly unseemly unsightly untimely wally weekly wiggly willy wily wobbly womanly woolly worldly wriggly
wrinkly yearly]])

local ABBR = set([[
mr mrs ms dr prof sr jr st vs etc cf fig figs approx vol pp eds est dept inc ltd co corp gen col
capt lt sgt rev hon mt ft jan feb mar apr jun jul aug sep sept oct nov dec al]])

local SIMPLE = {
    ["a number of"]="many|some", ["abundance"]="enough|plenty", ["accede to"]="agree to|allow",
    ["accelerate"]="speed up", ["accentuate"]="stress", ["accompany"]="go with|with", ["accomplish"]="carry out|do",
    ["accorded"]="given", ["accordingly"]="so", ["accrue"]="add|gain", ["accurate"]="correct|exact|right",
    ["acquiesce"]="agree", ["acquire"]="get", ["additional"]="added|extra|more|other", ["adjacent to"]="next to",
    ["adjustment"]="change", ["admissible"]="accepted|allowed", ["advantageous"]="helpful",
    ["adversely impact"]="hurt", ["adversely impact on"]="hurt|set back", ["advise"]="recommend|tell",
    ["afford an opportunity"]="allow|let", ["aforementioned"]="-", ["aggregate"]="add|total", ["all of"]="all",
    ["alleviate"]="ease|reduce", ["allocate"]="divide", ["along the lines of"]="as in|like",
    ["already existing"]="existing", ["alternatively"]="or", ["ameliorate"]="help|improve", ["anticipate"]="expect",
    ["apparent"]="clear|plain", ["appreciable"]="many", ["appropriate"]="proper|right|-", ["approximate"]="about",
    ["as a means of"]="to", ["as of yet"]="yet", ["as prescribed by"]="in", ["as to"]="about|on", ["as yet"]="yet",
    ["ascertain"]="find out|learn", ["assist"]="aid|help", ["assistance"]="aid|help",
    ["at the present time"]="at present", ["at this time"]="now", ["attain"]="meet", ["attempt"]="try",
    ["attributable to"]="because", ["authorise"]="allow|let", ["authorize"]="allow|let", ["be advised"]="-",
    ["because of the fact that"]="because", ["belated"]="late", ["benefit"]="help", ["benefit from"]="enjoy",
    ["bestow"]="award|give", ["by means of"]="by|with", ["by virtue of"]="by|under", ["capability"]="ability",
    ["caveat"]="warning", ["cease"]="stop", ["close proximity"]="near", ["combined"]="joint",
    ["commence"]="begin|start", ["comply with"]="follow", ["component"]="part", ["comprise"]="form|include|make up",
    ["concerning"]="about|on", ["consequently"]="so", ["consolidate"]="combine|join|merge",
    ["constitutes"]="forms|is|makes up", ["contains"]="has", ["convene"]="meet", ["currently"]="now|-",
    ["deem"]="believe|consider|think", ["delete"]="cut|drop", ["demonstrate"]="prove|show", ["depart"]="go|leave",
    ["designate"]="appoint|choose|name", ["desire"]="want|wish", ["determine"]="decide|figure|find",
    ["disclose"]="show", ["discontinue"]="drop|stop", ["disseminate"]="give|issue|pass|send",
    ["due to the fact that"]="because|due to|since", ["during the period"]="during", ["e.g."]="for example|such as",
    ["each and every"]="each", ["economical"]="cheap", ["effect modifications"]="make changes", ["elect"]="choose",
    ["eliminate"]="cut|drop|end|stop", ["elucidate"]="explain", ["employ"]="use", ["encounter"]="meet",
    ["endeavor"]="try", ["ensure"]="make sure", ["enumerate"]="count", ["equitable"]="fair", ["equivalent"]="equal",
    ["establish"]="set up|prove|show", ["evaluate"]="check|test", ["evidenced"]="showed", ["evident"]="clear",
    ["exclusively"]="only", ["exhibit"]="show", ["expedite"]="hasten|hurry|speed up", ["expeditious"]="fast|quick",
    ["expend"]="spend", ["expertise"]="ability", ["expiration"]="end", ["facilitate"]="ease|help",
    ["factual evidence"]="evidence|facts", ["failed to"]="didn't", ["feasible"]="can be done|workable",
    ["finalise"]="complete|finish", ["finalize"]="complete|finish", ["first and foremost"]="first",
    ["for a period of"]="for", ["for the purpose of"]="to", ["forfeit"]="give up|lose", ["formulate"]="plan",
    ["frequently"]="often", ["furnish"]="give|send", ["has a requirement for"]="needs",
    ["has no effect"]="does nothing|does not apply", ["herein"]="here", ["heretofore"]="until now",
    ["herewith"]="here|below", ["honest truth"]="truth", ["however"]="but|yet", ["i.e."]="that is|as in",
    ["identical"]="same", ["identify"]="find|name|show", ["if and when"]="if|when", ["immediately"]="at once",
    ["impacted"]="affected|changed|harmed", ["implement"]="carry out|install|put in place|tool|start",
    ["in a timely manner"]="on time|promptly", ["in accordance with"]="by|under|following|per",
    ["in addition"]="also|besides|too", ["in all likelihood"]="probably", ["in an effort to"]="to",
    ["in between"]="between", ["in excess of"]="more than", ["in lieu of"]="instead",
    ["in light of the fact that"]="because", ["in many cases"]="often", ["in order that"]="for|so",
    ["in order to"]="to", ["in order for"]="for", ["in regard to"]="about|concerning|on",
    ["in relation to"]="about|with|to", ["in some instances"]="sometimes", ["in terms of"]="as|for|with|-",
    ["in the amount of"]="for", ["in the event of"]="if", ["in the near future"]="soon|shortly",
    ["in the process of"]="-", ["in view of"]="since", ["in view of the above"]="so", ["inasmuch as"]="since",
    ["inception"]="start", ["incumbent upon"]="must", ["indicate"]="show|say|state|write down",
    ["indication"]="sign", ["initial"]="first", ["initiate"]="start", ["inter alia"]="-",
    ["interpose no objection"]="don't object", ["is applicable to"]="applies to", ["is authorised to"]="may",
    ["is authorized to"]="may", ["is in consonance with"]="agrees with|follows", ["is responsible for"]="handles|-",
    ["it appears"]="seems", ["it is essential"]="must|need to", ["it is requested"]="please",
    ["liaison"]="discussion", ["limited number"]="limits", ["literally"]="-", ["magnitude"]="size",
    ["maintain"]="support|keep", ["maximum"]="greatest|largest|most", ["methodology"]="method",
    ["minimise"]="cut|decrease", ["minimize"]="cut|decrease", ["minimum"]="least|small|smallest",
    ["modify"]="change", ["monitor"]="check|track|watch", ["multiple"]="many", ["necessitate"]="cause|need",
    ["nevertheless"]="besides|even so|still", ["not certain"]="uncertain", ["not many"]="few",
    ["not often"]="rarely", ["not unless"]="only if", ["not unlike"]="alike|similar", ["notify"]="let know|tell",
    ["not later than"]="by|before", ["notwithstanding"]="despite|in spite of|still", ["null and void"]="null|void",
    ["numerous"]="many", ["objective"]="aim|goal", ["obligate"]="bind|compel", ["observe"]="see", ["obtain"]="get",
    ["on the contrary"]="but|so", ["on the other hand"]="but|so|-", ["one particular"]="one",
    ["operate"]="run|use|work", ["optimum"]="best|greatest|most", ["option"]="choice", ["overall"]="-",
    ["owing to the fact that"]="because|since", ["parameters"]="limits", ["participate"]="take part",
    ["particulars"]="details", ["pass away"]="die", ["perform"]="do", ["permit"]="let",
    ["pertaining to"]="about|of|on", ["point in time"]="moment|now|point|time", ["portion"]="part",
    ["possess"]="have|own", ["practicable"]="practical", ["preclude"]="prevent", ["previous"]="earlier",
    ["previously"]="before", ["prior to"]="before", ["prioritise"]="focus on|rank", ["prioritize"]="focus on|rank",
    ["proceed"]="do|go ahead|try", ["procure"]="buy|get|-", ["proficiency"]="skill", ["promulgate"]="issue|publish",
    ["provide"]="give|offer|say", ["provided that"]="if", ["provides guidance for"]="guides", ["purchase"]="buy",
    ["pursuant to"]="by|following|per|under", ["put simply"]="-", ["readily apparent"]="clear",
    ["refer back"]="refer", ["reflect"]="say|show", ["regarding"]="about|of|on", ["relative to"]="about|on",
    ["relocate"]="move", ["remain"]="stay", ["remainder"]="rest", ["remuneration"]="pay|payment",
    ["render"]="give|make", ["represents"]="is", ["request"]="ask", ["require"]="must|need",
    ["requirement"]="need|rule", ["reside"]="live", ["retain"]="keep", ["satisfy"]="meet|please",
    ["selection"]="choice", ["set forth in"]="in", ["shall"]="must|will", ["should you wish"]="if you want",
    ["similar to"]="like", ["solicit"]="ask for|request", ["span across"]="cross|span",
    ["state-of-the-art"]="latest", ["strategise"]="plan", ["strategize"]="plan", ["submit"]="give|send",
    ["subsequent"]="after|later|next|then", ["subsequently"]="after|later|then", ["substantial"]="large|much",
    ["successfully complete"]="complete|pass", ["sufficient"]="enough", ["take action to"]="-",
    ["terminate"]="end|stop", ["the month of"]="-", ["the undersigned"]="I", ["therefore"]="so|thus",
    ["thereof"]="its|their", ["therein"]="there", ["this day and age"]="today", ["time period"]="period|time",
    ["timely"]="prompt", ["transmit"]="send", ["transpire"]="happen", ["under the provisions of"]="under",
    ["until such time as"]="until", ["utilise"]="use", ["utilisation"]="use", ["utilization"]="use",
    ["utilize"]="use", ["validate"]="confirm", ["various different"]="different|various", ["very"]="-",
    ["viable"]="practical|workable", ["warrant"]="call for|permit", ["whereas"]="because|since",
    ["whether or not"]="whether", ["with reference to"]="about", ["with respect to"]="about|on",
    ["with the exception of"]="except for", ["witnessed"]="saw|seen",
}

local function round(x) return math.floor(x + 0.5) end

function M.ari(letters, words, sentences)
    if words == 0 or sentences == 0 then return 0 end
    local r = round(4.71 * (letters / words) + 0.5 * (words / sentences) - 21.43)
    return r < 0 and 0 or r
end

function M.goals(t)
    return M.ari(t.letters, t.words, t.sentences), round(t.paras / 3), round(t.sentences / 5)
end

function M.tokens(text)
    local toks = {}
    for s, e in text:gmatch("()[%w\128-\255'%-]+()") do
        e = e - 1
        while s <= e do
            local b = text:byte(s)
            if b == 39 or b == 45 then
                s = s + 1
            elseif b == 226 and text:byte(s + 1) == 128 and text:byte(s + 2) == 153 then
                s = s + 3
            else
                break
            end
        end
        while e >= s do
            local b = text:byte(e)
            if b == 39 or b == 45 then
                e = e - 1
            elseif b == 153 and text:byte(e - 1) == 128 and text:byte(e - 2) == 226 then
                e = e - 3
            else
                break
            end
        end
        if e >= s then
            local w = text:sub(s, e)
            if w:find('[%w\192-\255]') then
                local low, n = w:lower(), #w
                if w:find('[^%w]') then
                    if low:find('\226\128\153', 1, true) then low = low:gsub('\226\128\153', "'") end
                    local _, k = w:gsub('[^%w\192-\225\227-\255]', '')
                    n = n - k
                end
                toks[#toks + 1] = { s = s, e = e + 1, w = low, n = n }
            end
        end
    end
    return toks
end

local INDEX
local function index()
    if INDEX then return INDEX end
    INDEX = {}
    for phrase, alts in pairs(SIMPLE) do
        local words = {}
        for _, t in ipairs(M.tokens(phrase)) do words[#words + 1] = t.w end
        local list, omit = {}, false
        for a in alts:gmatch('[^|]+') do
            if a == '-' then omit = true else list[#list + 1] = a end
        end
        local e = { words = words, alts = list, omit = omit, dot = phrase:sub(-1) == '.' }
        local k = words[1]
        INDEX[k] = INDEX[k] or {}
        table.insert(INDEX[k], e)
    end
    for _, l in pairs(INDEX) do
        table.sort(l, function(a, b) return #a.words > #b.words end)
    end
    return INDEX
end

local function is_adverb(w)
    if #w < 4 or w:sub(-2) ~= 'ly' then return false end
    local seg = w:match('[^%-]+$')
    return #seg >= 4 and not LY[seg]
end

local function is_participle(w, nxt)
    if ADJ[w] then return nxt == 'by' end
    if IRREG[w] then return true end
    return #w >= 4 and w:sub(-2) == 'ed' and not ED_NOT[w]
end

function M.sentences(text)
    local out, start, pos, len = {}, 1, 1, #text
    while true do
        local p, pe = text:find('[.!?]+', pos)
        if not p then break end
        local q = pe
        while true do
            local c = text:byte(q + 1)
            if c == 34 or c == 39 or c == 41 or c == 93 then
                q = q + 1
            elseif c == 226 and text:byte(q + 2) == 128 and text:byte(q + 3) == 153 then
                q = q + 3
            else
                break
            end
        end
        local nxt = text:byte(q + 1)
        local cut = nxt == nil or nxt == 32 or nxt == 9 or nxt == 10
        if cut and p == pe and text:byte(p) == 46 then
            local before = text:sub(math.max(1, p - 12), p - 1):match('([%a%.]+)$')
            if before and (ABBR[before:lower()] or before:find('%a%.%a$') or (before:find('^%u$') and before ~= 'I')) then
                cut = false
            end
        end
        if cut and nxt then
            local n = text:find('%S', q + 1)
            if n and text:sub(n, n):find('%l') then cut = false end
        end
        if cut then
            out[#out + 1] = { start, q + 1 }
            start = q + 1
        end
        pos = q + 1
    end
    if start <= len then out[#out + 1] = { start, len + 1 } end
    return out
end

function M.analyse(text)
    local toks, idx = M.tokens(text), index()
    local marks, used = {}, {}
    local t = { sentences = 0, words = 0, letters = 0, hard = 0, vhard = 0, adverbs = 0, passive = 0, simple = 0, paras = 0 }
    local i = 1
    while i <= #toks do
        local cands = idx[toks[i].w]
        local step = 1
        if cands then
            for _, c in ipairs(cands) do
                local n = #c.words
                local ok = i + n - 1 <= #toks
                for k = 2, n do
                    if not ok then break end
                    local a, b = toks[i + k - 2], toks[i + k - 1]
                    local gap = text:sub(a.e, b.s - 1)
                    if b.w ~= c.words[k] or not (gap:find('^%s+$') or c.dot and gap == '.') then ok = false end
                end
                if ok then
                    local e = toks[i + n - 1].e
                    if c.dot and text:byte(e) == 46 then e = e + 1 end
                    marks[#marks + 1] = { toks[i].s, e, 'simple', c }
                    for k = i, i + n - 1 do used[k] = true end
                    t.simple = t.simple + 1
                    step = n
                    break
                end
            end
        end
        i = i + step
    end
    local ti = 1
    for _, sp in ipairs(M.sentences(text)) do
        local first = ti
        while ti <= #toks and toks[ti].s < sp[2] do ti = ti + 1 end
        local last = ti - 1
        local nw = last - first + 1
        if nw > 0 then
            local letters = 0
            for k = first, last do letters = letters + toks[k].n end
            t.sentences, t.words, t.letters = t.sentences + 1, t.words + nw, t.letters + letters
            if nw >= 14 then
                local lv = M.ari(letters, nw, 1)
                local kind = lv >= 14 and 'vhard' or lv >= 10 and 'hard' or nil
                if kind then
                    local s = text:find('%S', sp[1])
                    local e = sp[2] - 1
                    while e > s and text:byte(e) == 32 do e = e - 1 end
                    marks[#marks + 1] = { s, e + 1, kind }
                    t[kind] = t[kind] + 1
                end
            end
            local k = first
            while k <= last do
                if BE[toks[k].w] then
                    local j, skips = k + 1, 0
                    while j <= last and skips < 2 and (SKIP[toks[j].w] or is_adverb(toks[j].w)) do
                        j, skips = j + 1, skips + 1
                    end
                    if j <= last and is_participle(toks[j].w, j < last and toks[j + 1].w or nil) then
                        marks[#marks + 1] = { toks[k].s, toks[j].e, 'passive' }
                        t.passive = t.passive + 1
                        k = j
                    end
                end
                k = k + 1
            end
            for a = first, last do
                if not used[a] and is_adverb(toks[a].w) then
                    marks[#marks + 1] = { toks[a].s, toks[a].e, 'adverb' }
                    t.adverbs = t.adverbs + 1
                end
            end
        end
    end
    if t.words > 0 then t.paras = 1 end
    return marks, t
end

local function blank(s) return (' '):rep(#s) end

local function clean(l)
    if not (l:find('\226', 1, true) or l:find('\194', 1, true) or l:find('\240', 1, true)) then return l end
    return (l:gsub('\226[\128-\191][\128-\191]', function(c) return c == '\226\128\153' and c or '   ' end)
        :gsub('[\240-\244][\128-\191][\128-\191][\128-\191]', '    ')
        :gsub('\194[\128-\191]', '  '))
end

local function urls(l)
    if l:find(':', 1, true) or l:find('@', 1, true) or l:find('www.', 1, true) then
        l = l:gsub('%a[%w+.-]*://[^%s<>"]*', blank):gsub('www%.[^%s<>"]+', blank)
            :gsub('[%w._%%+-]+@[%w.-]+%.%a+', blank)
    end
    return l
end

local MD_BLOCK = { '^%s*[-*+]%s+%[.%]%s', '^%s*[-*+]%s+', '^%s*%d+[.)]%s+', '^%s*#+%s*', '^%s*>[>%s]*', '^%s*|' }

local function md(l, row, st)
    if st.front then
        if l:match('^%-%-%-%s*$') or l:match('^%.%.%.%s*$') or l:match('^%+%+%+%s*$') then st.front = nil end
        return nil
    end
    if row == 0 and (l:match('^%-%-%-%s*$') or l:match('^%+%+%+%s*$')) then
        st.front = true
        return nil
    end
    if st.fence then
        local f = l:match('^%s*([`~]+)') or l:match('^%s*(}}})') or l:match('^%s*(%$%$)')
        if f and f:sub(1, 1) == st.fence:sub(1, 1) and #f >= #st.fence then st.fence = nil end
        return nil
    end
    if st.comment then
        local e = l:find('-->', 1, true)
        if not e then return nil end
        st.comment = nil
        l = blank(l:sub(1, e + 2)) .. l:sub(e + 3)
    end
    local i = l:find('%S')
    if not i then return nil end
    local c = l:sub(i, i)
    if c == '`' or c == '~' or c == '{' or c == '$' then
        local f = l:match('^%s*(```+)') or l:match('^%s*(~~~+)')
        if f then st.fence = f return nil end
        if l:match('^%s*{{{') then st.fence = '}}}' return nil end
        if l:match('^%s*%$%$%s*$') then st.fence = '$$' return nil end
    end
    if c == '[' and l:match('^%s*%[[^%]]+%]:%s') then return nil end
    if c:find('[-=*_|:]') and (l:match('^%s*[-=*_][-=*_%s]*$') or l:match('^%s*|?[%s:|-]+$')) then return nil end
    local start = st.heading or false
    st.heading = l:match('^%s*#+%s') ~= nil or l:match('^%s*#+$') ~= nil
    if c:find('[-*+#>|%d]') then
        for _, p in ipairs(MD_BLOCK) do
            local _, e = l:find(p)
            if e then
                start = true
                l = blank(l:sub(1, e)) .. l:sub(e + 1)
                break
            end
        end
    end
    if l:find('`', 1, true) then l = l:gsub('((`+).-%2)', blank) end
    if l:find('[', 1, true) then
        l = l:gsub('%[%[([^%]|]*)|([^%]]*)%]%]', function(a, b) return (' '):rep(#a + 3) .. b .. '  ' end)
            :gsub('%[%[[^%]]*%]%]', blank)
            :gsub('%](%b())', function(b) return ' ' .. blank(b) end)
            :gsub('%]%[[^%]]*%]', blank)
    end
    if l:find('<', 1, true) then
        l = l:gsub('<!%-%-.-%-%->', blank):gsub('<%a[%w+.-]*:[^>]*>', blank):gsub('</?%a[^>]*>', blank)
        local c = l:find('<!--', 1, true)
        if c then
            st.comment = true
            l = l:sub(1, c - 1) .. blank(l:sub(c))
        end
    end
    if l:find('{{', 1, true) then l = l:gsub('{{.-}}', blank) end
    return l, start
end

local TEX_ENV = set([[
verbatim verbatim* lstlisting minted equation equation* align align* gather gather* multline multline*
eqnarray eqnarray* math displaymath comment tikzpicture tabular tabular* array]])
local TEX_DROP = set([[
label ref eqref pageref autoref cref Cref cite citep citet citeauthor citeyear nocite url href includegraphics
input include usepackage documentclass bibliography bibliographystyle addbibresource printbibliography begin end
hspace vspace setlength newcommand renewcommand newenvironment graphicspath]])

local function tex(l, _, st)
    if st.env then
        if l:find(st.env, 1, true) then st.env = nil end
        return nil
    end
    local i = 1
    while true do
        local p = l:find('%', i, true)
        if not p then break end
        if p == 1 or l:byte(p - 1) ~= 92 then
            l = l:sub(1, p - 1) .. blank(l:sub(p))
            break
        end
        i = p + 1
    end
    local env = l:match('\\begin{([^}]+)}')
    if env and TEX_ENV[env] then
        if not l:find('\\end{' .. env .. '}', 1, true) then st.env = '\\end{' .. env .. '}' end
        return nil
    end
    if l:match('^%s*\\%[') and not l:find('\\]', 1, true) then st.env = '\\]' return nil end
    if l:match('^%s*%$%$%s*$') then st.env = '$$' return nil end
    if l:find('[$\\]') then
        l = l:gsub('\\%[.-\\%]', blank):gsub('%$%$.-%$%$', blank):gsub('\\%(.-\\%)', blank):gsub('%$.-%$', blank)
        local out, pos = {}, 1
        while true do
            local s, e, name = l:find('\\(%a+)%*?', pos)
            if not s then break end
            if TEX_DROP[name] then
                while true do
                    local _, b = l:find('^%s*%b[]', e + 1)
                    if not b then _, b = l:find('^%s*%b{}', e + 1) end
                    if not b then break end
                    e = b
                end
            end
            out[#out + 1] = l:sub(pos, s - 1)
            out[#out + 1] = blank(l:sub(s, e))
            pos = e + 1
        end
        out[#out + 1] = l:sub(pos)
        l = table.concat(out)
    end
    return l
end

local function gitcommit(l, _, st)
    if st.done then return nil end
    if l:match('^# %-+ >8 %-+') or l:match('^diff %-%-git ') then st.done = true return nil end
    if l:match('^#') then return nil end
    return l
end

local function mail(l, row, st)
    if st.done then return nil end
    if row == 0 and l:match('^[%w-]+:%s') then st.head = true end
    if st.head then
        if l == '' then st.head = nil end
        return nil
    end
    if l == '-- ' then st.done = true return nil end
    if l:match('^%s*>') then return nil end
    return l
end

local MASK = {
    markdown = md, vimwiki = md, pandoc = md, rmd = md, quarto = md,
    tex = tex, plaintex = tex, latex = tex,
    gitcommit = gitcommit, mail = mail,
}

function M.scan(lines, ft)
    local mask, st = MASK[ft], {}
    local paras, cur = {}, nil
    for i, raw in ipairs(lines) do
        local l, start = raw, false
        if mask then l, start = mask(raw, i - 1, st) end
        if l then l = clean(urls(l)) end
        if not l or not l:find('[%w\128-\255]') then
            cur = nil
        else
            if start or not cur then
                cur = { row = i - 1, lines = {} }
                paras[#paras + 1] = cur
            end
            cur.lines[#cur.lines + 1] = l
        end
    end
    for _, p in ipairs(paras) do p.text = table.concat(p.lines, ' ') end
    return paras
end

local HL = {
    hard = { 'HemingwayHard', 150 },
    vhard = { 'HemingwayVeryHard', 150 },
    passive = { 'HemingwayPassive', 160 },
    adverb = { 'HemingwayAdverb', 170 },
    simple = { 'HemingwaySimpler', 170 },
}

local COLOURS = {
    HemingwayHard = { '#4a4318', 58 },
    HemingwayVeryHard = { '#5a2828', 52 },
    HemingwayAdverb = { '#1e3d55', 24 },
    HemingwayPassive = { '#29491c', 22 },
    HemingwaySimpler = { '#4a2753', 53 },
}

local function colours()
    for name, c in pairs(COLOURS) do
        api.nvim_set_hl(0, name, { default = true, bg = c[1], ctermbg = c[2] })
    end
    api.nvim_set_hl(0, 'HemingwayBar', { default = true, link = 'WinBar' })
end

local function place(buf, st, p)
    local marks, t = M.analyse(p.text)
    local entry = { text = p.text, nrows = #p.lines, stats = t, ids = {}, sids = {} }
    entry.id = api.nvim_buf_set_extmark(buf, NS_PARA, p.row, 0, {})
    local starts, o = {}, 1
    for k, l in ipairs(p.lines) do
        starts[k] = o
        o = o + #l + 1
    end
    local function pos(off)
        local k = #starts
        while k > 1 and starts[k] > off do k = k - 1 end
        return p.row + k - 1, off - starts[k]
    end
    for _, m in ipairs(marks) do
        local sr, sc = pos(m[1])
        local er, ec = pos(m[2])
        local hl = HL[m[3]]
        local simple = m[3] == 'simple'
        local id = api.nvim_buf_set_extmark(buf, simple and NS_SIMPLE or NS, sr, sc, {
            end_row = er, end_col = ec, hl_group = hl[1], priority = hl[2], strict = false,
        })
        if simple then
            entry.sids[#entry.sids + 1] = id
            st.simple[id] = m[4]
        else
            entry.ids[#entry.ids + 1] = id
        end
    end
    return entry
end

local function drop(buf, st, e)
    pcall(api.nvim_buf_del_extmark, buf, NS_PARA, e.id)
    for _, id in ipairs(e.ids) do pcall(api.nvim_buf_del_extmark, buf, NS, id) end
    for _, id in ipairs(e.sids) do
        pcall(api.nvim_buf_del_extmark, buf, NS_SIMPLE, id)
        st.simple[id] = nil
    end
end

local function render(t)
    if t.sentences == 0 then return BAR end
    local grade, agoal, pgoal = M.goals(t)
    local function chip(g, n) return '%#' .. g .. '# ' .. n .. ' ' .. BAR end
    return table.concat({
        BAR, ' Grade ', grade, '  ',
        chip('HemingwayHard', t.hard), ' of ', t.sentences, t.sentences == 1 and ' sentence' or ' sentences', ' hard, ',
        chip('HemingwayVeryHard', t.vhard), ' very hard, ',
        chip('HemingwayAdverb', t.adverbs), t.adverbs == 1 and ' adverb' or ' adverbs', ' (meet ', agoal, ' or fewer), ',
        chip('HemingwayPassive', t.passive), ' passive (meet ', pgoal, ' or fewer), ',
        chip('HemingwaySimpler', t.simple), t.simple == 1 and ' simpler word' or ' simpler words',
        '%<',
    })
end

local function ours(win)
    local ok, v = pcall(api.nvim_get_option_value, 'winbar', { scope = 'local', win = win })
    return ok and v:sub(1, #BAR) == BAR
end

local function set_bar(win, v)
    pcall(api.nvim_set_option_value, 'winbar', v, { scope = 'local', win = win })
end

local function show(buf)
    local st = M.state[buf]
    if not st then return end
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do set_bar(win, st.bar) end
end

function M.update(buf)
    buf = buf or api.nvim_get_current_buf()
    local st = M.state[buf]
    if not st or not api.nvim_buf_is_loaded(buf) then return end
    if st.full then
        for _, ns in ipairs({ NS, NS_SIMPLE, NS_PARA }) do api.nvim_buf_clear_namespace(buf, ns, 0, -1) end
        st.paras, st.simple, st.full = {}, {}, nil
    end
    local paras = M.scan(api.nvim_buf_get_lines(buf, 0, -1, false), st.ft)
    local dirty = {}
    for _, m in ipairs(api.nvim_buf_get_extmarks(buf, NS_DIRTY, 0, -1, { details = true })) do
        dirty[#dirty + 1] = { m[2], m[4].end_row or m[2] }
    end
    api.nvim_buf_clear_namespace(buf, NS_DIRTY, 0, -1)
    local by_row = {}
    for _, m in ipairs(api.nvim_buf_get_extmarks(buf, NS_PARA, 0, -1, {})) do
        local e = st.paras[m[1]]
        if e then
            by_row[m[2]] = by_row[m[2]] or {}
            table.insert(by_row[m[2]], e)
        end
    end
    local keep, made = {}, 0
    local t = { sentences = 0, words = 0, letters = 0, hard = 0, vhard = 0, adverbs = 0, passive = 0, simple = 0, paras = 0 }
    for _, p in ipairs(paras) do
        local r1, r2 = p.row, p.row + #p.lines - 1
        local reuse
        local clean_rows = true
        for _, d in ipairs(dirty) do
            if d[1] <= r2 and math.max(d[2], d[1] + 1) > r1 then clean_rows = false break end
        end
        if clean_rows then
            for _, e in ipairs(by_row[r1] or {}) do
                if not keep[e.id] and e.text == p.text and e.nrows == #p.lines then reuse = e break end
            end
        end
        if not reuse then
            reuse = place(buf, st, p)
            made = made + 1
        end
        keep[reuse.id] = reuse
        for k, v in pairs(reuse.stats) do t[k] = t[k] + v end
    end
    for id, e in pairs(st.paras) do
        if not keep[id] then drop(buf, st, e) end
    end
    st.paras, st.stats, st.made = keep, t, made
    st.bar = render(t)
    show(buf)
end

function M.status(buf)
    local st = M.state[buf or api.nvim_get_current_buf()]
    return st and st.bar and (st.bar:gsub('%%#%w+#', ''))
end

local function schedule(buf)
    local st = M.state[buf]
    if not st then return end
    st.timer:stop()
    st.timer:start(M.delay, 0, vim.schedule_wrap(function()
        if M.state[buf] == st then M.update(buf) end
    end))
end

local function pick(items, prompt, cb)
    local ok, fzf = pcall(require, 'fzf-lua')
    if ok and type(fzf) == 'table' and fzf.fzf_exec then
        fzf.fzf_exec(items, {
            prompt = prompt .. '> ',
            winopts = { relative = 'cursor', row = 1, col = 0, width = 40, height = #items + 4, preview = { hidden = true } },
            fzf_opts = { ['--no-sort'] = true },
            actions = { ['enter'] = function(sel) if sel and sel[1] then cb(sel[1]) end end },
        })
    else
        vim.ui.select(items, { prompt = prompt }, function(c) if c then cb(c) end end)
    end
end

local function match_case(orig, new)
    if orig:find('%a.*%a') and orig == orig:upper() then return new:upper() end
    if orig:find('^%u') then return new:sub(1, 1):upper() .. new:sub(2) end
    return new
end

local function apply(buf, id, range, orig, choice)
    if not api.nvim_buf_is_valid(buf) then return end
    local m = api.nvim_buf_get_extmark_by_id(buf, NS_SIMPLE, id, { details = true })
    local sr, sc, er, ec
    if m[1] then
        sr, sc, er, ec = m[1], m[2], m[3].end_row, m[3].end_col
    else
        sr, sc, er, ec = unpack(range)
    end
    local ok, cur = pcall(api.nvim_buf_get_text, buf, sr, sc, er, ec, {})
    if not ok or table.concat(cur, ' ') ~= orig then return end
    if choice ~= DELETE then
        api.nvim_buf_set_text(buf, sr, sc, er, ec, { match_case(orig, choice) })
    else
        api.nvim_buf_set_text(buf, sr, sc, er, ec, { '' })
        local line = api.nvim_buf_get_lines(buf, sr, sr + 1, false)[1]
        if line:sub(sc + 1, sc + 1) == ' ' and (sc == 0 or line:sub(sc, sc):find('%s')) then
            api.nvim_buf_set_text(buf, sr, sc, sr, sc + 1, { '' })
        elseif sc > 0 and line:sub(sc, sc) == ' ' and not line:sub(sc + 1, sc + 1):find('%w') then
            api.nvim_buf_set_text(buf, sr, sc - 1, sr, sc, { '' })
            sc = sc - 1
        end
        line = api.nvim_buf_get_lines(buf, sr, sr + 1, false)[1]
        local nxt = line:sub(sc + 1, sc + 1)
        if orig:find('^%u') and nxt:find('%l') then api.nvim_buf_set_text(buf, sr, sc, sr, sc + 1, { nxt:upper() }) end
    end
    schedule(buf)
end

function M.simplify(buf, quiet)
    buf = buf or api.nvim_get_current_buf()
    local st = M.state[buf]
    if not st then return end
    local r, c = unpack(api.nvim_win_get_cursor(0))
    r = r - 1
    for _, m in ipairs(api.nvim_buf_get_extmarks(buf, NS_SIMPLE, { r, 0 }, { r, -1 }, { details = true, overlap = true })) do
        local d = m[4]
        if (m[2] < r or m[3] <= c) and (d.end_row > r or d.end_col > c) and st.simple[m[1]] then
            local e = st.simple[m[1]]
            local range = { m[2], m[3], d.end_row, d.end_col }
            local orig = table.concat(api.nvim_buf_get_text(buf, m[2], m[3], d.end_row, d.end_col, {}), ' ')
            local items = {}
            for _, a in ipairs(e.alts) do items[#items + 1] = match_case(orig, a) end
            if e.omit then items[#items + 1] = DELETE end
            pick(items, orig, function(choice) apply(buf, m[1], range, orig, choice) end)
            return
        end
    end
    if not quiet then vim.notify('No simpler word here') end
end

local function group() return api.nvim_create_augroup('Hemingway', { clear = false }) end

function M.enable(buf)
    buf = (buf == nil or buf == 0) and api.nvim_get_current_buf() or buf
    if M.state[buf] or not api.nvim_buf_is_loaded(buf) then return end
    local first = next(M.state) == nil
    local st = { ft = vim.bo[buf].filetype, paras = {}, simple = {}, timer = vim.uv.new_timer() }
    M.state[buf] = st
    colours()
    local g = group()
    if first then
        api.nvim_create_autocmd('ColorScheme', { group = g, callback = colours })
        api.nvim_create_autocmd('BufWinEnter', {
            group = g,
            callback = function()
                local win = api.nvim_get_current_win()
                local b = api.nvim_win_get_buf(win)
                if M.state[b] and M.state[b].bar then
                    set_bar(win, M.state[b].bar)
                elseif ours(win) then
                    set_bar(win, '')
                end
            end,
        })
    end
    api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'TextChangedP' }, {
        group = g, buffer = buf, callback = function() schedule(buf) end,
    })
    api.nvim_create_autocmd('FileType', {
        group = g, buffer = buf,
        callback = function()
            st.ft, st.full = vim.bo[buf].filetype, true
            schedule(buf)
        end,
    })
    api.nvim_create_autocmd({ 'BufUnload', 'BufWipeout' }, {
        group = g, buffer = buf, callback = function() M.disable(buf) end,
    })
    api.nvim_buf_attach(buf, false, {
        on_lines = function(_, b, _, top, _, bottom)
            if M.state[b] ~= st then return true end
            pcall(api.nvim_buf_set_extmark, b, NS_DIRTY, top, 0, { end_row = bottom, end_col = 0, strict = false })
        end,
        on_reload = function(_, b)
            if M.state[b] == st then
                st.full = true
                schedule(b)
            end
        end,
    })
    vim.keymap.set('n', M.key, function() M.simplify(buf) end, { buffer = buf, desc = 'Hemingway: simpler word' })
    vim.keymap.set('n', '<LeftRelease>', function() M.simplify(buf, true) end, { buffer = buf, desc = 'Hemingway: simpler word' })
    M.update(buf)
end

function M.disable(buf)
    buf = (buf == nil or buf == 0) and api.nvim_get_current_buf() or buf
    local st = M.state[buf]
    if not st then return end
    M.state[buf] = nil
    st.timer:stop()
    st.timer:close()
    if api.nvim_buf_is_valid(buf) then
        for _, ns in ipairs({ NS, NS_SIMPLE, NS_PARA, NS_DIRTY }) do api.nvim_buf_clear_namespace(buf, ns, 0, -1) end
        pcall(vim.keymap.del, 'n', M.key, { buffer = buf })
        pcall(vim.keymap.del, 'n', '<LeftRelease>', { buffer = buf })
    end
    for _, win in ipairs(api.nvim_list_wins()) do
        if ours(win) and not M.state[api.nvim_win_get_buf(win)] then set_bar(win, '') end
    end
    pcall(api.nvim_clear_autocmds, { group = 'Hemingway', buffer = buf })
    if next(M.state) == nil then pcall(api.nvim_del_augroup_by_name, 'Hemingway') end
end

function M.toggle(buf)
    buf = (buf == nil or buf == 0) and api.nvim_get_current_buf() or buf
    if M.state[buf] then M.disable(buf) else M.enable(buf) end
end

api.nvim_create_user_command('Hemingway', function(o)
    if o.args == 'on' then
        M.enable()
    elseif o.args == 'off' then
        M.disable()
    else
        M.toggle()
    end
end, { nargs = '?', complete = function() return { 'on', 'off' } end, desc = 'Hemingway mode for this buffer' })

vim.keymap.set('n', '<leader>H', function() M.toggle() end, { desc = 'Hemingway mode' })
