script_name("CarTool")
local script_version = 1.01

require "lib.moonloader"
local ffi = require "ffi"
local imgui = require "mimgui"
local encoding = require "encoding"
local sampev = require "lib.samp.events"
local vkeys = require "vkeys"
local mem = require "memory"
local dlstatus = require("moonloader").download_status
local hasLfs, lfs = pcall(require, "lfs")

encoding.default = "CP1251"
local u8 = encoding.UTF8

math.randomseed(os.time() + math.floor(os.clock() * 1000))

local updateUrl = "https://raw.githubusercontent.com/kaip0v/CarTool/main/update.json"
local activeTempFiles = {}

ffi.cdef[[
    typedef void (__thiscall *SetupSuspensionLines_t)(void *pAutomobile);
]]
local SetupSuspensionLines = ffi.cast("SetupSuspensionLines_t", 0x6A6180)

local configDir = getWorkingDirectory() .. "\\config"
local configPath = configDir .. "\\CarTool.json"

if not doesDirectoryExist(configDir) then
    createDirectory(configDir)
end

local settings = {
    uiScale = 1.0,
    notifPos = 2,
    notifyEvents = true,
    livePreview = true,
    showPalette = true,
    keepUnsavedColor = true,
    disableAllTune = false,
    disableVinyls = true,
    autoModloader = false,
    autoApplyHandling = true,
    autoUpdate = true
}

local UI = {
    windowState = imgui.new.bool(false),
    importModal = imgui.new.bool(false),
    currentTab = 1,
    uiScaleArr = imgui.new.float[1](1.0),
    notifyEventsBool = imgui.new.bool(true),
    livePreviewBool = imgui.new.bool(true),
    showPaletteBool = imgui.new.bool(true),
    keepUnsavedBool = imgui.new.bool(true),
    disableAllBool = imgui.new.bool(false),
    disableVinylsBool = imgui.new.bool(true),
    autoModloaderBool = imgui.new.bool(false),
    autoApplyHandlingBool = imgui.new.bool(true),
    autoUpdateBool = imgui.new.bool(true),

    c1 = imgui.new.int(0),
    c2 = imgui.new.int(0),
    c3 = imgui.new.int(0),
    c4 = imgui.new.int(0),
    activeColorSlot = 1,
    popupColorBuf = imgui.new.int(0),
    inputPlate = imgui.new.char[64](""),
    importColorBuf = imgui.new.char[64](""),
    presetSearch = imgui.new.char[128](""),

    tuneSearch = imgui.new.char[256](""),
    tuneFilterMode = 1,

    handSubMode = 1,
    handSearch = imgui.new.char[128](""),
    importCarSearch = imgui.new.char[128](""),
    importLineBuf = imgui.new.char[1024](""),
    importSafeMode = imgui.new.bool(true),
    importModelId = 560,
    manualModelId = 560,

    anyModalOpen = false,
    requestCloseModal = false,
    forceResize = false,
    confirmResetAllHandTimer = 0
}

local Sys = {
    tempText = nil,
    tempTimer = 0,
    tempType = 0,
    wasTypingEscape = false
}

local notifPositions = {
    u8"Ñëåâà ñíèçó",
    u8"Ñíèçó (ïî öåíòðó)",
    u8"Ñïðàâà ñíèçó",
    u8"Ñâåðõó (ïî öåíòðó)"
}

local theme = {
    me = imgui.ImVec4(0.18, 0.35, 0.58, 1.00),
    them = imgui.ImVec4(0.25, 0.25, 0.25, 1.00),
    warn = imgui.ImVec4(0.85, 0.55, 0.15, 1.00),
    danger = imgui.ImVec4(0.68, 0.22, 0.24, 1.00),
    err = imgui.ImVec4(0.85, 0.28, 0.28, 1.00),
    notif_bg = imgui.ImVec4(0.12, 0.12, 0.12, 0.95),
    notif_text = imgui.ImVec4(0.90, 0.90, 0.90, 1.00),
    sys_ok = imgui.ImVec4(0.20, 0.80, 0.20, 0.80),
    sys_err = imgui.ImVec4(0.80, 0.20, 0.20, 0.80),
    sys_info = imgui.ImVec4(0.20, 0.60, 0.90, 0.80),
    online = imgui.ImVec4(0.25, 0.82, 0.35, 1.00),
    muted = imgui.ImVec4(0.60, 0.60, 0.60, 1.00),
    subtext = imgui.ImVec4(0.65, 0.65, 0.65, 1.00),
    white = imgui.ImVec4(1.00, 1.00, 1.00, 1.00),
    dark_text = imgui.ImVec4(0.08, 0.08, 0.10, 1.00)
}

local vehicleNames = {
    [400]="Landstalker", [401]="Bravura", [402]="Buffalo", [403]="Linerunner", [404]="Perenniel", [405]="Sentinel", [406]="Dumper", [407]="Firetruck", [408]="Trashmaster", [409]="Stretch", [410]="Manana", [411]="Infernus", [412]="Voodoo", [413]="Pony", [414]="Mule", [415]="Cheetah", [416]="Ambulance", [417]="Leviathan", [418]="Moonbeam", [419]="Esperanto", [420]="Taxi", [421]="Washington", [422]="Bobcat", [423]="Mr Whoopee", [424]="BF Injection", [425]="Hunter", [426]="Premier", [427]="Enforcer", [428]="Securicar", [429]="Banshee", [430]="Predator", [431]="Bus", [432]="Rhino", [433]="Barracks", [434]="Hotknife", [435]="Article Trailer", [436]="Previon", [437]="Coach", [438]="Cabbie", [439]="Stallion", [440]="Rumpo", [441]="RC Bandit", [442]="Romero", [443]="Packer", [444]="Monster", [445]="Admiral", [446]="Squallo", [447]="Seasparrow", [448]="Pizzaboy", [449]="Tram", [450]="Article Trailer 2", [451]="Turismo", [452]="Speeder", [453]="Reefer", [454]="Tropic", [455]="Flatbed", [456]="Yankee", [457]="Caddy", [458]="Solair", [459]="Berkley's RC Van", [460]="Skimmer", [461]="PCJ-600", [462]="Faggio", [463]="Freeway", [464]="RC Baron", [465]="RC Raider", [466]="Glendale", [467]="Oceanic", [468]="Sanchez", [469]="Sparrow", [470]="Patriot", [471]="Quad", [472]="Coastguard", [473]="Dinghy", [474]="Hermes", [475]="Sabre", [476]="Rustler", [477]="ZR-350", [478]="Walton", [479]="Regina", [480]="Comet", [481]="BMX", [482]="Burrito", [483]="Camper", [484]="Marquis", [485]="Baggage", [486]="Dozer", [487]="Maverick", [488]="SAN News Maverick", [489]="Rancher", [490]="FBI Rancher", [491]="Virgo", [492]="Greenwood", [493]="Jetmax", [494]="Hotring Racer", [495]="Sandking", [496]="Blista Compact", [497]="Police Maverick", [498]="Boxville", [499]="Benson", [500]="Mesa", [501]="RC Goblin", [502]="Hotring Racer A", [503]="Hotring Racer B", [504]="Bloodring Banger", [505]="Rancher Lure", [506]="Super GT", [507]="Elegant", [508]="Journey", [509]="Bike", [510]="Mountain Bike", [511]="Beagle", [512]="Cropduster", [513]="Stuntplane", [514]="Tanker", [515]="Roadtrain", [516]="Nebula", [517]="Majestic", [518]="Buccaneer", [519]="Shamal", [520]="Hydra", [521]="FCR-900", [522]="NRG-500", [523]="HPV1000", [524]="Cement Truck", [525]="Towtruck", [526]="Fortune", [527]="Cadrona", [528]="FBI Truck", [529]="Willard", [530]="Forklift", [531]="Tractor", [532]="Combine Harvester", [533]="Feltzer", [534]="Remington", [535]="Slamvan", [536]="Blade", [537]="Freight", [538]="Brownstreak", [539]="Vortex", [540]="Vincent", [541]="Bullet", [542]="Clover", [543]="Sadler", [544]="Firetruck LA", [545]="Hustler", [546]="Intruder", [547]="Primo", [548]="Cargobob", [549]="Tampa", [550]="Sunrise", [551]="Merit", [552]="Utility Van", [553]="Nevada", [554]="Yosemite", [555]="Windsor", [556]="Monster A", [557]="Monster B", [558]="Uranus", [559]="Jester", [560]="Sultan", [561]="Stratum", [562]="Elegy", [563]="Raindance", [564]="RC Tiger", [565]="Flash", [566]="Tahoma", [567]="Savanna", [568]="Bandito", [569]="Freight Flat Trailer", [570]="Streak Trailer", [571]="Kart", [572]="Mower", [573]="Dune", [574]="Sweeper", [575]="Broadway", [576]="Tornado", [577]="AT-400", [578]="DFT-30", [579]="Huntley", [580]="Stafford", [581]="BF-400", [582]="Newsvan", [583]="Tug", [584]="Petrol Trailer", [585]="Emperor", [586]="Wayfarer", [587]="Euros", [588]="Hotdog", [589]="Club", [590]="Freight Box Trailer", [591]="Article Trailer 3", [592]="Andromada", [593]="Dodo", [594]="RC Cam", [595]="Launch", [596]="Police Car LSPD", [597]="Police Car SFPD", [598]="Police Car LVPD", [599]="Police Ranger", [600]="Picador", [601]="S.W.A.T.", [602]="Alpha", [603]="Phoenix", [604]="Glendale Damaged", [605]="Sadler Damaged", [606]="Baggage Trailer A", [607]="Baggage Trailer B", [608]="Tug Stairs Trailer", [609]="Boxville Black", [610]="Farm Trailer", [611]="Utility Trailer"
}

local dffToId = {
    ["landstal"]=400, ["bravura"]=401, ["buffalo"]=402, ["linerun"]=403, ["peren"]=404, ["sentinel"]=405, ["dumper"]=406, ["firetruk"]=407, ["trash"]=408, ["stretch"]=409, ["manana"]=410, ["infernus"]=411, ["voodoo"]=412, ["pony"]=413, ["mule"]=414, ["cheetah"]=415, ["ambulan"]=416, ["leviathn"]=417, ["moonbeam"]=418, ["esperant"]=419, ["taxi"]=420, ["washing"]=421, ["bobcat"]=422, ["mrwhoop"]=423, ["bfinject"]=424, ["hunter"]=425, ["premier"]=426, ["enforcer"]=427, ["securica"]=428, ["banshee"]=429, ["predator"]=430, ["bus"]=431, ["rhino"]=432, ["barracks"]=433, ["hotknife"]=434, ["artict1"]=435, ["previon"]=436, ["coach"]=437, ["cabbie"]=438, ["stallion"]=439, ["rumpo"]=440, ["rcbandit"]=441, ["romero"]=442, ["packer"]=443, ["monster"]=444, ["admiral"]=445, ["squalo"]=446, ["seaspar"]=447, ["pizzaboy"]=448, ["tram"]=449, ["artict2"]=450, ["turismo"]=451, ["speeder"]=452, ["reefer"]=453, ["tropic"]=454, ["flatbed"]=455, ["yankee"]=456, ["caddy"]=457, ["solair"]=458, ["topfun"]=459, ["skimmer"]=460, ["pcj600"]=461, ["faggio"]=462, ["freeway"]=463, ["rcbaron"]=464, ["rcraider"]=465, ["glendale"]=466, ["oceanic"]=467, ["sanchez"]=468, ["sparrow"]=469, ["patriot"]=470, ["quad"]=471, ["coastg"]=472, ["dinghy"]=473, ["hermes"]=474, ["sabre"]=475, ["rustler"]=476, ["zr350"]=477, ["walton"]=478, ["regina"]=479, ["comet"]=480, ["bmx"]=481, ["burrito"]=482, ["camper"]=483, ["marquis"]=484, ["baggage"]=485, ["dozer"]=486, ["maverick"]=487, ["vcnmav"]=488, ["rancher"]=489, ["fbiranch"]=490, ["virgo"]=491, ["greenwoo"]=492, ["jetmax"]=493, ["hotring"]=494, ["sandking"]=495, ["blistac"]=496, ["polmav"]=497, ["boxburg"]=498, ["benson"]=499, ["mesa"]=500, ["rcgoblin"]=501, ["hotrina"]=502, ["hotrinb"]=503, ["bloodra"]=504, ["rnchlure"]=505, ["supergt"]=506, ["elegant"]=507, ["journey"]=508, ["bike"]=509, ["mtbike"]=510, ["beagle"]=511, ["cropdust"]=512, ["stunt"]=513, ["petro"]=514, ["rdtrain"]=515, ["nebula"]=516, ["majestic"]=517, ["buccanee"]=518, ["shamal"]=519, ["hydra"]=520, ["fcr900"]=521, ["nrg500"]=522, ["copbike"]=523, ["cement"]=524, ["towtruck"]=525, ["fortune"]=526, ["cadrona"]=527, ["fbitruck"]=528, ["willard"]=529, ["forklift"]=530, ["tractor"]=531, ["combine"]=532, ["feltzer"]=533, ["remingtn"]=534, ["slamvan"]=535, ["blade"]=536, ["freight"]=537, ["streak"]=538, ["vortex"]=539, ["vincent"]=540, ["bullet"]=541, ["clover"]=542, ["sadler"]=543, ["firela"]=544, ["hustler"]=545, ["intruder"]=546, ["primo"]=547, ["cargobob"]=548, ["tampa"]=549, ["sunrise"]=550, ["merit"]=551, ["utility"]=552, ["nevada"]=553, ["yosemite"]=554, ["windsor"]=555, ["monstera"]=556, ["monsterb"]=557, ["uranus"]=558, ["jester"]=559, ["sultan"]=560, ["stratum"]=561, ["elegy"]=562, ["raindanc"]=563, ["rctiger"]=564, ["flash"]=565, ["tahoma"]=566, ["savanna"]=567, ["bandito"]=568, ["freiflat"]=569, ["streakc"]=570, ["kart"]=571, ["mower"]=572, ["duneride"]=573, ["sweeper"]=574, ["broadway"]=575, ["tornado"]=576, ["at400"]=577, ["dft30"]=578, ["huntley"]=579, ["stafford"]=580, ["bf400"]=581, ["newsvan"]=582, ["tug"]=583, ["petrotr"]=584, ["emperor"]=585, ["wayfarer"]=586, ["euros"]=587, ["hotdog"]=588, ["club"]=589, ["freibox"]=590, ["artict3"]=591, ["androm"]=592, ["dodo"]=593, ["rccam"]=594, ["launch"]=595, ["copcarla"]=596, ["copcarsf"]=597, ["copcarvg"]=598, ["copcarru"]=599, ["picador"]=600, ["swatvan"]=601, ["alpha"]=602, ["phoenix"]=603, ["glenshit"]=604, ["sadlshit"]=605, ["bagboxa"]=606, ["bagboxb"]=607, ["tugstair"]=608, ["boxville"]=609, ["farmtr1"]=610, ["utiltr1"]=611,
    ["police_la"]=596, ["police_sf"]=597, ["police_vg"]=598, ["polranger"]=599, ["zr_350"]=477, ["pcj_600"]=461, ["fcr_900"]=521, ["nrg_500"]=522, ["bf_400"]=581, ["at_400"]=577, ["dft_30"]=578
}

local gtaPalette = {
    [0]=0x080808, [1]=0xF5F5F5, [2]=0x2A77A1, [3]=0x840410, [4]=0x263739, [5]=0x86446E, [6]=0xD78E10, [7]=0x4C75B7,
    [8]=0xBDBEC6, [9]=0x5E7072, [10]=0x46597A, [11]=0x656A79, [12]=0x5D7E8D, [13]=0x58595A, [14]=0xD6DAD6, [15]=0x9CA1A3,
    [16]=0x335F3F, [17]=0x730E1A, [18]=0x7B0A2A, [19]=0x9F9D94, [20]=0x3B4E78, [21]=0x732E3E, [22]=0x691E3B, [23]=0x96918C,
    [24]=0x515459, [25]=0x3F3E45, [26]=0xA5A9A7, [27]=0x635C5A, [28]=0x3D4A68, [29]=0x979592, [30]=0x421F21, [31]=0x5F272B,
    [32]=0x8494AB, [33]=0x767B7C, [34]=0x646464, [35]=0x5A5752, [36]=0x252527, [37]=0x2D3A35, [38]=0x93A396, [39]=0x6D7A88,
    [40]=0x221918, [41]=0x6F675F, [42]=0x7C1C2A, [43]=0x5F0A15, [44]=0x193826, [45]=0x5D1B20, [46]=0x9D9872, [47]=0x7A7560,
    [48]=0x989586, [49]=0xADB0B0, [50]=0x848988, [51]=0x304F45, [52]=0x4D6268, [53]=0x162248, [54]=0x272F4B, [55]=0x7D6256,
    [56]=0x9EA4AB, [57]=0x9C8D71, [58]=0x6D1822, [59]=0x4E6881, [60]=0x9C9C98, [61]=0x917347, [62]=0x661C26, [63]=0x949D9F,
    [64]=0xA4A7A5, [65]=0x8E8C46, [66]=0x341A1E, [67]=0x6A7A8C, [68]=0xAAAD8E, [69]=0xAB988F, [70]=0x851F2E, [71]=0x6F8297,
    [72]=0x585853, [73]=0x9AA790, [74]=0x601A23, [75]=0x20202C, [76]=0xA4A096, [77]=0xAA9D84, [78]=0x78222B, [79]=0x0E316D,
    [80]=0x722A3F, [81]=0x7B715E, [82]=0x741D28, [83]=0x1E2E32, [84]=0x4D322F, [85]=0x7C1B44, [86]=0x2E5B20, [87]=0x395A83,
    [88]=0x6D2837, [89]=0xA7A28F, [90]=0xAFB1B1, [91]=0x364155, [92]=0x6D6C6E, [93]=0x0F6A89, [94]=0x204B6B, [95]=0x2B3E57,
    [96]=0x9B9F9D, [97]=0x6C8495, [98]=0x4D8495, [99]=0xAE9B7F, [100]=0x406C8F, [101]=0x1F253B, [102]=0xAB9276, [103]=0x134573,
    [104]=0x96816C, [105]=0x64686A, [106]=0x105082, [107]=0xA19983, [108]=0x385694, [109]=0x525661, [110]=0x7F6956, [111]=0x8C929A,
    [112]=0x596E87, [113]=0x473532, [114]=0x44624F, [115]=0x730A27, [116]=0x223457, [117]=0x640D1B, [118]=0xA3ADC6, [119]=0x695853,
    [120]=0x9B8B80, [121]=0x620B1C, [122]=0x5B5D5E, [123]=0x624428, [124]=0x731827, [125]=0x1B376D, [126]=0xEC6AAE, [127]=0x000000,
    [128]=0x177517, [129]=0x210606, [130]=0x125478, [131]=0x452A0D, [132]=0x571E1E, [133]=0x010701, [134]=0x25225A, [135]=0x2C89AA,
    [136]=0x8A4DBD, [137]=0x35963A, [138]=0xB7B7B7, [139]=0x464C8D, [140]=0x84888C, [141]=0x817867, [142]=0x817A26, [143]=0x6A506F,
    [144]=0x583E6F, [145]=0x8CB972, [146]=0x824F78, [147]=0x6D276A, [148]=0x1E1D13, [149]=0x1E1306, [150]=0x1F2518, [151]=0x2C4531,
    [152]=0x1E4C99, [153]=0x2E5F43, [154]=0x1E9948, [155]=0x1E9999, [156]=0x999976, [157]=0x7C8499, [158]=0x992E1E, [159]=0x2C1E08,
    [160]=0x142407, [161]=0x993E4D, [162]=0x1E4C99, [163]=0x198181, [164]=0x1A292A, [165]=0x16616F, [166]=0x1B6687, [167]=0x6C3F99,
    [168]=0x481A0E, [169]=0x7A7399, [170]=0x746D99, [171]=0x53387E, [172]=0x222407, [173]=0x3E190C, [174]=0x46210E, [175]=0x991E1E,
    [176]=0x8D4C8D, [177]=0x805B80, [178]=0x7B3E7E, [179]=0x3C1737, [180]=0x733517, [181]=0x781818, [182]=0x83341A, [183]=0x8E2F1C,
    [184]=0x7E3E53, [185]=0x7C6D7C, [186]=0x020C02, [187]=0x072407, [188]=0x163012, [189]=0x16301B, [190]=0x642B4F, [191]=0x368452,
    [192]=0x999590, [193]=0x818D96, [194]=0x99991E, [195]=0x7F994C, [196]=0x839292, [197]=0x788222, [198]=0x2B3C99, [199]=0x3A3A0B,
    [200]=0x8A794E, [201]=0x0E1F49, [202]=0x15371C, [203]=0x15273A, [204]=0x375775, [205]=0x060820, [206]=0x071326, [207]=0x20394B,
    [208]=0x2C5089, [209]=0x15426C, [210]=0x103250, [211]=0x241663, [212]=0x692015, [213]=0x8C8D94, [214]=0x516013, [215]=0x090F02,
    [216]=0x8C573A, [217]=0x52888E, [218]=0x995C52, [219]=0x99581E, [220]=0x993A63, [221]=0x998F4E, [222]=0x99311E, [223]=0x0D1842,
    [224]=0x521E1E, [225]=0x42420D, [226]=0x4C991E, [227]=0x082A1D, [228]=0x96821D, [229]=0x197F19, [230]=0x3B141F, [231]=0x745217,
    [232]=0x893F8D, [233]=0x7E1A6C, [234]=0x0B370B, [235]=0x27450D, [236]=0x071F24, [237]=0x784573, [238]=0x8A653A, [239]=0x732617,
    [240]=0x319490, [241]=0x56941D, [242]=0x59163D, [243]=0x1B8A2F, [244]=0x38160B, [245]=0x041804, [246]=0x355D8E, [247]=0x2E3F5B,
    [248]=0x561A28, [249]=0x4E0E27, [250]=0x706C67, [251]=0x3B3E42, [252]=0x2E2D33, [253]=0x7B7E7D, [254]=0x4A4442, [255]=0x28344E
}

local presets = {}
local sessionColors = {}
local vehiclePlates = {}
local originalColors = {}
local previewedCarHandle = nil
local previewedCarId = nil

local vehicleModelsCache = {}
local modloaderModels = {}
local modelBools = {}
local cleanedVehicles = {}

for id = 400, 611 do
    modelBools[id] = imgui.new.bool(false)
end

local handlingFields = {
    { key = "suspForce",      label = "Suspension Force Level (Æ¸ñòêîñòü ïîäâåñêè)",      cat = 1, safe = true,  offset = 0xAC, type = "float", tokenIdx = 22 },
    { key = "suspDamping",    label = "Suspension Damping (Çàòóõàíèå àìîðòèçàòîðîâ)",     cat = 1, safe = true,  offset = 0xB0, type = "float", tokenIdx = 23 },
    { key = "suspHighSpd",    label = "High Speed Damping (Ñêîðîñòíîå äåìïôèðîâàíèå)",    cat = 1, safe = true,  offset = 0xB4, type = "float", tokenIdx = 24 },
    { key = "suspUpper",      label = "Suspension Upper Limit (Âåðõíèé ïðåäåë õîäà)",     cat = 1, safe = true,  offset = 0xB8, type = "float", tokenIdx = 25 },
    { key = "suspLower",      label = "Suspension Lower Limit (Âûñîòà ïîñàäêè / Êëèðåíñ)",cat = 1, safe = true,  offset = 0xBC, type = "float", tokenIdx = 26 },
    { key = "suspBias",       label = "Suspension Bias (Áàëàíñ ïîäâåñêè ïåðåä/çàä)",      cat = 1, safe = true,  offset = 0xC0, type = "float", tokenIdx = 27 },
    { key = "suspAntiDive",   label = "Suspension Anti-Dive (Àíòè-êëåâîê êóçîâà)",        cat = 1, safe = true,  offset = 0xC4, type = "float", tokenIdx = 28 },

    { key = "tractionMult",   label = "Traction Multiplier (Ñöåïëåíèå êîë¸ñ)",            cat = 2, safe = true,  offset = 0x28, type = "float", tokenIdx = 9  },
    { key = "tractionLoss",   label = "Traction Loss (Ïîòåðÿ ñöåïëåíèÿ)",                 cat = 2, safe = true,  offset = 0xA4, type = "float", tokenIdx = 10 },
    { key = "tractionBias",   label = "Traction Bias (Áàëàíñ ñöåïëåíèÿ îñåé)",            cat = 2, safe = true,  offset = 0xA8, type = "float", tokenIdx = 11 },
    { key = "steeringLock",   label = "Steering Lock (Óãîë âûâîðîòà êîë¸ñ)",              cat = 2, safe = true,  offset = 0xA0, type = "float", tokenIdx = 21 },
    { key = "comX",           label = "Centre Of Mass X (Öåíòð ìàññ X)",                  cat = 2, safe = true,  offset = 0x14, type = "float", tokenIdx = 5  },
    { key = "comY",           label = "Centre Of Mass Y (Öåíòð ìàññ Y)",                  cat = 2, safe = true,  offset = 0x18, type = "float", tokenIdx = 6  },
    { key = "comZ",           label = "Centre Of Mass Z (Öåíòð ìàññ Z / Âûñîòà)",         cat = 2, safe = true,  offset = 0x1C, type = "float", tokenIdx = 7  },

    { key = "mass",           label = "Mass (Ìàññà àâòîìîáèëÿ)",                          cat = 3, safe = false, offset = 0x04, type = "mass",  tokenIdx = 2  },
    { key = "turnMass",       label = "Turn Mass (Ïîâîðîòíàÿ ìàññà)",                     cat = 3, safe = false, offset = 0x0C, type = "float", tokenIdx = 3  },
    { key = "dragMult",       label = "Drag Multiplier (Ñîïðîòèâëåíèå âåòðà)",            cat = 3, safe = false, offset = 0x10, type = "float", tokenIdx = 4  },
    { key = "submerged",      label = "Percent Submerged (Ïîãðóæåíèå â âîäó %)",          cat = 3, safe = false, offset = 0x20, type = "int8",  tokenIdx = 8  },
    { key = "gears",          label = "Number of Gears (Êîëè÷åñòâî ïåðåäà÷)",             cat = 3, safe = false, offset = 0x76, type = "int8",  tokenIdx = 12 },
    { key = "engineAccel",    label = "Engine Acceleration (Óñêîðåíèå / Ðàçãîí)",         cat = 3, safe = false, offset = 0x7C, type = "accel", tokenIdx = 14 },
    { key = "engineInertia",  label = "Engine Inertia (Èíåðöèÿ äâèãàòåëÿ)",               cat = 3, safe = false, offset = 0x80, type = "float", tokenIdx = 15 },
    { key = "driveType",      label = "Drive Type (Òèï ïðèâîäà: RWD / FWD / AWD)",        cat = 3, safe = false, offset = 0x74, type = "drive", tokenIdx = 16 },
    { key = "engineType",     label = "Engine Type (Òèï äâèãàòåëÿ: P / D / E)",           cat = 3, safe = false, offset = 0x75, type = "eng",   tokenIdx = 17 },
    { key = "brakeDecel",     label = "Brake Deceleration (Ñèëà òîðìîæåíèÿ)",             cat = 3, safe = false, offset = 0x94, type = "brake", tokenIdx = 18 },
    { key = "brakeBias",      label = "Brake Bias (Áàëàíñ òîðìîçîâ)",                     cat = 3, safe = false, offset = 0x98, type = "float", tokenIdx = 19 },
    { key = "abs",            label = "ABS (Àíòèáëîêèðîâî÷íàÿ ñèñòåìà)",                  cat = 3, safe = false, offset = 0x9C, type = "abs",   tokenIdx = 20 },
    { key = "seatOffset",     label = "Seat Offset Distance (Ïîñàäêà ïåäà)",              cat = 3, safe = false, offset = 0xD4, type = "float", tokenIdx = 29 },
    { key = "colDamage",      label = "Collision Damage Mult (Ìíîæèòåëü óðîíà)",          cat = 3, safe = false, offset = 0xC8, type = "float", tokenIdx = 30 }
}

local importFieldChecks = {}
local manualBuffers = {}

for _, f in ipairs(handlingFields) do
    importFieldChecks[f.key] = imgui.new.bool(f.safe)
    if f.type == "int8" or f.type == "drive" or f.type == "eng" or f.type == "abs" then
        manualBuffers[f.key] = imgui.new.int(0)
    else
        manualBuffers[f.key] = imgui.new.float(0.0)
    end
end

local defaultHandlingBackup = {}
local savedHandlings = {}
local parsedImportState = {
    valid = false,
    message = "Âñòàâüòå ñòðîêó èç ôàéëà handling.cfg",
    detectedModel = nil,
    values = {},
    count = 0
}

local function clamp(val)
    return math.max(0.0, math.min(1.0, val))
end

local function trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$") or s
end

local function cp1251_lower(str)
    if not str then return "" end
    local res = {}
    for i = 1, #str do
        local b = str:byte(i)
        if b >= 192 and b <= 223 then
            res[i] = string.char(b + 32)
        elseif b == 168 then
            res[i] = string.char(184)
        elseif b >= 65 and b <= 90 then
            res[i] = string.char(b + 32)
        else
            res[i] = string.char(b)
        end
    end
    return table.concat(res)
end

local function cleanPlateText(s)
    if not s then return "" end
    local noHex = s:gsub("{%x%x%x%x%x%x}", "")
    return trim(noHex):upper()
end

local function showSystemNotification(text, nType, duration)
    if not settings.notifyEvents and nType ~= 0 then return end
    Sys.tempText = text
    Sys.tempType = nType or 0
    Sys.tempTimer = os.clock() + (duration or 3.5)
end

local function getPaletteVec4(idx)
    local hex = gtaPalette[idx]
    if not hex then
        local r = ((idx * 53) % 200) + 40
        local g = ((idx * 97) % 200) + 40
        local b = ((idx * 149) % 200) + 40
        return imgui.ImVec4(r / 255, g / 255, b / 255, 1.0)
    end
    local r = bit.band(bit.rshift(hex, 16), 0xFF) / 255.0
    local g = bit.band(bit.rshift(hex, 8), 0xFF) / 255.0
    local b = bit.band(hex, 0xFF) / 255.0
    return imgui.ImVec4(r, g, b, 1.0)
end

local function isLightColor(bgVec4)
    local lum = 0.299 * bgVec4.x + 0.587 * bgVec4.y + 0.114 * bgVec4.z
    return lum > 0.55
end

local function getContrastVec4(bgVec4)
    if isLightColor(bgVec4) then
        return theme.dark_text
    end
    return theme.white
end

local function getContrastTextColU32(bgVec4)
    return imgui.GetColorU32Vec4(getContrastVec4(bgVec4))
end

local function getContrastGrabVec4(bgVec4, isActive)
    if isLightColor(bgVec4) then
        return isActive and imgui.ImVec4(0.05, 0.05, 0.07, 0.95) or imgui.ImVec4(0.12, 0.12, 0.15, 0.80)
    end
    return isActive and imgui.ImVec4(1.00, 1.00, 1.00, 0.95) or imgui.ImVec4(0.90, 0.92, 0.96, 0.75)
end

local function clampColors()
    if UI.c1[0] > 255 then UI.c1[0] = 255 elseif UI.c1[0] < 0 then UI.c1[0] = 0 end
    if UI.c2[0] > 255 then UI.c2[0] = 255 elseif UI.c2[0] < 0 then UI.c2[0] = 0 end
    if UI.c3[0] > 255 then UI.c3[0] = 255 elseif UI.c3[0] < 0 then UI.c3[0] = 0 end
    if UI.c4[0] > 255 then UI.c4[0] = 255 elseif UI.c4[0] < 0 then UI.c4[0] = 0 end
end

local function getFullCarColors(car)
    local col1, col2 = getCarColours(car)
    local ok, col3, col4 = pcall(getExtraCarColours, car)
    if not ok then col3, col4 = 0, 0 end
    return {col1 or 0, col2 or 0, col3 or 0, col4 or 0}
end

local function applyColors(car, t)
    if not doesVehicleExist(car) then return end
    local want1, want2 = tonumber(t[1]) or 0, tonumber(t[2]) or 0
    local want3, want4 = tonumber(t[3]) or 0, tonumber(t[4]) or 0
    changeCarColour(car, want1, want2)
    setExtraCarColours(car, want3, want4)
end

local unsavedCarColors = {}

local function getPresetForVehicle(id)
    if not id then return nil end
    local rawPlate = vehiclePlates[id]
    if rawPlate then
        local cleanP = cleanPlateText(rawPlate)
        if cleanP ~= "" and sessionColors[cleanP] then
            return sessionColors[cleanP]
        end
        local upperRaw = trim(rawPlate):upper()
        if sessionColors[upperRaw] then
            return sessionColors[upperRaw]
        end
    end
    return nil
end

local function getEffectiveVehicleColor(id, car)
    if car and unsavedCarColors[car] then
        return unsavedCarColors[car]
    end
    if id then
        return getPresetForVehicle(id)
    end
    return nil
end

local function restoreVehicleColor(id, car)
    if not doesVehicleExist(car) then return end
    local activeCol = getEffectiveVehicleColor(id, car)
    if activeCol then
        applyColors(car, activeCol)
    elseif id and originalColors[id] then
        applyColors(car, originalColors[id])
    end
end

local function getHandlingIdByModel(modelId)
    modelId = tonumber(modelId)
    if not modelId or modelId < 400 or modelId > 611 then return nil end
    local modelInfoPtr = mem.getint32(modelId * 0x4 + 0xA9B0C8, false)
    if not modelInfoPtr or modelInfoPtr == 0 then return nil end
    local handlingId = mem.getint16(modelInfoPtr + 0x4A, false)
    if not handlingId or handlingId < 0 or handlingId >= 210 then return nil end
    return handlingId
end

local function getHandlingBaseAddr(modelId)
    local hId = getHandlingIdByModel(modelId)
    if not hId then return nil, nil end
    return 0xC2B9DC + (hId * 0xE0), hId
end

local function readHandlingField(baseAddr, field)
    local addr = baseAddr + field.offset
    if field.type == "float" or field.type == "mass" then
        return mem.getfloat(addr, false)
    elseif field.type == "accel" then
        return mem.getfloat(addr, false) * 12500.0
    elseif field.type == "brake" then
        return mem.getfloat(addr, false) * 2500.0
    elseif field.type == "int8" or field.type == "drive" or field.type == "eng" or field.type == "abs" then
        return mem.getint8(addr, false)
    end
    return 0
end

local function writeHandlingField(baseAddr, field, val)
    if val == nil then return end
    local addr = baseAddr + field.offset
    if field.type == "float" then
        mem.setfloat(addr, tonumber(val) or 0.0, false)
    elseif field.type == "mass" then
        local m = tonumber(val) or 1000.0
        if m < 1.0 then m = 1.0 end
        mem.setfloat(addr, m, false)
        mem.setfloat(baseAddr + 0x08, 1.0 / m, false)
    elseif field.type == "accel" then
        mem.setfloat(addr, (tonumber(val) or 0.0) / 12500.0, false)
    elseif field.type == "brake" then
        local b = tonumber(val) or 0.0
        if b > 100.0 then
            mem.setfloat(addr, b / 12500.0, false)
        else
            mem.setfloat(addr, b / 2500.0, false)
        end
    elseif field.type == "int8" then
        local n = math.floor(tonumber(val) or 1)
        if field.key == "gears" and n < 1 then n = 1 end
        mem.setint8(addr, n, false)
    elseif field.type == "drive" or field.type == "eng" then
        mem.setint8(addr, math.floor(tonumber(val) or 82), false)
    elseif field.type == "abs" then
        mem.setint8(addr, (tonumber(val) and tonumber(val) >= 1) and 1 or 0, false)
    end
end

local function backupDefaultHandling(modelId)
    modelId = tonumber(modelId)
    if not modelId or defaultHandlingBackup[modelId] then return end
    local baseAddr = getHandlingBaseAddr(modelId)
    if not baseAddr then return end
    local snap = {}
    for _, f in ipairs(handlingFields) do
        snap[f.key] = readHandlingField(baseAddr, f)
    end
    defaultHandlingBackup[modelId] = snap
end

local function refreshStreamedVehiclesSuspension(modelId)
    modelId = tonumber(modelId)
    if not modelId then return end
    local baseAddr = getHandlingBaseAddr(modelId)
    if not baseAddr then return end
    local cx = mem.getfloat(baseAddr + 0x14, false)
    local cy = mem.getfloat(baseAddr + 0x18, false)
    local cz = mem.getfloat(baseAddr + 0x1C, false)

    for _, car in ipairs(getAllVehicles()) do
        if doesVehicleExist(car) and getCarModel(car) == modelId then
            local pVeh = getCarPointer(car)
            if pVeh and pVeh ~= 0 then
                mem.setfloat(pVeh + 0x98, cx, false)
                mem.setfloat(pVeh + 0x9C, cy, false)
                mem.setfloat(pVeh + 0xA0, cz, false)
                local vehClass = mem.getint32(pVeh + 0x590, false)
                if vehClass == 0 then
                    pcall(SetupSuspensionLines, ffi.cast("void*", pVeh))
                end
            end
        end
    end
end

local function loadModelHandlingToManualUI(modelId)
    modelId = tonumber(modelId)
    if not modelId then return end
    backupDefaultHandling(modelId)
    local baseAddr = getHandlingBaseAddr(modelId)
    if not baseAddr then return end
    for _, f in ipairs(handlingFields) do
        local val = readHandlingField(baseAddr, f)
        if f.type == "drive" then
            if val == 82 then manualBuffers[f.key][0] = 0
            elseif val == 70 then manualBuffers[f.key][0] = 1
            else manualBuffers[f.key][0] = 2 end
        elseif f.type == "eng" then
            if val == 80 then manualBuffers[f.key][0] = 0
            elseif val == 68 then manualBuffers[f.key][0] = 1
            else manualBuffers[f.key][0] = 2 end
        elseif f.type == "abs" then
            manualBuffers[f.key][0] = (val >= 1) and 1 or 0
        elseif f.type == "int8" then
            manualBuffers[f.key][0] = math.floor(val)
        else
            manualBuffers[f.key][0] = val
        end
    end
end

local function formatHandlingValue(field, val)
    if val == nil then return "-" end
    if field.type == "drive" then
        if val == 82 then return "RWD (R)"
        elseif val == 70 then return "FWD (F)"
        elseif val == 52 then return "AWD (4)" end
        return tostring(val)
    elseif field.type == "eng" then
        if val == 80 then return "Petrol (P)"
        elseif val == 68 then return "Diesel (D)"
        elseif val == 69 then return "Electric (E)" end
        return tostring(val)
    elseif field.type == "abs" then
        return (val >= 1) and "ÂÊË (1)" or "ÂÛÊË (0)"
    elseif field.type == "int8" then
        return string.format("%d", math.floor(val))
    else
        return string.format("%.3f", tonumber(val) or 0.0)
    end
end

local function parseHandlingString(rawLine)
    local clean = trim(rawLine or "")
    if clean == "" then
        parsedImportState.valid = false
        parsedImportState.message = "Âñòàâüòå ñòðîêó èç ôàéëà handling.cfg"
        parsedImportState.values = {}
        parsedImportState.detectedModel = nil
        parsedImportState.count = 0
        return
    end

    clean = clean:gsub("^;", ""):gsub("\t", " ")
    local rawTokens = {}
    for tok in clean:gmatch("%S+") do
        rawTokens[#rawTokens + 1] = tok
    end

    if #rawTokens < 18 then
        parsedImportState.valid = false
        parsedImportState.message = string.format("Íåäîñòàòî÷íî çíà÷åíèé â ñòðîêå (íàéäåíî %d, íóæíî ìèíèìóì 25)", #rawTokens)
        parsedImportState.values = {}
        parsedImportState.detectedModel = nil
        parsedImportState.count = 0
        return
    end

    local drivePos = nil
    for i = 10, math.min(#rawTokens - 1, 22) do
        local t1 = rawTokens[i]:upper()
        local t2 = rawTokens[i + 1]:upper()
        if (t1 == "R" or t1 == "F" or t1 == "4") and (t2 == "P" or t2 == "D" or t2 == "E") then
            drivePos = i
            break
        end
    end

    local offsetShift = 0
    local detectedModel = nil

    if drivePos then
        offsetShift = drivePos - 16
        if offsetShift >= 0 and rawTokens[1] then
            local tok1Low = rawTokens[1]:lower()
            local num1 = tonumber(rawTokens[1])
            if dffToId[tok1Low] then
                detectedModel = dffToId[tok1Low]
            elseif num1 and num1 >= 400 and num1 <= 611 and offsetShift == 0 then
                detectedModel = num1
            else
                for id = 400, 611 do
                    if vehicleNames[id] and vehicleNames[id]:lower() == tok1Low then
                        detectedModel = id
                        break
                    end
                end
            end
        end
    else
        local firstNum = tonumber((rawTokens[1]:gsub(",", ".")))
        if firstNum and firstNum > 50 and tonumber((rawTokens[2]:gsub(",", "."))) then
            offsetShift = -1
        else
            offsetShift = 0
        end
    end

    local values = {}
    local count = 0

    for _, f in ipairs(handlingFields) do
        local idx = f.tokenIdx + offsetShift
        local tok = rawTokens[idx]
        if tok then
            if f.type == "drive" then
                local u = tok:upper()
                if u == "R" then values[f.key] = 82; count = count + 1
                elseif u == "F" then values[f.key] = 70; count = count + 1
                elseif u == "4" then values[f.key] = 52; count = count + 1 end
            elseif f.type == "eng" then
                local u = tok:upper()
                if u == "P" then values[f.key] = 80; count = count + 1
                elseif u == "D" then values[f.key] = 68; count = count + 1
                elseif u == "E" then values[f.key] = 69; count = count + 1 end
            elseif f.type == "abs" then
                local n = tonumber((tok:gsub(",", ".")))
                if n ~= nil then
                    values[f.key] = (n >= 1) and 1 or 0
                    count = count + 1
                end
            elseif f.type == "int8" then
                local n = tonumber((tok:gsub(",", ".")))
                if n ~= nil then
                    values[f.key] = math.floor(n)
                    count = count + 1
                end
            else
                local n = tonumber((tok:gsub(",", ".")))
                if n ~= nil then
                    values[f.key] = n
                    count = count + 1
                end
            end
        end
    end

    parsedImportState.values = values
    parsedImportState.count = count
    parsedImportState.detectedModel = detectedModel
    if count >= 10 then
        parsedImportState.valid = true
        parsedImportState.message = string.format("Ñòðîêà ðàñïîçíàíà (ïàðàìåòðîâ: %d | Ìàêñ. ñêîðîñòü è ôëàãè ïðîïóùåíû)", count)
    else
        parsedImportState.valid = false
        parsedImportState.message = "Íå óäàëîñü ðàñïîçíàòü ÷èñëîâûå ïàðàìåòðû ñòðîêè handling.cfg"
    end
end

local function applySafeModeSelection(isSafe)
    for _, f in ipairs(handlingFields) do
        if isSafe then
            importFieldChecks[f.key][0] = f.safe
        else
            importFieldChecks[f.key][0] = true
        end
    end
end

local function saveConfig()
    local sdPresets = {}
    for _, p in ipairs(presets) do
        table.insert(sdPresets, {
            plate = p.plate_str,
            c1 = p.c1, c2 = p.c2, c3 = p.c3, c4 = p.c4
        })
    end

    local sdModels = {}
    for id = 400, 611 do
        if modelBools[id][0] then
            sdModels[tostring(id)] = true
        end
    end

    local sdHandling = {}
    for modelId, hData in pairs(savedHandlings) do
        sdHandling[tostring(modelId)] = {
            enabled = hData.enabled,
            safeMode = hData.safeMode,
            rawLine = hData.rawLine or "",
            values = hData.values or {}
        }
    end

    local data = {
        settings = settings,
        paint = {
            presets = sdPresets
        },
        tune = {
            models = sdModels
        },
        handling = sdHandling
    }

    local f = io.open(configPath, "w")
    if f then
        f:write(encodeJson(data))
        f:close()
    end
end

local function applySavedHandlingEntry(modelId, entry)
    modelId = tonumber(modelId)
    if not modelId or not entry or not entry.values then return false end
    backupDefaultHandling(modelId)
    local baseAddr = getHandlingBaseAddr(modelId)
    if not baseAddr then return false end

    if defaultHandlingBackup[modelId] then
        for _, f in ipairs(handlingFields) do
            writeHandlingField(baseAddr, f, defaultHandlingBackup[modelId][f.key])
        end
    end

    for _, f in ipairs(handlingFields) do
        local v = entry.values[f.key]
        if v ~= nil then
            writeHandlingField(baseAddr, f, v)
        end
    end

    refreshStreamedVehiclesSuspension(modelId)
    return true
end

local function resetModelHandlingToDefault(modelId)
    modelId = tonumber(modelId)
    if not modelId then return false end
    local baseAddr = getHandlingBaseAddr(modelId)
    if not baseAddr or not defaultHandlingBackup[modelId] then return false end

    for _, f in ipairs(handlingFields) do
        writeHandlingField(baseAddr, f, defaultHandlingBackup[modelId][f.key])
    end

    refreshStreamedVehiclesSuspension(modelId)
    return true
end

local function syncSettingsToUI()
    UI.uiScaleArr[0] = settings.uiScale
    UI.notifyEventsBool[0] = settings.notifyEvents
    UI.livePreviewBool[0] = settings.livePreview
    UI.showPaletteBool[0] = settings.showPalette
    UI.keepUnsavedBool[0] = settings.keepUnsavedColor
    UI.disableAllBool[0] = settings.disableAllTune
    UI.disableVinylsBool[0] = settings.disableVinyls
    UI.autoModloaderBool[0] = settings.autoModloader
    UI.autoApplyHandlingBool[0] = settings.autoApplyHandling
    UI.autoUpdateBool[0] = settings.autoUpdate
end

local function convertUtf8ToCp1251IfNeeded(code)
    if not code or code == "" then return code, false end
    local changed = false

    if code:sub(1, 3) == "\239\187\191" then
        code = code:sub(4)
        changed = true
    end

    if code:find("\195[\128-\191]\195[\128-\191]") then
        code = code:gsub("\195([\128-\191])", function(c)
            return string.char(c:byte(1) + 64)
        end)
        code = code:gsub("\194([\128-\191])", function(c)
            return c
        end)
        changed = true
    end

    if code:find("[\208\209][\128-\191][\208\209][\128-\191]") then
        local ok, decoded = pcall(function() return u8:decode(code) end)
        if ok and decoded and decoded ~= "" and not decoded:find("[\208\209][\128-\191][\208\209][\128-\191]") then
            code = decoded
        else
            code = code
                :gsub("\226\128\162", "\149")
                :gsub("\226\128\148", "\151")
                :gsub("\226\128\147", "\150")
                :gsub("\226\132\150", "\185")
                :gsub("\194\171", "\171")
                :gsub("\194\187", "\187")
                :gsub("\208\129", "\168")
                :gsub("\209\145", "\184")
                :gsub("\208([\144-\191])", function(c) return string.char(c:byte(1) + 48) end)
                :gsub("\209([\128-\143])", function(c) return string.char(c:byte(1) + 112) end)
        end
        changed = true
    end

    return code, changed
end

local function ensureSelfEncodingCP1251()
    local scriptPath = thisScript().path
    local f = io.open(scriptPath, "rb")
    if not f then return false end
    local content = f:read("*a")
    f:close()
    local fixedCode, wasChanged = convertUtf8ToCp1251IfNeeded(content)
    if wasChanged and fixedCode then
        local fOut = io.open(scriptPath, "wb")
        if fOut then
            fOut:write(fixedCode)
            fOut:close()
            lua_thread.create(function()
                wait(100)
                thisScript():reload()
            end)
            return true
        end
    end
    return false
end

local function checkUpdates(is_manual)
    if not settings.autoUpdate and not is_manual then return end

    local updateFile_tmp = configDir .. "\\cartool_update_" .. tostring(math.random(100000, 999999)) .. ".json"
    activeTempFiles[updateFile_tmp] = true

    if is_manual then
        showSystemNotification(u8"Ïðîâåðêà îáíîâëåíèé...", 3)
    end

    local url_no_cache = updateUrl .. "?t=" .. tostring(os.time())
    downloadUrlToFile(url_no_cache, updateFile_tmp, function(id, status)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            local f = io.open(updateFile_tmp, "rb")
            local content = nil
            if f then
                content = f:read("*a")
                f:close()
            end
            pcall(os.remove, updateFile_tmp)
            activeTempFiles[updateFile_tmp] = nil

            if content and content ~= "" then
                local data = nil
                local ok, res = pcall(decodeJson, content)
                if ok and type(res) == "table" then
                    data = res
                else
                    pcall(function()
                        local func = load("return " .. content)
                        if func then data = func() end
                    end)
                end

                if data and data.version and data.url then
                    if tonumber(data.version) > tonumber(script_version) then
                        local is_silent = (data.silent == true) and not is_manual

                        if not is_silent then
                            showSystemNotification(u8"Íàéäåíî îáíîâëåíèå! Çàãðóçêà...", 3)
                        end

                        lua_thread.create(function()
                            wait(100)
                            local scriptPath = thisScript().path
                            local tempPath = scriptPath .. tostring(math.random(10000, 99999)) .. ".tmp"
                            activeTempFiles[tempPath] = true

                            local dl_url_no_cache = data.url .. "?t=" .. tostring(os.time())
                            downloadUrlToFile(dl_url_no_cache, tempPath, function(id2, status2)
                                if status2 == dlstatus.STATUS_ENDDOWNLOADDATA then
                                    local fTmp = io.open(tempPath, "rb")
                                    if fTmp then
                                        local newCode = fTmp:read("*a")
                                        fTmp:close()
                                        pcall(os.remove, tempPath)
                                        activeTempFiles[tempPath] = nil

                                        newCode = convertUtf8ToCp1251IfNeeded(newCode)

                                        local fOut = io.open(scriptPath, "wb")
                                        if fOut then
                                            fOut:write(newCode)
                                            fOut:close()
                                            if not is_silent then
                                                showSystemNotification(u8"Óñïåøíî îáíîâëåíî! Ïåðåçàïóñê...", 1)
                                            end
                                            lua_thread.create(function()
                                                wait(1500)
                                                thisScript():reload()
                                            end)
                                        elseif not is_silent then
                                            showSystemNotification(u8"Îøèáêà: Ôàéë ñêðèïòà çàíÿò!", 2)
                                        end
                                    end
                                elseif status2 == dlstatus.STATUS_EX_ERROR then
                                    pcall(os.remove, tempPath)
                                    activeTempFiles[tempPath] = nil
                                    if not is_silent then
                                        showSystemNotification(u8"Îøèáêà ïðè ñêà÷èâàíèè îáíîâëåíèÿ!", 2)
                                    end
                                end
                            end)
                        end)
                    else
                        if is_manual then
                            showSystemNotification(u8"Ó âàñ óñòàíîâëåíà ïîñëåäíÿÿ âåðñèÿ!", 1)
                        end
                    end
                else
                    if is_manual then
                        showSystemNotification(u8"Îøèáêà: Íåâåðíûé ôîðìàò îòâåòà îò ñåðâåðà!", 2)
                    end
                end
            else
                if is_manual then
                    showSystemNotification(u8"Îøèáêà: Ïóñòîé îòâåò îò ñåðâåðà GitHub!", 2)
                end
            end
        elseif status == dlstatus.STATUS_EX_ERROR then
            pcall(os.remove, updateFile_tmp)
            activeTempFiles[updateFile_tmp] = nil
            if is_manual then
                showSystemNotification(u8"Îøèáêà ñîåäèíåíèÿ ñ GitHub!", 2)
            end
        end
    end)
end

local function loadConfig()
    if doesFileExist(configPath) then
        local f = io.open(configPath, "r")
        if f then
            local ok, data = pcall(decodeJson, f:read("*a"))
            f:close()
            if ok and type(data) == "table" then
                if type(data.settings) == "table" then
                    for k, v in pairs(data.settings) do
                        if settings[k] ~= nil then settings[k] = v end
                    end
                end
                if type(data.paint) == "table" and type(data.paint.presets) == "table" then
                    presets = {}
                    sessionColors = {}
                    for _, p in ipairs(data.paint.presets) do
                        local plateText = tostring(p.plate or "")
                        local buf = imgui.new.char[64]()
                        ffi.fill(buf, ffi.sizeof(buf), 0)
                        ffi.copy(buf, u8(plateText))
                        local col1 = tonumber(p.c1) or 0
                        local col2 = tonumber(p.c2) or 0
                        local col3 = tonumber(p.c3) or 0
                        local col4 = tonumber(p.c4) or 0
                        table.insert(presets, {
                            plate_buf = buf,
                            plate_str = plateText,
                            c1 = col1, c2 = col2, c3 = col3, c4 = col4
                        })
                        local cleanStr = cleanPlateText(plateText)
                        if cleanStr ~= "" then
                            sessionColors[cleanStr] = {col1, col2, col3, col4}
                        end
                    end
                end
                if type(data.tune) == "table" and type(data.tune.models) == "table" then
                    for k, v in pairs(data.tune.models) do
                        local num = tonumber(k)
                        if num and modelBools[num] then
                            modelBools[num][0] = (v == true)
                        end
                    end
                end
                if type(data.handling) == "table" then
                    savedHandlings = {}
                    for k, v in pairs(data.handling) do
                        local mId = tonumber(k)
                        if mId and type(v) == "table" and type(v.values) == "table" then
                            savedHandlings[mId] = {
                                enabled = (v.enabled ~= false),
                                safeMode = (v.safeMode ~= false),
                                rawLine = tostring(v.rawLine or ""),
                                values = v.values
                            }
                        end
                    end
                end
            end
        end
    end

    syncSettingsToUI()
    saveConfig()
end

local function scanModloader()
    modloaderModels = {}
    if not hasLfs then return end
    local mlPath = getGameDirectory() .. "\\modloader\\"
    if not lfs.attributes(mlPath) then return end

    local function scanDir(path)
        for file in lfs.dir(path) do
            if file ~= "." and file ~= ".." then
                local fPath = path .. file
                local attr = lfs.attributes(fPath)
                if attr and attr.mode == "directory" then
                    scanDir(fPath .. "\\")
                elseif attr and attr.mode == "file" then
                    if file:lower():match("%.dff$") then
                        local baseName = file:lower():gsub("%.dff$", "")
                        local id = dffToId[baseName]
                        if id then modloaderModels[id] = true end
                    end
                end
            end
        end
    end
    pcall(scanDir, mlPath)
end

local function checkShouldDisableTune(model)
    if settings.disableAllTune then return true end
    if not model then return false end
    model = tonumber(model)
    if settings.autoModloader and modloaderModels[model] then return true end
    if modelBools[model] and modelBools[model][0] then return true end
    return false
end

local function stripTuningAndVinylFromCar(carHandle, sampVehicleId, forceVinylStrip)
    if not doesVehicleExist(carHandle) then return end
    local model = getCarModel(carHandle)
    if not checkShouldDisableTune(model) then return end

    for slot = 0, 16 do
        local compId = getCurrentCarMod(carHandle, slot)
        if compId and compId > 0 then
            removeVehicleMod(carHandle, compId)
        end
    end

    if settings.disableVinyls and (forceVinylStrip or not cleanedVehicles[carHandle]) then
        cleanedVehicles[carHandle] = true
        pcall(giveVehiclePaintjob, carHandle, 3)
        restoreVehicleColor(sampVehicleId, carHandle)
    end
end

local function purgeAllStreamedVehicles()
    cleanedVehicles = {}
    for _, car in ipairs(getAllVehicles()) do
        if doesVehicleExist(car) then
            local ok, vid = sampGetVehicleIdByCarHandle(car)
            local validId = ok and vid or nil
            if validId then
                vehicleModelsCache[validId] = getCarModel(car)
            end
            stripTuningAndVinylFromCar(car, validId, true)
            if validId then
                restoreVehicleColor(validId, car)
            end
        end
    end
end

function sampev.onSetVehicleNumberPlate(id, text)
    vehiclePlates[id] = text
    local preset = getPresetForVehicle(id)
    if preset then
        lua_thread.create(function()
            wait(0)
            local res, handle = sampGetCarHandleBySampVehicleId(id)
            if res and doesVehicleExist(handle) then
                applyColors(handle, preset)
            end
        end)
    end
end

function sampev.onChangeVehicleColor(vehicleId, color1, color2)
    originalColors[vehicleId] = {color1, color2, 0, 0}
    local preset = getPresetForVehicle(vehicleId)
    if preset then
        return {vehicleId, preset[1], preset[2]}
    end
end

function sampev.onVehicleStreamIn(vehicleId, data)
    vehicleModelsCache[vehicleId] = data.type
    if data.text and data.text ~= "" then
        vehiclePlates[vehicleId] = data.text
    end
    originalColors[vehicleId] = {data.bodyColor1, data.bodyColor2, 0, 0}

    local modified = false
    local preset = getPresetForVehicle(vehicleId)
    if preset then
        data.bodyColor1 = preset[1]
        data.bodyColor2 = preset[2]
        modified = true
    end

    if checkShouldDisableTune(data.type) then
        for i = 1, 14 do
            if data.modSlots[i] ~= 0 then
                data.modSlots[i] = 0
            end
        end
        if settings.disableVinyls then
            data.paintjob = 3
        end
        modified = true

        lua_thread.create(function()
            wait(100)
            local res, handle = sampGetCarHandleBySampVehicleId(vehicleId)
            if res and doesVehicleExist(handle) then
                stripTuningAndVinylFromCar(handle, vehicleId, true)
            end
        end)
    end

    if modified then
        return {vehicleId, data}
    end
end

function sampev.onVehicleStreamOut(vehicleId)
    vehicleModelsCache[vehicleId] = nil
end

function sampev.onAddVehicleComponent(vehicleId, componentId)
    local model = vehicleModelsCache[vehicleId]
    if not model then
        local result, handle = sampGetCarHandleBySampVehicleId(vehicleId)
        if result and doesVehicleExist(handle) then
            model = getCarModel(handle)
            vehicleModelsCache[vehicleId] = model
        end
    end
    if checkShouldDisableTune(model) then
        return false
    end
end

function sampev.onChangeVehiclePaintjob(vehicleId, paintjobId)
    local model = vehicleModelsCache[vehicleId]
    local result, handle = sampGetCarHandleBySampVehicleId(vehicleId)
    if not model and result and doesVehicleExist(handle) then
        model = getCarModel(handle)
        vehicleModelsCache[vehicleId] = model
    end
    if checkShouldDisableTune(model) and settings.disableVinyls then
        if result and doesVehicleExist(handle) then
            lua_thread.create(function()
                wait(50)
                if doesVehicleExist(handle) then
                    pcall(giveVehiclePaintjob, handle, 3)
                    restoreVehicleColor(vehicleId, handle)
                end
            end)
        end
        return false
    end
end

local function styleButton(label, col, size)
    local hov = imgui.ImVec4(clamp(col.x + 0.10), clamp(col.y + 0.10), clamp(col.z + 0.10), 1.0)
    local act = imgui.ImVec4(clamp(col.x - 0.08), clamp(col.y - 0.08), clamp(col.z - 0.08), 1.0)
    imgui.PushStyleColor(imgui.Col.Button, col)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, hov)
    imgui.PushStyleColor(imgui.Col.ButtonActive, act)
    local pressed = false
    if size then
        pressed = imgui.Button(label, size)
    else
        pressed = imgui.Button(label)
    end
    imgui.PopStyleColor(3)
    return pressed
end

local function disabledButton(label, size)
    local disBg = imgui.ImVec4(0.18, 0.18, 0.18, 0.65)
    imgui.PushStyleColor(imgui.Col.Button, disBg)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, disBg)
    imgui.PushStyleColor(imgui.Col.ButtonActive, disBg)
    imgui.PushStyleColor(imgui.Col.Text, theme.muted)
    if size then
        imgui.Button(label, size)
    else
        imgui.Button(label)
    end
    imgui.PopStyleColor(4)
end

local function ToggleButton(str_id, bool_ptr, scale, customOnCol)
    local draw_list = imgui.GetWindowDrawList()
    local pos = imgui.GetCursorScreenPos()
    local height = imgui.GetFrameHeight()
    local width = height * 1.65
    local radius = height * 0.50

    local clicked = imgui.InvisibleButton(str_id, imgui.ImVec2(width, height))
    if clicked then
        bool_ptr[0] = not bool_ptr[0]
    end
    if imgui.IsItemHovered() then
        imgui.SetMouseCursor(imgui.MouseCursor.Hand)
    end

    local activeCol = customOnCol or theme.me
    local col_bg = imgui.GetColorU32Vec4(bool_ptr[0] and activeCol or theme.them)
    draw_list:AddRectFilled(pos, imgui.ImVec2(pos.x + width, pos.y + height), col_bg, radius)
    local circle_x = bool_ptr[0] and (pos.x + width - radius) or (pos.x + radius)
    draw_list:AddCircleFilled(imgui.ImVec2(circle_x, pos.y + radius), radius - 2.0 * scale, imgui.GetColorU32Vec4(theme.white))

    return clicked
end

local function DrawColorBoxWithId(str_id, colorIdx, width, height, scale, isSelected)
    local dl = imgui.GetWindowDrawList()
    local pMin = imgui.GetCursorScreenPos()
    local pMax = imgui.ImVec2(pMin.x + width, pMin.y + height)
    local rounding = 6.0 * scale

    local clicked = imgui.InvisibleButton(str_id, imgui.ImVec2(width, height))
    local hovered = imgui.IsItemHovered()
    if hovered then
        imgui.SetMouseCursor(imgui.MouseCursor.Hand)
    end

    local bgVec4 = getPaletteVec4(colorIdx)
    dl:AddRectFilled(pMin, pMax, imgui.GetColorU32Vec4(bgVec4), rounding, 15)

    local borderCol = isSelected and theme.white or imgui.ImVec4(0.55, 0.55, 0.58, 0.65)
    local borderThick = isSelected and (2.0 * scale) or 1.0
    dl:AddRect(pMin, pMax, imgui.GetColorU32Vec4(borderCol), rounding, 15, borderThick)

    local idStr = tostring(colorIdx)
    local tSize = imgui.CalcTextSize(idStr)
    local tx = pMin.x + (width - tSize.x) * 0.5
    local ty = pMin.y + (height - tSize.y) * 0.5
    dl:AddText(imgui.ImVec2(tx, ty), getContrastTextColU32(bgVec4), idStr)

    return clicked, hovered
end

local function ApplyMessengerStyle(scale)
    local acc = theme.me
    local bg = theme.them

    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 6.0 * scale)
    imgui.PushStyleVarFloat(imgui.StyleVar.GrabRounding, 5.0 * scale)
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 6.0 * scale)
    imgui.PushStyleVarFloat(imgui.StyleVar.PopupRounding, 10.0 * scale)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 8.0 * scale)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 1.0)
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(8.0 * scale, 6.0 * scale))
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(14.0 * scale, 14.0 * scale))

    imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(clamp(bg.x * 0.3), clamp(bg.y * 0.3), clamp(bg.z * 0.3), 0.95))
    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(clamp(bg.x * 0.25), clamp(bg.y * 0.25), clamp(bg.z * 0.25), 0.70))
    imgui.PushStyleColor(imgui.Col.PopupBg, imgui.ImVec4(clamp(bg.x * 0.25), clamp(bg.y * 0.25), clamp(bg.z * 0.25), 0.98))
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(clamp(bg.x + 0.12), clamp(bg.y + 0.12), clamp(bg.z + 0.12), 0.50))
    imgui.PushStyleColor(imgui.Col.Button, acc)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(clamp(acc.x + 0.1), clamp(acc.y + 0.1), clamp(acc.z + 0.1), 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(clamp(acc.x - 0.1), clamp(acc.y - 0.1), clamp(acc.z - 0.1), 1.0))
    imgui.PushStyleColor(imgui.Col.Header, acc)
    imgui.PushStyleColor(imgui.Col.HeaderHovered, imgui.ImVec4(clamp(acc.x + 0.1), clamp(acc.y + 0.1), clamp(acc.z + 0.1), 0.8))
    imgui.PushStyleColor(imgui.Col.HeaderActive, imgui.ImVec4(clamp(acc.x - 0.1), clamp(acc.y - 0.1), clamp(acc.z - 0.1), 1.0))
    imgui.PushStyleColor(imgui.Col.FrameBg, bg)
    imgui.PushStyleColor(imgui.Col.FrameBgHovered, imgui.ImVec4(clamp(bg.x + 0.1), clamp(bg.y + 0.1), clamp(bg.z + 0.1), 0.8))
    imgui.PushStyleColor(imgui.Col.FrameBgActive, bg)
    imgui.PushStyleColor(imgui.Col.TitleBg, imgui.ImVec4(clamp(bg.x * 0.4), clamp(bg.y * 0.4), clamp(bg.z * 0.4), 1.0))
    imgui.PushStyleColor(imgui.Col.TitleBgActive, acc)
    imgui.PushStyleColor(imgui.Col.TextSelectedBg, imgui.ImVec4(acc.x, acc.y, acc.z, 0.5))
    imgui.PushStyleColor(imgui.Col.ModalWindowDimBg, imgui.ImVec4(0.0, 0.0, 0.0, 0.6))
    imgui.PushStyleColor(imgui.Col.ScrollbarBg, imgui.ImVec4(bg.x, bg.y, bg.z, 0.3))
    imgui.PushStyleColor(imgui.Col.ScrollbarGrab, acc)
    imgui.PushStyleColor(imgui.Col.ScrollbarGrabHovered, imgui.ImVec4(clamp(acc.x + 0.1), clamp(acc.y + 0.1), clamp(acc.z + 0.1), 1.0))
    imgui.PushStyleColor(imgui.Col.ScrollbarGrabActive, imgui.ImVec4(clamp(acc.x - 0.1), clamp(acc.y - 0.1), clamp(acc.z - 0.1), 1.0))
    imgui.PushStyleColor(imgui.Col.CheckMark, acc)
    imgui.PushStyleColor(imgui.Col.SliderGrab, acc)
    imgui.PushStyleColor(imgui.Col.SliderGrabActive, imgui.ImVec4(clamp(acc.x + 0.1), clamp(acc.y + 0.1), clamp(acc.z + 0.1), 1.0))
end

local function PopMessengerStyle()
    imgui.PopStyleColor(24)
    imgui.PopStyleVar(8)
end

addEventHandler("onWindowMessage", function(msg, wparam, lparam)
    if msg == 0x0100 or msg == 0x0101 then
        if wparam == vkeys.VK_ESCAPE and (UI.windowState[0] or UI.importModal[0]) then
            if sampIsChatInputActive() then return end
            consumeWindowMessage(true, false)
            if msg == 0x0100 then
                local intercepted = false
                if UI.anyModalOpen then
                    UI.requestCloseModal = true
                    intercepted = true
                elseif imgui.GetIO().WantCaptureKeyboard then
                    intercepted = true
                end
                Sys.wasTypingEscape = intercepted
            elseif msg == 0x0101 then
                if not Sys.wasTypingEscape then
                    if UI.importModal[0] then
                        UI.importModal[0] = false
                    else
                        UI.windowState[0] = false
                    end
                end
                Sys.wasTypingEscape = false
            end
        end
    end
end)

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    imgui.GetStyle().WindowTitleAlign = imgui.ImVec2(0.0, 0.5)
end)

local sysIndicatorFrame = imgui.OnFrame(
    function()
        return Sys.tempText ~= nil and os.clock() < Sys.tempTimer
    end,
    function()
        local scale = settings.uiScale or 1.0
        imgui.GetIO().FontGlobalScale = scale
        local resX, resY = getScreenResolution()
        local posX, posY = resX / 2, resY - 20
        local pivotX, pivotY = 0.5, 1.0
        local notifPos = settings.notifPos or 2

        if notifPos == 1 then
            posX, posY = 20, resY - 20
            pivotX, pivotY = 0.0, 1.0
        elseif notifPos == 2 then
            posX, posY = resX / 2, resY - 20
            pivotX, pivotY = 0.5, 1.0
        elseif notifPos == 3 then
            posX, posY = resX - 20, resY - 20
            pivotX, pivotY = 1.0, 1.0
        elseif notifPos == 4 then
            posX, posY = resX / 2, resY * 0.08
            pivotX, pivotY = 0.5, 0.0
        end

        local borderColor = theme.them
        if Sys.tempType == 1 then
            borderColor = theme.sys_ok
        elseif Sys.tempType == 2 then
            borderColor = theme.sys_err
        elseif Sys.tempType == 3 then
            borderColor = theme.sys_info
        end

        imgui.SetNextWindowPos(imgui.ImVec2(posX, posY), imgui.Cond.Always, imgui.ImVec2(pivotX, pivotY))
        imgui.PushStyleColor(imgui.Col.WindowBg, theme.notif_bg)
        imgui.PushStyleColor(imgui.Col.Border, borderColor)
        imgui.PushStyleColor(imgui.Col.Text, theme.notif_text)
        imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 6.0 * scale)
        imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 1.0)
        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(15 * scale, 10 * scale))

        local flags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoFocusOnAppearing + imgui.WindowFlags.NoInputs
        if imgui.Begin("##CarToolSysIndicator", nil, flags) then
            imgui.TextUnformatted(Sys.tempText)
            imgui.End()
        end

        imgui.PopStyleVar(3)
        imgui.PopStyleColor(3)
    end
)
sysIndicatorFrame.HideCursor = true

local function openHandlingImportWindow(defaultModelId)
    if defaultModelId and defaultModelId >= 400 and defaultModelId <= 611 then
        UI.importModelId = defaultModelId
    end
    backupDefaultHandling(UI.importModelId)
    local curLine = ffi.string(UI.importLineBuf)
    if trim(curLine) == "" and savedHandlings[UI.importModelId] and savedHandlings[UI.importModelId].rawLine ~= "" then
        ffi.fill(UI.importLineBuf, ffi.sizeof(UI.importLineBuf), 0)
        ffi.copy(UI.importLineBuf, u8(savedHandlings[UI.importModelId].rawLine))
    end
    parseHandlingString(u8:decode(ffi.string(UI.importLineBuf)))
    applySafeModeSelection(UI.importSafeMode[0])
    UI.importModal[0] = true
end

imgui.OnFrame(
    function() return UI.importModal[0] end,
    function()
        local scale = settings.uiScale or 1.0
        imgui.GetIO().FontGlobalScale = scale
        local resX, resY = getScreenResolution()
        ApplyMessengerStyle(scale)

        imgui.SetNextWindowPos(imgui.ImVec2(resX * 0.5, resY * 0.5), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(820 * scale, 510 * scale), imgui.Cond.FirstUseEver)

        if imgui.Begin(u8"Âíåñåíèå èçìåíåíèé â Õåíäëèíã | CarTool", UI.importModal, imgui.WindowFlags.NoCollapse) then
            local spaceX = imgui.GetStyle().ItemSpacing.x
            local framePadX = imgui.GetStyle().FramePadding.x

            local inCar = isCharInAnyCar(PLAYER_PED)
            local curCar = inCar and storeCarCharIsInNoSave(PLAYER_PED) or nil
            local curCarModel = (curCar and doesVehicleExist(curCar)) and getCarModel(curCar) or nil

            imgui.AlignTextToFramePadding()
            imgui.TextColored(theme.muted, u8"Àâòîìîáèëü:")
            imgui.SameLine(0, 8 * scale)

            local selName = string.format("%s [ID: %d]", vehicleNames[UI.importModelId] or "Unknown", UI.importModelId)
            imgui.PushItemWidth(260 * scale)
            if imgui.BeginCombo("##importCarCombo", u8(selName)) then
                imgui.PushItemWidth(-1)
                imgui.InputTextWithHint("##impCarSearch", u8"Ïîèñê ïî íàçâàíèþ èëè ID...", UI.importCarSearch, ffi.sizeof(UI.importCarSearch))
                imgui.PopItemWidth()
                imgui.Separator()
                local flt = cp1251_lower(trim(u8:decode(ffi.string(UI.importCarSearch))))
                for id = 400, 611 do
                    local vName = vehicleNames[id] or "Unknown"
                    local pass = (flt == "") or vName:lower():find(flt, 1, true) or tostring(id):find(flt, 1, true)
                    if pass then
                        local itemLabel = string.format("%s (ID: %d)%s", vName, id, modloaderModels[id] and " [Modloader]" or "")
                        if imgui.Selectable(u8(itemLabel), UI.importModelId == id) then
                            UI.importModelId = id
                            backupDefaultHandling(id)
                        end
                    end
                end
                imgui.EndCombo()
            end
            imgui.PopItemWidth()

            if curCarModel then
                imgui.SameLine(0, spaceX)
                if styleButton(u8(string.format("Òåêóùåå àâòî (%s)", vehicleNames[curCarModel] or curCarModel)), theme.them) then
                    UI.importModelId = curCarModel
                    backupDefaultHandling(curCarModel)
                end
            end

            if parsedImportState.detectedModel and parsedImportState.detectedModel ~= UI.importModelId then
                imgui.SameLine(0, spaceX)
                local detId = parsedImportState.detectedModel
                if styleButton(u8(string.format("Èç ñòðîêè: %s (%d)", vehicleNames[detId] or detId, detId)), theme.warn) then
                    UI.importModelId = detId
                    backupDefaultHandling(detId)
                end
            end

            imgui.Spacing()

            local pasteBtnText = u8"Âñòàâèòü èç áóôåðà"
            local clrBtnText = u8"Î÷èñòèòü"
            local pasteW = imgui.CalcTextSize(pasteBtnText).x + framePadX * 2 + 10 * scale
            local clrW = imgui.CalcTextSize(clrBtnText).x + framePadX * 2 + 10 * scale
            local lineInputW = imgui.GetContentRegionAvail().x - pasteW - clrW - spaceX * 2

            imgui.PushItemWidth(lineInputW)
            if imgui.InputTextWithHint("##handlingRawLine", u8"Âñòàâüòå ñþäà ñòðîêó èç handling.cfg (ïðîáåëû è òàáóëÿöèè ïàðñÿòñÿ àâòîìàòè÷åñêè)...", UI.importLineBuf, ffi.sizeof(UI.importLineBuf)) then
                parseHandlingString(u8:decode(ffi.string(UI.importLineBuf)))
            end
            imgui.PopItemWidth()

            imgui.SameLine(0, spaceX)
            if imgui.Button(pasteBtnText, imgui.ImVec2(pasteW, 0)) then
                local clip = getClipboardText()
                if clip and clip ~= "" then
                    clip = clip:gsub("[\r\n]+", " ")
                    ffi.fill(UI.importLineBuf, ffi.sizeof(UI.importLineBuf), 0)
                    ffi.copy(UI.importLineBuf, u8(clip))
                    parseHandlingString(clip)
                    if parsedImportState.detectedModel then
                        UI.importModelId = parsedImportState.detectedModel
                        backupDefaultHandling(UI.importModelId)
                    end
                end
            end

            imgui.SameLine(0, spaceX)
            if styleButton(clrBtnText, theme.them, imgui.ImVec2(clrW, 0)) then
                ffi.fill(UI.importLineBuf, ffi.sizeof(UI.importLineBuf), 0)
                parseHandlingString("")
            end

            imgui.TextColored(parsedImportState.valid and theme.online or theme.warn, u8(parsedImportState.message))

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            if ToggleButton("##safe_mode_sw", UI.importSafeMode, scale) then
                applySafeModeSelection(UI.importSafeMode[0])
            end
            imgui.SameLine(0, 8 * scale)
            imgui.AlignTextToFramePadding()
            imgui.TextColored(UI.importSafeMode[0] and theme.online or theme.warn,
                UI.importSafeMode[0]
                    and u8"Áåçîïàñíûé ðåæèì: ÂÊË (ìåíÿþòñÿ òîëüêî ïîäâåñêà, êîë¸ñà è ïîñàäêà áåç ðàçãîíà è ñîïðîòèâëåíèÿ âåòðà)"
                    or u8"Áåçîïàñíûé ðåæèì: ÂÛÊË (çàìåíÿåòñÿ âñÿ ñòðîêà êðîìå ìàêñèìàëüíîé ñêîðîñòè è ôëàãîâ)"
            )

            local btnAllText = u8"Âûáðàòü âñå"
            local btnNoneText = u8"Ñíÿòü âñå"
            local wAll = imgui.CalcTextSize(btnAllText).x + framePadX * 2 + 8 * scale
            local wNone = imgui.CalcTextSize(btnNoneText).x + framePadX * 2 + 8 * scale
            imgui.SameLine()
            local availR = imgui.GetContentRegionAvail().x
            if availR > (wAll + wNone + spaceX) then
                imgui.SetCursorPosX(imgui.GetCursorPosX() + availR - (wAll + wNone + spaceX))
            end
            if styleButton(btnAllText, theme.them, imgui.ImVec2(wAll, 0)) then
                UI.importSafeMode[0] = false
                applySafeModeSelection(false)
            end
            imgui.SameLine(0, spaceX)
            if styleButton(btnNoneText, theme.them, imgui.ImVec2(wNone, 0)) then
                for _, f in ipairs(handlingFields) do
                    importFieldChecks[f.key][0] = false
                end
            end

            imgui.Spacing()

            local footerH = 38 * scale
            imgui.BeginChild("##importFieldsChild", imgui.ImVec2(0, -footerH), true)

            backupDefaultHandling(UI.importModelId)
            local baseAddr = getHandlingBaseAddr(UI.importModelId)

            local catTitles = {
                [1] = u8"1. Ïîäâåñêà è ïîñàäêà êóçîâà (Áåçîïàñíûé ðåæèì)",
                [2] = u8"2. Êîë¸ñà, ñöåïëåíèå è öåíòð òÿæåñòè (Áåçîïàñíûé ðåæèì)",
                [3] = u8"3. Ðàçãîí, ñîïðîòèâëåíèå âåòðà (Drag), ìàññà è òîðìîçà (Ïîëíûé ðåæèì)"
            }

            for catId = 1, 3 do
                imgui.TextColored(catId <= 2 and theme.online or theme.warn, catTitles[catId])
                imgui.Separator()
                imgui.Columns(2, "ImpCols_" .. catId, false)
                for _, f in ipairs(handlingFields) do
                    if f.cat == catId then
                        local curVal = baseAddr and readHandlingField(baseAddr, f) or nil
                        local newVal = parsedImportState.values[f.key]
                        local curStr = formatHandlingValue(f, curVal)
                        local newStr = newVal ~= nil and formatHandlingValue(f, newVal) or "íåò â ñòðîêå"

                        imgui.Checkbox(u8(f.label) .. "##chk_" .. f.key, importFieldChecks[f.key])
                        imgui.SameLine()
                        if newVal ~= nil then
                            imgui.TextColored(importFieldChecks[f.key][0] and theme.sys_info or theme.muted,
                                u8(string.format("[%s -> %s]", curStr, newStr)))
                        else
                            imgui.TextColored(theme.muted, u8(string.format("[Òåêóùåå: %s]", curStr)))
                        end
                        imgui.NextColumn()
                    end
                end
                imgui.Columns(1)
                imgui.Spacing()
            end

            imgui.EndChild()

            local gap = 8 * scale
            local availW = imgui.GetContentRegionAvail().x
            local btnW = (availW - gap * 2) / 3

            if parsedImportState.valid then
                if imgui.Button(u8"Ïðèìåíèòü âûáðàííûå ïóíêòû", imgui.ImVec2(btnW, 30 * scale)) then
                    local chosenValues = {}
                    local appliedCount = 0
                    for _, f in ipairs(handlingFields) do
                        if importFieldChecks[f.key][0] and parsedImportState.values[f.key] ~= nil then
                            chosenValues[f.key] = parsedImportState.values[f.key]
                            appliedCount = appliedCount + 1
                        end
                    end

                    if appliedCount > 0 then
                        savedHandlings[UI.importModelId] = {
                            enabled = true,
                            safeMode = UI.importSafeMode[0],
                            rawLine = trim(u8:decode(ffi.string(UI.importLineBuf))),
                            values = chosenValues
                        }
                        applySavedHandlingEntry(UI.importModelId, savedHandlings[UI.importModelId])
                        saveConfig()
                        showSystemNotification(
                            u8(string.format("Õåíäëèíã ïðèìåí¸í ê %s (%d ïóíêòîâ)", vehicleNames[UI.importModelId] or UI.importModelId, appliedCount)),
                            1, 3.5
                        )
                        UI.importModal[0] = false
                    else
                        showSystemNotification(u8"Íå âûáðàíî íè îäíîãî ïóíêòà äëÿ èçìåíåíèÿ!", 2, 3.0)
                    end
                end
            else
                disabledButton(u8"Ïðèìåíèòü âûáðàííûå ïóíêòû", imgui.ImVec2(btnW, 30 * scale))
            end

            imgui.SameLine(0, gap)
            if styleButton(u8"Ñáðîñèòü àâòî ê ñòàíäàðòó", theme.danger, imgui.ImVec2(btnW, 30 * scale)) then
                resetModelHandlingToDefault(UI.importModelId)
                savedHandlings[UI.importModelId] = nil
                saveConfig()
                showSystemNotification(u8(string.format("Õåíäëèíã %s ñáðîøåí ê çàâîäñêîìó", vehicleNames[UI.importModelId] or UI.importModelId)), 3, 3.0)
            end

            imgui.SameLine(0, gap)
            if styleButton(u8"Çàêðûòü (Esc)", theme.them, imgui.ImVec2(btnW, 30 * scale)) then
                UI.importModal[0] = false
            end

            imgui.End()
        end

        PopMessengerStyle()
    end
)

local function DrawSettingsModal(scale)
    UI.anyModalOpen = false
    if imgui.BeginPopupModal("SettingsModal", nil, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoTitleBar) then
        UI.anyModalOpen = true
        if UI.requestCloseModal then
            imgui.CloseCurrentPopup()
            UI.requestCloseModal = false
        end

        imgui.TextUnformatted(u8"Íàñòðîéêè CarTool")
        imgui.SameLine()
        local ver_str = tostring(script_version)
        if not ver_str:find("%.") then ver_str = ver_str .. ".0" end
        imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), "v" .. ver_str)
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        local comboWidth = 240 * scale
        local btnOffset = comboWidth + imgui.GetStyle().ItemSpacing.x + 14 * scale

        imgui.TextUnformatted(u8"Ìàñøòàá èíòåðôåéñà:")
        imgui.PushItemWidth(comboWidth)
        if imgui.SliderFloat("##UIScale", UI.uiScaleArr, 0.5, 2.0, "%.2f") then
            settings.uiScale = UI.uiScaleArr[0]
            UI.forceResize = true
            saveConfig()
        end
        imgui.PopItemWidth()
        imgui.SameLine(btnOffset)
        if imgui.Button(u8"Ïî óìîë÷àíèþ", imgui.ImVec2(140 * scale, 0)) then
            settings.uiScale = 1.0
            UI.uiScaleArr[0] = 1.0
            UI.forceResize = true
            saveConfig()
        end

        imgui.Spacing()
        imgui.TextUnformatted(u8"Ïîëîæåíèå óâåäîìëåíèé:")
        imgui.PushItemWidth(comboWidth)
        if imgui.BeginCombo("##NotifPosCombo", notifPositions[settings.notifPos]) then
            for i, posName in ipairs(notifPositions) do
                if imgui.Selectable(posName, settings.notifPos == i) then
                    settings.notifPos = i
                    saveConfig()
                end
            end
            imgui.EndCombo()
        end
        imgui.PopItemWidth()
        imgui.SameLine(btnOffset)
        if imgui.Button(u8"Ïðîâåðêà", imgui.ImVec2(140 * scale, 0)) then
            showSystemNotification(u8"Òåñòîâîå óâåäîìëåíèå CarTool!", 1)
        end

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        if imgui.Checkbox(u8"Âñïëûâàþùèå ñèñòåìíûå óâåäîìëåíèÿ", UI.notifyEventsBool) then
            settings.notifyEvents = UI.notifyEventsBool[0]
            saveConfig()
        end

        if imgui.Checkbox(u8"Îñòàâëÿòü íåñîõðàí¸ííûé öâåò íà àâòî ïîñëå çàêðûòèÿ ìåíþ", UI.keepUnsavedBool) then
            settings.keepUnsavedColor = UI.keepUnsavedBool[0]
            if not settings.keepUnsavedColor then
                unsavedCarColors = {}
            end
            saveConfig()
        end

        if imgui.Checkbox(u8"Àâòîìàòè÷åñêè ïðèìåíÿòü ñîõðàí¸ííûé õåíäëèíã ïðè âõîäå", UI.autoApplyHandlingBool) then
            settings.autoApplyHandling = UI.autoApplyHandlingBool[0]
            saveConfig()
        end

        if imgui.Checkbox(u8"Àâòîîáíîâëåíèå ñêðèïòà", UI.autoUpdateBool) then
            settings.autoUpdate = UI.autoUpdateBool[0]
            saveConfig()
        end
        imgui.SameLine()
        if imgui.Button(u8"Ïðîâåðèòü îáíîâëåíèå") then
            checkUpdates(true)
        end

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        local btnCloseW = 110 * scale
        local availRight = imgui.GetContentRegionAvail().x
        if availRight > btnCloseW then
            imgui.SetCursorPosX(imgui.GetCursorPosX() + availRight - btnCloseW)
        end
        if imgui.Button(u8"Çàêðûòü", imgui.ImVec2(btnCloseW, 0)) then
            imgui.CloseCurrentPopup()
        end

        imgui.EndPopup()
    end
end

local function applyImportedColorString(rawStr, curCar)
    local s = trim(rawStr or "")
    if s == "" then
        showSystemNotification(u8"Ñòðîêà èìïîðòà ïóñòà!", 2)
        return false
    end
    local nums = {}
    for numStr in s:gmatch("%d+") do
        nums[#nums + 1] = math.max(0, math.min(255, tonumber(numStr) or 0))
        if #nums == 4 then break end
    end
    if #nums == 0 then
        showSystemNotification(u8"Íå íàéäåíî çíà÷åíèé öâåòà (ïðèìåð: 101,0,99,0)", 2)
        return false
    end
    UI.c1[0] = nums[1] or 0
    UI.c2[0] = nums[2] or 0
    UI.c3[0] = nums[3] or 0
    UI.c4[0] = nums[4] or 0

    if curCar and doesVehicleExist(curCar) then
        local cols = {UI.c1[0], UI.c2[0], UI.c3[0], UI.c4[0]}
        if settings.keepUnsavedColor then
            unsavedCarColors[curCar] = cols
        end
        applyColors(curCar, cols)
    end
    showSystemNotification(u8(string.format("Èìïîðòèðîâàíû öâåòà: %d, %d, %d, %d", UI.c1[0], UI.c2[0], UI.c3[0], UI.c4[0])), 1)
    return true
end

local function saveCurrentPreset(targetStr)
    local pStr = trim(targetStr)
    local cleanStr = cleanPlateText(pStr)
    if cleanStr == "" then
        showSystemNotification(u8"Ââåäèòå ãîñ. íîìåð èëè ñÿäüòå â àâòî ñ íîìåðîì!", 2)
        return false
    end

    local found = false
    for _, p in ipairs(presets) do
        if cleanPlateText(p.plate_str) == cleanStr then
            p.c1, p.c2, p.c3, p.c4 = UI.c1[0], UI.c2[0], UI.c3[0], UI.c4[0]
            p.plate_str = pStr
            if not p.plate_buf then
                p.plate_buf = imgui.new.char[64]()
            end
            ffi.fill(p.plate_buf, ffi.sizeof(p.plate_buf), 0)
            ffi.copy(p.plate_buf, u8(pStr))
            found = true
            break
        end
    end

    if not found then
        local buf = imgui.new.char[64]()
        ffi.fill(buf, ffi.sizeof(buf), 0)
        ffi.copy(buf, u8(pStr))
        table.insert(presets, 1, {
            plate_buf = buf,
            plate_str = pStr,
            c1 = UI.c1[0], c2 = UI.c2[0], c3 = UI.c3[0], c4 = UI.c4[0]
        })
    end

    sessionColors[cleanStr] = {UI.c1[0], UI.c2[0], UI.c3[0], UI.c4[0]}
    saveConfig()
    showSystemNotification(u8(string.format("Ïðåñåò ïîêðàñêè ñîõðàí¸í íà íîìåð: %s", cleanStr)), 1)
    return true
end

local function drawColorSlotCompact(slotIdx, label, intPtr, scale)
    local isSelected = (UI.activeColorSlot == slotIdx)
    local availW = imgui.GetContentRegionAvail().x

    imgui.TextColored(isSelected and theme.white or theme.subtext, label)
    if imgui.IsItemClicked(0) then
        UI.activeColorSlot = slotIdx
    end

    local bgVec4 = getPaletteVec4(intPtr[0])
    local txtVec4 = getContrastVec4(bgVec4)
    local grabVec4 = getContrastGrabVec4(bgVec4, false)
    local grabActVec4 = getContrastGrabVec4(bgVec4, true)

    local pMin = imgui.GetCursorScreenPos()

    imgui.PushItemWidth(availW)
    imgui.PushStyleColor(imgui.Col.FrameBg, bgVec4)
    imgui.PushStyleColor(imgui.Col.FrameBgHovered, bgVec4)
    imgui.PushStyleColor(imgui.Col.FrameBgActive, bgVec4)
    imgui.PushStyleColor(imgui.Col.Text, txtVec4)
    imgui.PushStyleColor(imgui.Col.SliderGrab, grabVec4)
    imgui.PushStyleColor(imgui.Col.SliderGrabActive, grabActVec4)

    if imgui.SliderInt("##slider" .. slotIdx, intPtr, 0, 255, "%d") then
        UI.activeColorSlot = slotIdx
    end

    imgui.PopStyleColor(6)
    imgui.PopItemWidth()

    local pMax = imgui.ImVec2(pMin.x + availW, pMin.y + imgui.GetItemRectSize().y)
    local dl = imgui.GetWindowDrawList()
    local borderCol = isSelected and theme.white or imgui.ImVec4(0.50, 0.50, 0.55, 0.55)
    local borderThick = isSelected and (1.8 * scale) or 1.0
    dl:AddRect(pMin, pMax, imgui.GetColorU32Vec4(borderCol), 6.0 * scale, 15, borderThick)

    if imgui.IsItemClicked(0) then
        UI.activeColorSlot = slotIdx
    end
    if imgui.IsItemHovered() then
        local wheel = imgui.GetIO().MouseWheel
        if wheel ~= 0 then
            UI.activeColorSlot = slotIdx
            intPtr[0] = math.max(0, math.min(255, intPtr[0] + (wheel > 0 and 1 or -1)))
        end
        if imgui.IsMouseClicked(1) then
            UI.activeColorSlot = slotIdx
            UI.popupColorBuf[0] = intPtr[0]
            imgui.OpenPopup("ExactColorPopup_" .. slotIdx)
        end
        imgui.SetTooltip(u8"ËÊÌ / Ïîëçóíîê  âûáðàòü öâåò\nÊîë¸ñèêî  èçìåíèòü íà ±1\nÏÊÌ  ââåñòè ID âðó÷íóþ")
    end

    if imgui.BeginPopup("ExactColorPopup_" .. slotIdx) then
        imgui.TextUnformatted(label)
        imgui.PushItemWidth(100 * scale)
        if imgui.InputInt("##exact_in_" .. slotIdx, UI.popupColorBuf, 1, 10) then
            intPtr[0] = math.max(0, math.min(255, UI.popupColorBuf[0]))
        end
        imgui.PopItemWidth()
        imgui.EndPopup()
    end
end

local function countSavedHandlings()
    local c = 0
    for _ in pairs(savedHandlings) do c = c + 1 end
    return c
end

local function countBannedTuneModels()
    if settings.disableAllTune then return 212 end
    local c = 0
    for id = 400, 611 do
        if modelBools[id][0] or (settings.autoModloader and modloaderModels[id]) then
            c = c + 1
        end
    end
    return c
end

local wasWindowOpen = false
imgui.OnFrame(function() return UI.windowState[0] end, function()
    local scale = settings.uiScale or 1.0
    imgui.GetIO().FontGlobalScale = scale
    local resX, resY = getScreenResolution()

    ApplyMessengerStyle(scale)

    local sizeCond = UI.forceResize and imgui.Cond.Always or imgui.Cond.FirstUseEver
    imgui.SetNextWindowPos(imgui.ImVec2(resX * 0.5, resY * 0.5), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(860 * scale, 520 * scale), sizeCond)
    if UI.forceResize then UI.forceResize = false end

    if UI.windowState[0] and not wasWindowOpen then
        imgui.SetNextWindowFocus()
    end
    wasWindowOpen = UI.windowState[0]

    if imgui.Begin("CarTool", UI.windowState, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse) then
        clampColors()
        DrawSettingsModal(scale)

        local framePadX = imgui.GetStyle().FramePadding.x
        local spaceX = imgui.GetStyle().ItemSpacing.x

        local inCar = isCharInAnyCar(PLAYER_PED)
        local curCar = inCar and storeCarCharIsInNoSave(PLAYER_PED) or nil
        local curId, curModel, curPlate = nil, nil, nil
        if curCar and doesVehicleExist(curCar) then
            local ok, vid = sampGetVehicleIdByCarHandle(curCar)
            if ok then curId = vid end
            curModel = getCarModel(curCar)
            if curId and vehiclePlates[curId] then
                curPlate = cleanPlateText(vehiclePlates[curId])
            end
        end

        if styleButton(u8(string.format("Ïîêðàñêà (%d)", #presets)), UI.currentTab == 1 and theme.me or theme.them, imgui.ImVec2(140 * scale, 0)) then
            UI.currentTab = 1
        end

        imgui.SameLine()
        if styleButton(u8(string.format("Àíòè-Òþíèíã (%d)", countBannedTuneModels())), UI.currentTab == 2 and theme.me or theme.them, imgui.ImVec2(155 * scale, 0)) then
            UI.currentTab = 2
        end

        imgui.SameLine()
        if styleButton(u8(string.format("Õåíäëèíã (%d)", countSavedHandlings())), UI.currentTab == 3 and theme.me or theme.them, imgui.ImVec2(145 * scale, 0)) then
            UI.currentTab = 3
            if curModel then
                UI.manualModelId = curModel
                loadModelHandlingToManualUI(curModel)
            end
        end

        imgui.SameLine(0, 10 * scale)
        imgui.AlignTextToFramePadding()
        if curModel then
            local mName = vehicleNames[curModel] or "Unknown"
            local plateHdr = (curPlate and curPlate ~= "") and curPlate or "Áåç íîìåðà"
            imgui.TextColored(theme.online, u8(string.format(" %s [%d] | %s", mName, curModel, plateHdr)))
        else
            imgui.TextColored(theme.muted, u8" Âíå òðàíñïîðòà")
        end

        local settingsBtnText = u8"Íàñòðîéêè"
        local settingsBtnW = imgui.CalcTextSize(settingsBtnText).x + (framePadX * 2.0) + (12 * scale)
        imgui.SameLine()
        local availRight = imgui.GetContentRegionAvail().x
        if availRight > settingsBtnW then
            imgui.SetCursorPosX(imgui.GetCursorPosX() + availRight - settingsBtnW)
        end
        if imgui.Button(settingsBtnText, imgui.ImVec2(settingsBtnW, 0)) then
            syncSettingsToUI()
            imgui.OpenPopup("SettingsModal")
        end

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        if curCar and doesVehicleExist(curCar) and curModel then
            local dl = imgui.GetWindowDrawList()
            local availW = imgui.GetContentRegionAvail().x
            local barH = 34 * scale
            local btnH = 24 * scale
            local textH = imgui.GetTextLineHeight()
            local pMin = imgui.GetCursorScreenPos()
            local pMax = imgui.ImVec2(pMin.x + availW, pMin.y + barH)
            dl:AddRectFilled(pMin, pMax, imgui.GetColorU32Vec4(imgui.ImVec4(theme.me.x, theme.me.y, theme.me.z, 0.35)), 6.0 * scale)

            local cPos = imgui.GetCursorPos()
            local plateInfo = (curPlate and curPlate ~= "") and curPlate or "Íåò íîìåðà"
            local bannerStr = u8(string.format("Òåêóùåå àâòî: %s (ID: %d)   |   Íîìåð: %s",
                vehicleNames[curModel] or "Unknown", curModel, plateInfo))

            dl:AddText(
                imgui.ImVec2(pMin.x + 12 * scale, pMin.y + (barH - textH) * 0.5),
                imgui.GetColorU32Vec4(theme.white),
                bannerStr
            )

            local btnOffsetY = (barH - btnH) * 0.5
            if UI.currentTab == 1 then
                local bReset = u8"Ñáðîñèòü ê ðîäíîìó öâåòó"
                local wReset = imgui.CalcTextSize(bReset).x + framePadX * 2 + 10 * scale
                imgui.SetCursorPos(imgui.ImVec2(cPos.x + availW - wReset - 8 * scale, cPos.y + btnOffsetY))
                if styleButton(bReset, theme.them, imgui.ImVec2(wReset, btnH)) and curId and originalColors[curId] then
                    local oc = originalColors[curId]
                    UI.c1[0], UI.c2[0], UI.c3[0], UI.c4[0] = oc[1], oc[2], oc[3], oc[4]
                    unsavedCarColors[curCar] = nil
                    applyColors(curCar, oc)
                end
            elseif UI.currentTab == 2 then
                local isBanned = modelBools[curModel] and modelBools[curModel][0]
                local b1 = isBanned and u8"Ðàçðåøèòü òþíèíã àâòî" or u8"Óáðàòü òþíèíã àâòî"
                local w1 = imgui.CalcTextSize(b1).x + framePadX * 2 + 10 * scale
                imgui.SetCursorPos(imgui.ImVec2(cPos.x + availW - w1 - 8 * scale, cPos.y + btnOffsetY))
                if styleButton(b1, isBanned and theme.warn or theme.me, imgui.ImVec2(w1, btnH)) then
                    modelBools[curModel][0] = not isBanned
                    saveConfig()
                    purgeAllStreamedVehicles()
                end
            elseif UI.currentTab == 3 then
                local b1 = u8"Âíåñòè èçìåíåíèÿ"
                local b2 = u8"Ñáðîñèòü"
                local w1 = imgui.CalcTextSize(b1).x + framePadX * 2 + 10 * scale
                local w2 = imgui.CalcTextSize(b2).x + framePadX * 2 + 10 * scale
                local totW = w1 + w2 + spaceX
                imgui.SetCursorPos(imgui.ImVec2(cPos.x + availW - totW - 8 * scale, cPos.y + btnOffsetY))
                if imgui.Button(b1, imgui.ImVec2(w1, btnH)) then
                    openHandlingImportWindow(curModel)
                end
                imgui.SameLine(0, spaceX)
                if styleButton(b2, theme.danger, imgui.ImVec2(w2, btnH)) then
                    resetModelHandlingToDefault(curModel)
                    savedHandlings[curModel] = nil
                    loadModelHandlingToManualUI(curModel)
                    saveConfig()
                    showSystemNotification(u8"Õåíäëèíã òåêóùåãî àâòî ñáðîøåí ê ñòàíäàðòó", 3)
                end
            end

            imgui.SetCursorPos(imgui.ImVec2(cPos.x, cPos.y + barH + 6 * scale))
        end

        if UI.currentTab == 1 then
            if ToggleButton("##sw_live_prev", UI.livePreviewBool, scale) then
                settings.livePreview = UI.livePreviewBool[0]
                saveConfig()
                if not settings.livePreview and curCar then
                    unsavedCarColors[curCar] = nil
                    restoreVehicleColor(curId, curCar)
                end
            end
            imgui.SameLine(0, 6 * scale)
            imgui.AlignTextToFramePadding()
            imgui.TextUnformatted(u8"Ïðåäïðîñìîòð")

            imgui.SameLine(0, 14 * scale)
            if ToggleButton("##sw_palette", UI.showPaletteBool, scale) then
                settings.showPalette = UI.showPaletteBool[0]
                saveConfig()
            end
            imgui.SameLine(0, 6 * scale)
            imgui.AlignTextToFramePadding()
            imgui.TextUnformatted(u8"Ïàëèòðà GTA")

            local saveBtnText = u8"Ñîõðàíèòü"
            local impBtnText = u8"Èìïîðò"
            local saveBtnW = imgui.CalcTextSize(saveBtnText).x + framePadX * 2 + 14 * scale
            local impBtnW = imgui.CalcTextSize(impBtnText).x + framePadX * 2 + 14 * scale
            local inputW = 175 * scale
            local rightClusterW = inputW + saveBtnW + impBtnW + spaceX * 2

            imgui.SameLine()
            local availToolbar = imgui.GetContentRegionAvail().x
            if availToolbar > rightClusterW then
                imgui.SetCursorPosX(imgui.GetCursorPosX() + availToolbar - rightClusterW)
            end

            imgui.PushItemWidth(inputW)
            imgui.InputTextWithHint("##input_plate", u8"Íîìåð", UI.inputPlate, 64)
            imgui.PopItemWidth()

            imgui.SameLine(0, spaceX)
            if imgui.Button(saveBtnText, imgui.ImVec2(saveBtnW, 0)) then
                local typed = trim(u8:decode(ffi.string(UI.inputPlate)))
                if typed ~= "" then
                    if saveCurrentPreset(typed) then
                        ffi.fill(UI.inputPlate, ffi.sizeof(UI.inputPlate), 0)
                        if curCar and doesVehicleExist(curCar) then
                            unsavedCarColors[curCar] = nil
                            applyColors(curCar, {UI.c1[0], UI.c2[0], UI.c3[0], UI.c4[0]})
                        end
                    end
                else
                    if curCar and curPlate and curPlate ~= "" then
                        if saveCurrentPreset(curPlate) then
                            ffi.fill(UI.inputPlate, ffi.sizeof(UI.inputPlate), 0)
                            unsavedCarColors[curCar] = nil
                            applyColors(curCar, {UI.c1[0], UI.c2[0], UI.c3[0], UI.c4[0]})
                        end
                    else
                        showSystemNotification(u8"Ó òåêóùåãî àâòî íåò íîìåðà! Ââåäèòå íîìåð âðó÷íóþ.", 2)
                    end
                end
            end

            imgui.SameLine(0, spaceX)
            if styleButton(impBtnText, theme.them, imgui.ImVec2(impBtnW, 0)) then
                imgui.OpenPopup("ImportColorPopup")
            end
            if imgui.IsItemHovered() then
                if imgui.IsMouseClicked(1) then
                    local clip = getClipboardText()
                    if clip and clip ~= "" then
                        applyImportedColorString(clip, curCar)
                    end
                end
                imgui.SetTooltip(u8"ËÊÌ  îòêðûòü îêíî èìïîðòà (101,0,99,0)\nÏÊÌ  ìãíîâåííî âñòàâèòü èç áóôåðà îáìåíà")
            end

            if imgui.BeginPopup("ImportColorPopup") then
                imgui.TextUnformatted(u8"Èìïîðò öâåòà (ôîðìàò: 101,0,99,0):")
                imgui.PushItemWidth(210 * scale)
                local enterPressed = imgui.InputTextWithHint("##imp_clr_str", "101,0,99,0", UI.importColorBuf, 64, imgui.InputTextFlags.EnterReturnsTrue)
                imgui.PopItemWidth()
                if enterPressed then
                    if applyImportedColorString(u8:decode(ffi.string(UI.importColorBuf)), curCar) then
                        ffi.fill(UI.importColorBuf, ffi.sizeof(UI.importColorBuf), 0)
                        imgui.CloseCurrentPopup()
                    end
                end
                imgui.Spacing()
                if imgui.Button(u8"Ïðèìåíèòü", imgui.ImVec2(100 * scale, 0)) then
                    if applyImportedColorString(u8:decode(ffi.string(UI.importColorBuf)), curCar) then
                        ffi.fill(UI.importColorBuf, ffi.sizeof(UI.importColorBuf), 0)
                        imgui.CloseCurrentPopup()
                    end
                end
                imgui.SameLine(0, spaceX)
                if styleButton(u8"Èç áóôåðà", theme.them, imgui.ImVec2(102 * scale, 0)) then
                    local clip = getClipboardText()
                    if clip and clip ~= "" then
                        if applyImportedColorString(clip, curCar) then
                            ffi.fill(UI.importColorBuf, ffi.sizeof(UI.importColorBuf), 0)
                            imgui.CloseCurrentPopup()
                        end
                    end
                end
                imgui.EndPopup()
            end

            imgui.Spacing()

            local topBoxH = settings.showPalette and (218 * scale) or (122 * scale)
            imgui.BeginChild("##paintTopBox", imgui.ImVec2(0, topBoxH), true, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)

            imgui.Columns(2, "ColorSlotsGrid", false)
            drawColorSlotCompact(1, u8"Îñíîâíîé 1:", UI.c1, scale)
            imgui.Spacing()
            drawColorSlotCompact(2, u8"Îñíîâíîé 2:", UI.c2, scale)
            imgui.NextColumn()
            drawColorSlotCompact(3, u8"Äîïîëíèòåëüíûé 1:", UI.c3, scale)
            imgui.Spacing()
            drawColorSlotCompact(4, u8"Äîïîëíèòåëüíûé 2:", UI.c4, scale)
            imgui.Columns(1)

            if settings.showPalette then
                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                local dl = imgui.GetWindowDrawList()
                local startScreen = imgui.GetCursorScreenPos()
                local startLocal = imgui.GetCursorPos()
                local availW = imgui.GetContentRegionAvail().x
                local cols = 32
                local rows = 4
                local gap = 2 * scale
                local totalGapX = (cols - 1) * gap
                local pureW = availW - totalGapX
                local cellH = 19 * scale

                local activeVal = UI.c1[0]
                if UI.activeColorSlot == 2 then activeVal = UI.c2[0]
                elseif UI.activeColorSlot == 3 then activeVal = UI.c3[0]
                elseif UI.activeColorSlot == 4 then activeVal = UI.c4[0] end

                for r = 0, rows - 1 do
                    local y0 = startScreen.y + r * (cellH + gap)
                    local y1 = y0 + cellH
                    for c = 0, cols - 1 do
                        local idx = r * cols + c
                        local x0 = startScreen.x + math.floor(c * pureW / cols) + c * gap
                        local x1 = startScreen.x + math.floor((c + 1) * pureW / cols) + c * gap
                        local w = x1 - x0

                        imgui.SetCursorScreenPos(imgui.ImVec2(x0, y0))
                        imgui.PushIDInt(3000 + idx)
                        if imgui.InvisibleButton("##palcell", imgui.ImVec2(w, cellH)) then
                            if UI.activeColorSlot == 1 then UI.c1[0] = idx
                            elseif UI.activeColorSlot == 2 then UI.c2[0] = idx
                            elseif UI.activeColorSlot == 3 then UI.c3[0] = idx
                            elseif UI.activeColorSlot == 4 then UI.c4[0] = idx end
                        end
                        local isHov = imgui.IsItemHovered()
                        if isHov then
                            imgui.SetMouseCursor(imgui.MouseCursor.Hand)
                            imgui.SetTooltip(u8("ID öâåòà: " .. idx))
                        end
                        imgui.PopID()

                        local pMin = imgui.ImVec2(x0, y0)
                        local pMax = imgui.ImVec2(x1, y1)
                        dl:AddRectFilled(pMin, pMax, imgui.GetColorU32Vec4(getPaletteVec4(idx)), 4.0 * scale, 15)
                        if idx == activeVal or isHov then
                            dl:AddRect(pMin, pMax, imgui.GetColorU32Vec4(theme.white), 4.0 * scale, 15, 1.5 * scale)
                        end
                    end
                end

                imgui.SetCursorPos(imgui.ImVec2(startLocal.x, startLocal.y + rows * cellH + (rows - 1) * gap))
            end

            imgui.EndChild()

            imgui.Spacing()
            imgui.PushItemWidth(imgui.GetContentRegionAvail().x)
            imgui.InputTextWithHint("##presetSearch", u8"Ïîèñê â ñîõðàí¸ííûõ ïðåñåòàõ", UI.presetSearch, ffi.sizeof(UI.presetSearch))
            imgui.PopItemWidth()

            imgui.Spacing()
            imgui.BeginChild("##presetsListChild", imgui.ImVec2(0, 0), true)
            local pFilter = cleanPlateText(u8:decode(ffi.string(UI.presetSearch)))
            local dl = imgui.GetWindowDrawList()
            local availW = imgui.GetContentRegionAvail().x
            local padX = 12 * scale
            local toDelete = nil
            local visibleCount = 0

            for i, p in ipairs(presets) do
                if pFilter == "" or cleanPlateText(p.plate_str):find(pFilter, 1, true) then
                    visibleCount = visibleCount + 1
                    local cardH = 38 * scale
                    local boxW = 42 * scale
                    local boxH = 24 * scale
                    local boxOffsetY = (cardH - boxH) * 0.5

                    local startPos = imgui.GetCursorPos()
                    local pMin = imgui.GetCursorScreenPos()
                    local pMax = imgui.ImVec2(pMin.x + availW, pMin.y + cardH)

                    dl:AddRectFilled(pMin, pMax, imgui.GetColorU32Vec4(imgui.ImVec4(theme.them.x, theme.them.y, theme.them.z, 0.42)), 6.0 * scale, 15)

                    imgui.PushIDInt(i)
                    if not p.plate_buf then
                        p.plate_buf = imgui.new.char[64]()
                        ffi.fill(p.plate_buf, ffi.sizeof(p.plate_buf), 0)
                        ffi.copy(p.plate_buf, u8(p.plate_str or ""))
                    end

                    imgui.SetCursorPos(imgui.ImVec2(startPos.x + padX, startPos.y + boxOffsetY))
                    imgui.PushItemWidth(155 * scale)
                    if imgui.InputText("##plateid", p.plate_buf, 64) then
                        local oldStr = cleanPlateText(p.plate_str)
                        p.plate_str = u8:decode(ffi.string(p.plate_buf))
                        local newStr = cleanPlateText(p.plate_str)
                        if oldStr ~= "" and oldStr ~= newStr then
                            sessionColors[oldStr] = nil
                        end
                        if newStr ~= "" then
                            sessionColors[newStr] = {p.c1, p.c2, p.c3, p.c4}
                        end
                        saveConfig()
                    end
                    imgui.PopItemWidth()

                    local swatchesX = startPos.x + 180 * scale
                    imgui.SetCursorPos(imgui.ImVec2(swatchesX, startPos.y + boxOffsetY))
                    DrawColorBoxWithId("##pc1", p.c1, boxW, boxH, scale, false)
                    imgui.SameLine(0, 6 * scale)
                    DrawColorBoxWithId("##pc2", p.c2, boxW, boxH, scale, false)
                    imgui.SameLine(0, 6 * scale)
                    DrawColorBoxWithId("##pc3", p.c3, boxW, boxH, scale, false)
                    imgui.SameLine(0, 6 * scale)
                    DrawColorBoxWithId("##pc4", p.c4, boxW, boxH, scale, false)

                    local applyLabel = u8"Ïðèìåíèòü ê íûíåøíåìó"
                    local updLabel = u8"Îáíîâèòü"
                    local applyW = imgui.CalcTextSize(applyLabel).x + framePadX * 2 + 10 * scale
                    local updW = imgui.CalcTextSize(updLabel).x + framePadX * 2 + 10 * scale
                    local delW = 28 * scale
                    local rightW = applyW + updW + delW + spaceX * 2

                    imgui.SetCursorPos(imgui.ImVec2(startPos.x + availW - rightW - padX, startPos.y + boxOffsetY))
                    if imgui.Button(applyLabel, imgui.ImVec2(applyW, boxH)) then
                        UI.c1[0], UI.c2[0], UI.c3[0], UI.c4[0] = p.c1, p.c2, p.c3, p.c4
                        if curCar and doesVehicleExist(curCar) then
                            unsavedCarColors[curCar] = {p.c1, p.c2, p.c3, p.c4}
                            applyColors(curCar, {p.c1, p.c2, p.c3, p.c4})
                            showSystemNotification(u8"Ïðåñåò ïðèìåí¸í ê íûíåøíåìó àâòîìîáèëþ", 1)
                        else
                            showSystemNotification(u8"Öâåòà ïðåñåòà âûáðàíû", 1)
                        end
                    end

                    imgui.SameLine(0, spaceX)
                    if styleButton(updLabel, theme.them, imgui.ImVec2(updW, boxH)) then
                        p.c1, p.c2, p.c3, p.c4 = UI.c1[0], UI.c2[0], UI.c3[0], UI.c4[0]
                        local cleanStr = cleanPlateText(p.plate_str)
                        if cleanStr ~= "" then
                            sessionColors[cleanStr] = {p.c1, p.c2, p.c3, p.c4}
                        end
                        if curCar and doesVehicleExist(curCar) and curPlate == cleanStr then
                            unsavedCarColors[curCar] = nil
                            applyColors(curCar, {p.c1, p.c2, p.c3, p.c4})
                        end
                        saveConfig()
                        showSystemNotification(u8"Ïðåñåò îáíîâë¸í", 1)
                    end

                    imgui.SameLine(0, spaceX)
                    if styleButton("X", theme.danger, imgui.ImVec2(delW, boxH)) then
                        toDelete = i
                    end

                    imgui.PopID()
                    imgui.SetCursorPos(imgui.ImVec2(startPos.x, startPos.y + cardH + 5 * scale))
                end
            end

            if toDelete then
                local cleanStr = cleanPlateText(presets[toDelete].plate_str)
                if cleanStr ~= "" then
                    sessionColors[cleanStr] = nil
                end
                table.remove(presets, toDelete)
                saveConfig()
                if curCar then
                    restoreVehicleColor(curId, curCar)
                end
                showSystemNotification(u8"Ïðåñåò óäàë¸í", 3)
            end

            if visibleCount == 0 then
                local emptyText = (#presets == 0)
                    and u8"Ñîõðàí¸ííûõ ïðåñåòîâ ïîêà íåò. Âûáåðèòå öâåòà ñâåðõó è íàæìèòå «Ñîõðàíèòü»."
                    or u8"Ïî âàøåìó çàïðîñó ïðåñåòîâ íå íàéäåíî."
                local tSize = imgui.CalcTextSize(emptyText)
                local avail = imgui.GetContentRegionAvail()
                local cPos = imgui.GetCursorPos()
                imgui.SetCursorPos(imgui.ImVec2(cPos.x + (avail.x - tSize.x) * 0.5, cPos.y + (avail.y - tSize.y) * 0.5))
                imgui.TextColored(theme.muted, emptyText)
            end

            imgui.EndChild()

        elseif UI.currentTab == 2 then
            if ToggleButton("##sw_dis_all", UI.disableAllBool, scale) then
                settings.disableAllTune = UI.disableAllBool[0]
                saveConfig()
                purgeAllStreamedVehicles()
            end
            imgui.SameLine(0, 6 * scale)
            imgui.AlignTextToFramePadding()
            imgui.TextUnformatted(u8"Îòêëþ÷èòü âåñü òþíèíã")

            imgui.SameLine(0, 14 * scale)
            if ToggleButton("##sw_dis_vinyls", UI.disableVinylsBool, scale) then
                settings.disableVinyls = UI.disableVinylsBool[0]
                saveConfig()
                purgeAllStreamedVehicles()
            end
            imgui.SameLine(0, 6 * scale)
            imgui.AlignTextToFramePadding()
            imgui.TextUnformatted(u8"Óäàëÿòü âèíèëû")

            imgui.SameLine(0, 14 * scale)
            if ToggleButton("##sw_auto_ml", UI.autoModloaderBool, scale) then
                settings.autoModloader = UI.autoModloaderBool[0]
                saveConfig()
                if settings.autoModloader then scanModloader() end
                purgeAllStreamedVehicles()
            end
            imgui.SameLine(0, 6 * scale)
            imgui.AlignTextToFramePadding()
            imgui.TextUnformatted(u8"Àâòî Modloader")

            local rescanText = u8"Ñêàíèðîâàòü Modloader"
            local purgeText = u8"Î÷èñòèòü ñòðèì"
            local rescanW = imgui.CalcTextSize(rescanText).x + framePadX * 2 + 10 * scale
            local purgeW = imgui.CalcTextSize(purgeText).x + framePadX * 2 + 10 * scale
            imgui.SameLine()
            local availTopR = imgui.GetContentRegionAvail().x
            if availTopR > (rescanW + purgeW + spaceX) then
                imgui.SetCursorPosX(imgui.GetCursorPosX() + availTopR - (rescanW + purgeW + spaceX))
            end
            if styleButton(rescanText, theme.them, imgui.ImVec2(rescanW, 0)) then
                scanModloader()
                purgeAllStreamedVehicles()
                showSystemNotification(u8"Ïàïêà Modloader ïðîñêàíèðîâàíà", 1)
            end
            imgui.SameLine(0, spaceX)
            if imgui.Button(purgeText, imgui.ImVec2(purgeW, 0)) then
                purgeAllStreamedVehicles()
                showSystemNotification(u8"Òþíèíã è âèíèëû î÷èùåíû íà âñåõ àâòî â ñòðèìå", 1)
            end

            imgui.Spacing()

            local filters = {
                { id = 1, label = u8"Âñå ìîäåëè" },
                { id = 2, label = u8"Òîëüêî àêòèâíûå" },
                { id = 3, label = u8"Èç Modloader" },
                { id = 4, label = u8"Ñåé÷àñ â ñòðèìå" }
            }
            for _, f in ipairs(filters) do
                if styleButton(f.label .. "##tflt_" .. f.id, UI.tuneFilterMode == f.id and theme.me or theme.them) then
                    UI.tuneFilterMode = f.id
                end
                imgui.SameLine(0, 4 * scale)
            end

            local btnOnAll = u8"Âêëþ÷èòü âñå"
            local btnOffAll = u8"Âûêëþ÷èòü âñå"
            local wOn = imgui.CalcTextSize(btnOnAll).x + framePadX * 2 + 10 * scale
            local wOff = imgui.CalcTextSize(btnOffAll).x + framePadX * 2 + 10 * scale
            imgui.SameLine()
            local availFltR = imgui.GetContentRegionAvail().x
            if availFltR > (wOn + wOff + spaceX) then
                imgui.SetCursorPosX(imgui.GetCursorPosX() + availFltR - (wOn + wOff + spaceX))
            end
            if styleButton(btnOnAll, theme.them, imgui.ImVec2(wOn, 0)) then
                for id = 400, 611 do modelBools[id][0] = true end
                saveConfig()
                purgeAllStreamedVehicles()
            end
            imgui.SameLine(0, spaceX)
            if styleButton(btnOffAll, theme.them, imgui.ImVec2(wOff, 0)) then
                for id = 400, 611 do modelBools[id][0] = false end
                saveConfig()
            end

            imgui.Spacing()
            imgui.PushItemWidth(imgui.GetContentRegionAvail().x)
            imgui.InputTextWithHint("##tuneSearch", u8"Ïîèñê àâòîìîáèëÿ ïî íàçâàíèþ èëè Model ID (400-611)...", UI.tuneSearch, ffi.sizeof(UI.tuneSearch))
            imgui.PopItemWidth()

            imgui.Spacing()
            imgui.BeginChild("##tuneModelsList", imgui.ImVec2(0, 0), true)

            local streamedModels = {}
            if UI.tuneFilterMode == 4 then
                for _, vCar in ipairs(getAllVehicles()) do
                    if doesVehicleExist(vCar) then
                        streamedModels[getCarModel(vCar)] = true
                    end
                end
            end

            local searchTerm = cp1251_lower(trim(u8:decode(ffi.string(UI.tuneSearch))))
            imgui.Columns(2, "TuneVehiclesCols", false)

            for id = 400, 611 do
                local name = vehicleNames[id] or "Unknown"
                local isActive = settings.disableAllTune or modelBools[id][0] or (settings.autoModloader and modloaderModels[id])
                local passFilter = true

                if UI.tuneFilterMode == 2 and not isActive then passFilter = false end
                if UI.tuneFilterMode == 3 and not modloaderModels[id] then passFilter = false end
                if UI.tuneFilterMode == 4 and not streamedModels[id] then passFilter = false end

                if passFilter and searchTerm ~= "" then
                    local matchName = string.find(string.lower(name), searchTerm, 1, true)
                    local matchId = string.find(tostring(id), searchTerm, 1, true)
                    if not matchName and not matchId then passFilter = false end
                end

                if passFilter then
                    if settings.disableAllTune or (settings.autoModloader and modloaderModels[id]) then
                        local dummy = imgui.new.bool(true)
                        ToggleButton("##t_sw_" .. id, dummy, scale, theme.online)
                    else
                        if ToggleButton("##t_sw_" .. id, modelBools[id], scale) then
                            saveConfig()
                            if modelBools[id][0] then
                                purgeAllStreamedVehicles()
                            end
                        end
                    end
                    imgui.SameLine(0, 8 * scale)
                    imgui.AlignTextToFramePadding()
                    local mlTag = modloaderModels[id] and " [Modloader]" or ""
                    imgui.TextColored(isActive and theme.white or theme.subtext, u8(string.format("%s (ID: %d)%s", name, id, mlTag)))
                    imgui.NextColumn()
                end
            end

            imgui.Columns(1)
            imgui.EndChild()

        elseif UI.currentTab == 3 then
            if imgui.Button(u8"Âíåñòè èçìåíåíèÿ (èç ñòðîêè)", imgui.ImVec2(225 * scale, 0)) then
                openHandlingImportWindow(curModel or UI.manualModelId)
            end

            imgui.SameLine(0, spaceX)
            if styleButton(u8"Èçìåí¸ííûå àâòî", UI.handSubMode == 1 and theme.me or theme.them, imgui.ImVec2(145 * scale, 0)) then
                UI.handSubMode = 1
            end

            imgui.SameLine(0, spaceX)
            if styleButton(u8"Ðó÷íàÿ íàñòðîéêà", UI.handSubMode == 2 and theme.me or theme.them, imgui.ImVec2(165 * scale, 0)) then
                UI.handSubMode = 2
                if curModel then UI.manualModelId = curModel end
                loadModelHandlingToManualUI(UI.manualModelId)
            end

            local isConfReset = (os.clock() < UI.confirmResetAllHandTimer)
            local resetAllLabel = isConfReset and u8"Ïîäòâåðäèòü ñáðîñ?" or u8"Ñáðîñèòü âñå"
            local resetAllW = imgui.CalcTextSize(resetAllLabel).x + framePadX * 2 + 12 * scale
            imgui.SameLine()
            local availHandR = imgui.GetContentRegionAvail().x
            if availHandR > resetAllW then
                imgui.SetCursorPosX(imgui.GetCursorPosX() + availHandR - resetAllW)
            end
            if styleButton(resetAllLabel, isConfReset and theme.danger or theme.them, imgui.ImVec2(resetAllW, 0)) then
                if not isConfReset then
                    UI.confirmResetAllHandTimer = os.clock() + 3.0
                else
                    UI.confirmResetAllHandTimer = 0
                    for mId, _ in pairs(savedHandlings) do
                        resetModelHandlingToDefault(mId)
                    end
                    savedHandlings = {}
                    saveConfig()
                    showSystemNotification(u8"Âåñü èçìåí¸ííûé õåíäëèíã ñáðîøåí ê ñòàíäàðòó", 1)
                end
            end

            imgui.Spacing()

            if UI.handSubMode == 1 then
                imgui.PushItemWidth(imgui.GetContentRegionAvail().x)
                imgui.InputTextWithHint("##handSearch", u8"Ïîèñê ïî ñîõðàí¸ííûì àâòîìîáèëÿì (íàçâàíèå èëè ID)...", UI.handSearch, ffi.sizeof(UI.handSearch))
                imgui.PopItemWidth()

                imgui.Spacing()
                imgui.BeginChild("##savedHandlingList", imgui.ImVec2(0, 0), true)

                local flt = cp1251_lower(trim(u8:decode(ffi.string(UI.handSearch))))
                local dl = imgui.GetWindowDrawList()
                local availW = imgui.GetContentRegionAvail().x
                local padX = 12 * scale
                local padY = 8 * scale
                local toRemoveModel = nil
                local visibleCount = 0

                local sortedIds = {}
                for mId in pairs(savedHandlings) do
                    sortedIds[#sortedIds + 1] = mId
                end
                table.sort(sortedIds)

                for _, mId in ipairs(sortedIds) do
                    local entry = savedHandlings[mId]
                    local vName = vehicleNames[mId] or "Unknown"
                    local pass = (flt == "") or vName:lower():find(flt, 1, true) or tostring(mId):find(flt, 1, true)

                    if pass then
                        visibleCount = visibleCount + 1
                        local paramCount = 0
                        for _ in pairs(entry.values or {}) do paramCount = paramCount + 1 end

                        local cardH = 64 * scale
                        local startPos = imgui.GetCursorPos()
                        local pMin = imgui.GetCursorScreenPos()
                        local pMax = imgui.ImVec2(pMin.x + availW, pMin.y + cardH)

                        dl:AddRectFilled(pMin, pMax, imgui.GetColorU32Vec4(imgui.ImVec4(theme.them.x, theme.them.y, theme.them.z, 0.45)), 8.0 * scale)

                        imgui.SetCursorPos(imgui.ImVec2(startPos.x + padX, startPos.y + padY))
                        local enBool = imgui.new.bool(entry.enabled)
                        if ToggleButton("##h_en_" .. mId, enBool, scale) then
                            entry.enabled = enBool[0]
                            if entry.enabled then
                                applySavedHandlingEntry(mId, entry)
                                showSystemNotification(u8(string.format("Õåíäëèíã %s âêëþ÷¸í", vName)), 1)
                            else
                                resetModelHandlingToDefault(mId)
                                showSystemNotification(u8(string.format("Õåíäëèíã %s âðåìåííî âûêëþ÷åí", vName)), 3)
                            end
                            saveConfig()
                        end

                        imgui.SameLine(0, 10 * scale)
                        imgui.AlignTextToFramePadding()
                        imgui.TextColored(theme.white, u8(string.format("%s (Model ID: %d)", vName, mId)))

                        imgui.SameLine(0, 10 * scale)
                        imgui.TextColored(entry.safeMode and theme.online or theme.warn,
                            entry.safeMode and u8"[Áåçîïàñíûé ðåæèì: Ïîäâåñêà è êîë¸ñà]" or u8"[Ïîëíàÿ çàìåíà ñòðîêè]")

                        imgui.SameLine(0, 10 * scale)
                        imgui.TextColored(theme.subtext, u8(string.format("Ïàðàìåòðîâ: %d", paramCount)))

                        local editBtnW = 105 * scale
                        local manualBtnW = 105 * scale
                        local delBtnW = 30 * scale
                        local rightClusterW = editBtnW + manualBtnW + delBtnW + spaceX * 2

                        imgui.SameLine(availW - rightClusterW - padX)
                        if imgui.Button(u8"Ñòðîêà##h_imp_" .. mId, imgui.ImVec2(editBtnW, 24 * scale)) then
                            ffi.fill(UI.importLineBuf, ffi.sizeof(UI.importLineBuf), 0)
                            ffi.copy(UI.importLineBuf, u8(entry.rawLine or ""))
                            UI.importSafeMode[0] = entry.safeMode
                            openHandlingImportWindow(mId)
                        end

                        imgui.SameLine(0, spaceX)
                        if styleButton(u8"Ïîëçóíêè##h_man_" .. mId, theme.them, imgui.ImVec2(manualBtnW, 24 * scale)) then
                            UI.manualModelId = mId
                            loadModelHandlingToManualUI(mId)
                            UI.handSubMode = 2
                        end

                        imgui.SameLine(0, spaceX)
                        if styleButton("X##h_del_" .. mId, theme.danger, imgui.ImVec2(delBtnW, 24 * scale)) then
                            toRemoveModel = mId
                        end

                        imgui.SetCursorPos(imgui.ImVec2(startPos.x + padX, startPos.y + padY + 30 * scale))
                        local previewLine = (entry.rawLine and entry.rawLine ~= "") and entry.rawLine or "Íàñòðîåíî âðó÷íóþ ÷åðåç ðåäàêòîð ïàðàìåòðîâ"
                        if #previewLine > 95 then
                            previewLine = previewLine:sub(1, 95) .. "..."
                        end
                        imgui.TextColored(theme.muted, u8("Ñòðîêà: " .. previewLine))

                        imgui.SetCursorPos(imgui.ImVec2(startPos.x, startPos.y + cardH + 6 * scale))
                    end
                end

                if toRemoveModel then
                    resetModelHandlingToDefault(toRemoveModel)
                    savedHandlings[toRemoveModel] = nil
                    saveConfig()
                    showSystemNotification(u8"Õåíäëèíã àâòîìîáèëÿ ñáðîøåí è óäàë¸í", 3)
                end

                if visibleCount == 0 then
                    local emptyText = u8"Ñïèñîê èçìåí¸ííûõ àâòî ïóñò. Íàæìèòå «Âíåñòè èçìåíåíèÿ (èç ñòðîêè)», ÷òîáû íàñòðîèòü ïîäâåñêó èëè õåíäëèíã."
                    local tSize = imgui.CalcTextSize(emptyText)
                    local avail = imgui.GetContentRegionAvail()
                    local cPos = imgui.GetCursorPos()
                    imgui.SetCursorPos(imgui.ImVec2(cPos.x + (avail.x - tSize.x) * 0.5, cPos.y + (avail.y - tSize.y) * 0.5))
                    imgui.TextColored(theme.muted, emptyText)
                end

                imgui.EndChild()

            else
                imgui.AlignTextToFramePadding()
                imgui.TextColored(theme.muted, u8"Ìîäåëü:")
                imgui.SameLine(0, 8 * scale)

                local mSelName = string.format("%s [ID: %d]", vehicleNames[UI.manualModelId] or "Unknown", UI.manualModelId)
                imgui.PushItemWidth(240 * scale)
                if imgui.BeginCombo("##manualCarCombo", u8(mSelName)) then
                    for id = 400, 611 do
                        local vName = vehicleNames[id] or "Unknown"
                        if imgui.Selectable(u8(string.format("%s (ID: %d)", vName, id)), UI.manualModelId == id) then
                            UI.manualModelId = id
                            loadModelHandlingToManualUI(id)
                        end
                    end
                    imgui.EndCombo()
                end
                imgui.PopItemWidth()

                imgui.SameLine(0, spaceX)
                if imgui.Button(u8"Ïðèìåíèòü íàñòðîéêè") then
                    backupDefaultHandling(UI.manualModelId)
                    local baseAddr = getHandlingBaseAddr(UI.manualModelId)
                    if baseAddr then
                        local vals = {}
                        for _, f in ipairs(handlingFields) do
                            local v = manualBuffers[f.key][0]
                            if f.type == "drive" then
                                v = (v == 0 and 82) or (v == 1 and 70) or 52
                            elseif f.type == "eng" then
                                v = (v == 0 and 80) or (v == 1 and 68) or 69
                            end
                            writeHandlingField(baseAddr, f, v)
                            vals[f.key] = v
                        end
                        refreshStreamedVehiclesSuspension(UI.manualModelId)
                        savedHandlings[UI.manualModelId] = {
                            enabled = true,
                            safeMode = false,
                            rawLine = (savedHandlings[UI.manualModelId] and savedHandlings[UI.manualModelId].rawLine) or "",
                            values = vals
                        }
                        saveConfig()
                        showSystemNotification(u8(string.format("Ïàðàìåòðû %s îáíîâëåíû!", vehicleNames[UI.manualModelId] or UI.manualModelId)), 1)
                    end
                end

                imgui.SameLine(0, spaceX)
                if styleButton(u8"Ïåðå÷èòàòü èç ïàìÿòè", theme.them) then
                    loadModelHandlingToManualUI(UI.manualModelId)
                end

                imgui.SameLine(0, spaceX)
                if styleButton(u8"Ñáðîñèòü ê ñòàíäàðòó", theme.danger) then
                    resetModelHandlingToDefault(UI.manualModelId)
                    savedHandlings[UI.manualModelId] = nil
                    loadModelHandlingToManualUI(UI.manualModelId)
                    saveConfig()
                    showSystemNotification(u8"Âîçâðàùåíû ñòàíäàðòíûå íàñòðîéêè ìîäåëè", 3)
                end

                imgui.Spacing()
                imgui.BeginChild("##manualEditorChild", imgui.ImVec2(0, 0), true)

                local catNames = {
                    [1] = u8"Íàñòðîéêè ïîäâåñêè è ïîñàäêè (Suspension)",
                    [2] = u8"Êîë¸ñà, ñöåïëåíèå è öåíòð òÿæåñòè (Wheels & Centre of Mass)",
                    [3] = u8"Äâèãàòåëü, ðàçãîí, ìàññà è òîðìîçà (Engine & Physical)"
                }

                for catId = 1, 3 do
                    imgui.TextColored(catId <= 2 and theme.online or theme.warn, catNames[catId])
                    imgui.Separator()
                    imgui.Columns(2, "ManCols_" .. catId, false)
                    for _, f in ipairs(handlingFields) do
                        if f.cat == catId then
                            imgui.PushItemWidth(155 * scale)
                            if f.type == "drive" then
                                local items = { "RWD (Çàäíèé)", "FWD (Ïåðåäíèé)", "AWD (Ïîëíûé)" }
                                if imgui.BeginCombo(u8(f.label) .. "##m_" .. f.key, u8(items[manualBuffers[f.key][0] + 1] or items[1])) then
                                    for idx, it in ipairs(items) do
                                        if imgui.Selectable(u8(it), manualBuffers[f.key][0] == (idx - 1)) then
                                            manualBuffers[f.key][0] = idx - 1
                                        end
                                    end
                                    imgui.EndCombo()
                                end
                            elseif f.type == "eng" then
                                local items = { "Petrol (Áåíçèí)", "Diesel (Äèçåëü)", "Electric (Ýëåêòðî)" }
                                if imgui.BeginCombo(u8(f.label) .. "##m_" .. f.key, u8(items[manualBuffers[f.key][0] + 1] or items[1])) then
                                    for idx, it in ipairs(items) do
                                        if imgui.Selectable(u8(it), manualBuffers[f.key][0] == (idx - 1)) then
                                            manualBuffers[f.key][0] = idx - 1
                                        end
                                    end
                                    imgui.EndCombo()
                                end
                            elseif f.type == "abs" then
                                local items = { "Âûêëþ÷åí (0)", "Âêëþ÷¸í (1)" }
                                if imgui.BeginCombo(u8(f.label) .. "##m_" .. f.key, u8(items[manualBuffers[f.key][0] + 1] or items[1])) then
                                    for idx, it in ipairs(items) do
                                        if imgui.Selectable(u8(it), manualBuffers[f.key][0] == (idx - 1)) then
                                            manualBuffers[f.key][0] = idx - 1
                                        end
                                    end
                                    imgui.EndCombo()
                                end
                            elseif f.type == "int8" then
                                imgui.InputInt(u8(f.label) .. "##m_" .. f.key, manualBuffers[f.key], 1, 5)
                            else
                                imgui.InputFloat(u8(f.label) .. "##m_" .. f.key, manualBuffers[f.key], 0.02, 0.2, "%.3f")
                            end
                            imgui.PopItemWidth()
                            imgui.NextColumn()
                        end
                    end
                    imgui.Columns(1)
                    imgui.Spacing()
                end

                imgui.EndChild()
            end
        end

        imgui.End()
    end

    PopMessengerStyle()
end)

function onScriptTerminate(scr, quitGame)
    if scr == thisScript() then
        for path, _ in pairs(activeTempFiles) do
            pcall(os.remove, path)
        end
    end
end

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    if ensureSelfEncodingCP1251() then return end

    local oldScript = script.find("zCar Studio") or script.find("zCarStudio")
    if oldScript and oldScript ~= thisScript() then
        pcall(function() oldScript:unload() end)
    end

    loadConfig()
    scanModloader()
    checkUpdates(false)

    if settings.autoApplyHandling then
        for mId, entry in pairs(savedHandlings) do
            if entry.enabled then
                applySavedHandlingEntry(mId, entry)
            end
        end
    end

    for _, car in ipairs(getAllVehicles()) do
        if doesVehicleExist(car) then
            local ok, id = sampGetVehicleIdByCarHandle(car)
            if ok then
                vehicleModelsCache[id] = getCarModel(car)
                originalColors[id] = getFullCarColors(car)
            end
        end
    end
    purgeAllStreamedVehicles()

    sampRegisterChatCommand("ctool", function()
        UI.windowState[0] = not UI.windowState[0]
    end)

    local lastPeriodicCheck = 0
    local activePaintedCars = {}

    while true do
        wait(0)

        local isPreviewActiveNow = false

        if isCharInAnyCar(PLAYER_PED) then
            local car = storeCarCharIsInNoSave(PLAYER_PED)
            if doesVehicleExist(car) then
                local ok, id = sampGetVehicleIdByCarHandle(car)
                local validId = ok and id or nil

                if validId and not originalColors[validId] then
                    originalColors[validId] = getFullCarColors(car)
                end

                if UI.windowState[0] and UI.currentTab == 1 and settings.livePreview then
                    if previewedCarHandle ~= car then
                        if previewedCarHandle and doesVehicleExist(previewedCarHandle) then
                            restoreVehicleColor(previewedCarId, previewedCarHandle)
                        end
                        previewedCarHandle = car
                        previewedCarId = validId

                        local activeCol = getEffectiveVehicleColor(validId, car)
                        if activeCol then
                            UI.c1[0], UI.c2[0], UI.c3[0], UI.c4[0] = activeCol[1], activeCol[2], activeCol[3], activeCol[4]
                        elseif validId and originalColors[validId] then
                            local oc = originalColors[validId]
                            UI.c1[0], UI.c2[0], UI.c3[0], UI.c4[0] = oc[1], oc[2], oc[3], oc[4]
                        else
                            local curCols = getFullCarColors(car)
                            UI.c1[0], UI.c2[0], UI.c3[0], UI.c4[0] = curCols[1], curCols[2], curCols[3], curCols[4]
                        end
                    end

                    local curPreviewCols = {UI.c1[0], UI.c2[0], UI.c3[0], UI.c4[0]}
                    if settings.keepUnsavedColor then
                        unsavedCarColors[car] = curPreviewCols
                    end
                    applyColors(car, curPreviewCols)
                    isPreviewActiveNow = true
                else
                    local activeCol = getEffectiveVehicleColor(validId, car)
                    if activeCol then
                        applyColors(car, activeCol)
                    end
                end
            end
        end

        if not isPreviewActiveNow and previewedCarHandle ~= nil then
            if doesVehicleExist(previewedCarHandle) then
                if not settings.keepUnsavedColor then
                    unsavedCarColors[previewedCarHandle] = nil
                end
                restoreVehicleColor(previewedCarId, previewedCarHandle)
            end
            previewedCarHandle = nil
            previewedCarId = nil
        end

        local now = os.clock()
        if now - lastPeriodicCheck >= 0.30 then
            lastPeriodicCheck = now

            local oldScr = script.find("zCar Studio") or script.find("zCarStudio")
            if oldScr and oldScr ~= thisScript() then
                pcall(function() oldScr:unload() end)
            end

            activePaintedCars = {}
            for _, car in ipairs(getAllVehicles()) do
                if doesVehicleExist(car) then
                    local ok, id = sampGetVehicleIdByCarHandle(car)
                    local validId = ok and id or nil
                    stripTuningAndVinylFromCar(car, validId, false)
                    local activeCol = getEffectiveVehicleColor(validId, car)
                    if activeCol then
                        activePaintedCars[#activePaintedCars + 1] = { handle = car, preset = activeCol }
                    end
                end
            end
        end

        for i = 1, #activePaintedCars do
            local item = activePaintedCars[i]
            if doesVehicleExist(item.handle) and not (isPreviewActiveNow and item.handle == previewedCarHandle) then
                applyColors(item.handle, item.preset)
            end
        end
    end
end
