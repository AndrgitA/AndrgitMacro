local ADDON_CMD_NAME = "ANDRGITMACRO"

---Таблица всех возможных таргетов UNIT
local ANDRGITMACRO_TARGET = {
	["@target"] = "target",
	["@focus"] = "focus",
	["@mouseover"] = "mouseover",
	["@mouseoverframe"] = "mouseover",
	["@player"] = "player",
};

---Таблица всех возможных параметров проверок
local ANDRGITMACRO_OPTION = {
	["HELP"] = "help",
	["HARM"] = "harm",
	["NOHARM"] = "noharm",
	["DEAD"] = "dead",
	["DEADORGHOST"] = "deadorghost",
	["NOBUFF"] = "nobuff",
	["BUFF"] = "buff",
	-- ["NODEBUFF"] = "nodebuff",
	-- ["DEBUFF"] = "debuff",
	["USABLEACTION"] = "usableaction",
	["NOTUSABLEACTION"] = "notusableaction",
	["CD"] = "cd",
	["NOCD"] = "nocd",
};

local MEMOIZE_CACHE_DATA = {};
local MAX_COUNT_BUFFS = 64;

AndrgitMacro = CreateFrame("Frame", nil, UIParent);
AndrgitMacro.needUpdate = {
	spellBookData = true,
};
AndrgitMacro.cacheData = {
	spellBookData = nil,
};

AndrgitMacro:RegisterEvent("ADDON_LOADED");
AndrgitMacro:RegisterEvent("CHARACTER_POINTS_CHANGED");
AndrgitMacro:RegisterEvent("SPELLS_CHANGED");
AndrgitMacro:RegisterEvent("LEARNED_SPELL_IN_TAB");
AndrgitMacro:SetScript("OnEvent", function()
	if (
		event == "CHARACTER_POINTS_CHANGED" or
		event == "SPELLS_CHANGED" or
		event == "LEARNED_SPELL_IN_TAB"
	) then
		this.needUpdate.spellBookData = true;
	end
end)

local ANDRGITMACRO_Tooltip = CreateFrame("GameTooltip", "AndrgitMacroTooltip", nil, "GameTooltipTemplate");
local ANDRGITMACRO_TooltipPrefix = "AndrgitMacroTooltip";
ANDRGITMACRO_Tooltip:SetOwner(WorldFrame, "ANCHOR_NONE");

---Локальная функция принта
---@param ... unknown
---@return void
local function Print(...)
  if arg.n == 0 then
    return
  end

  local result = tostring(arg[1]) 
  for i = 2, arg.n do
    result = result.." "..tostring(arg[i])
  end

  DEFAULT_CHAT_FRAME:AddMessage(result, .5, 1, .3)
end

local print = Print

-- Lua APIs
local type, next, pairs, tostring = type, next, pairs, tostring
local strsub, strfind, strgmatch, strgfind = string.sub, string.find, string.gmatch, string.gfind
local tinsert, tconcat = table.insert, table.concat
local error, assert = error, assert


---Функция подсчета размера таблицы
---@param T table таблица над которой производится подсчет 
---@return number
local function tablelength(T)
	if not T then
		return nil
	end
	
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

---Возвращает значение из кортежа данных по позиции n
---@param n number
---@param ... any
---@return string
function select (n, ...)
	return arg[n]
end

---Разделение строки на массив подстрок разделенных символом
---@param inputstr string входящая строка
---@param sep string разделяющий символ
---@return table<number,string>
function splitString(inputstr, sep)
	if (type(inputstr) ~= "string") then
		return nil;
	end
  if sep == nil then
    sep = "%s";
  end

  local t = {};
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str);
  end
  return t;
end


local ANDRGITMACRO_ShowAddonHelpInfo
local ANDRGITMACRO_ParseMacro

---Главная функция обработки команды /andrgitmacro | /am
---@param msg string
---@return void
function ANDRGITMACRO_SlashCommand(msg)
	if msg == "" then
		-- показать инфомрацию об аддоне
		ANDRGITMACRO_ShowAddonHelpInfo()
	else
		ANDRGITMACRO_StartMacro(msg)
	end
end

--- Показать информацию об аддоне в чат игры
---@return void
ANDRGITMACRO_ShowAddonHelpInfo = function()
	local commandColor = "|c0000ff00"
	local textColor = "|caaffff44"
	local startText = commandColor..SLASH_ANDRGITMACRO1
	DEFAULT_CHAT_FRAME:AddMessage("Аддон `AndrgitMacro`. Предназначен для удобного использования спелами через макросы",1,.7,0);
	DEFAULT_CHAT_FRAME:AddMessage("Список команд:",0,1,0);

	DEFAULT_CHAT_FRAME:AddMessage(startText.." "..textColor.."- Показать инфо.");
	DEFAULT_CHAT_FRAME:AddMessage(startText.." [] "..textColor.."- Последовательные проверки через условие 'ИЛИ' (допустимо несколько условий). Внутри каждого такого условия можно перечислять через запятую условия, которые будут проверяться через условие 'И'");
	DEFAULT_CHAT_FRAME:AddMessage(startText.." [@player][@focus][@mouseover][@target][@mouseoverframe] "..textColor.."- 'TARGET'. Обращение к таргету для проверки условий, обязательный параметр на 1 месте");
	DEFAULT_CHAT_FRAME:AddMessage(startText.." [TARGET,[help][harm][noharm][dead][deadorghost]...]"..textColor.."- Необязательные параметры идущие после параметра 'TARGET'. Перечисление идет через запятую без пробелов.");
	DEFAULT_CHAT_FRAME:AddMessage("\nКаждая из опций означает :",0,1,0);
	DEFAULT_CHAT_FRAME:AddMessage(" [help]"..textColor.."- проверка, что текущий таргет может быть ассистом для вас. кому вы можете дать хил, бафф или подобные дейсвтия");
	DEFAULT_CHAT_FRAME:AddMessage(" [harm]"..textColor.."- проверка, что текущий таргет является для вас враждебным");
	DEFAULT_CHAT_FRAME:AddMessage(" [noharm]"..textColor.."- проверка, что текущий таргет является для вас дружественным");
	DEFAULT_CHAT_FRAME:AddMessage(" [dead]"..textColor.."- проверка, что текущий таргет является мертвым");
	DEFAULT_CHAT_FRAME:AddMessage(" [deadorghost]"..textColor.."- проверка, что текущий таргет является мертвым или в форме духа");

	DEFAULT_CHAT_FRAME:AddMessage(" [nobuff:BUFFNAME]"..textColor.."- проверка, что на игроке нет указанного баффа BUFFNAME");
	DEFAULT_CHAT_FRAME:AddMessage(" [buff:BUFFNAME]"..textColor.."- проверка, что на игроке есть указанный бафф BUFFNAME");
	DEFAULT_CHAT_FRAME:AddMessage(" [usableaction:slotID]"..textColor.."- проверка, что возможно нажать на actionbar slotID");
	DEFAULT_CHAT_FRAME:AddMessage(" [notusableaction:slotID]"..textColor.."- проверка, что нельзя нажать на actionbar slotID");
	DEFAULT_CHAT_FRAME:AddMessage(" [cd:SPELLNAME]"..textColor.."- проверка, что способность SPELLNAME на кулдауне");
	DEFAULT_CHAT_FRAME:AddMessage(" [nocd:SPELLNAME]"..textColor.."- проверка, что способность SPELLNAME не на кулдауне");

	DEFAULT_CHAT_FRAME:AddMessage("\nПримеры :",0,1,0);
	DEFAULT_CHAT_FRAME:AddMessage(startText.." [@mouseover,noharm] Arcane intellect"..textColor.."- Дать бафф юниту который находится в mouseover таргете и является дружественным");
	DEFAULT_CHAT_FRAME:AddMessage(startText.." [@target,harm] Fireball "..textColor.."- Каст Fireball в юнита который находится в таргете и является враждебным");
	DEFAULT_CHAT_FRAME:AddMessage(startText.." [@mouseover,noharm][@target,noharm][@player] Arcane Intellect "..textColor.."- Каст Arcane Intellect в юнита который находится в mouseover таргете и является дружественным или тому, кто является таргетом, или самому себе. Выполнится первое из возможных действий");
end

---Парсер параметров для команды /andrgitmacro
---@param str string
---@return table<number, table<number, string>>
local parseOptions = function(str)
	local result = {}
	for v in strgfind(str, '%[([^%[%]]+)%]') do
		table.insert(result, splitString(v, ","));
	end
	return result
end

---Парсер входящей строки на необходимые елементы разбора для команды /andrgitmacro
---@param str string
---@return table<number, table<number, string>>|nil
---@return string|nil
ANDRGITMACRO_ParseMacro = function(str)
	local options = nil

	local _, _, strCond, strAction = strfind(str, "(%[.*%])%s*([^%[%];]*)%s*;?");
	
	if strAction then
		if strCond then
			options = parseOptions(strCond)
		end
	end

	return options, strAction
end

---Проверка данных парсера для активации марокса
---@param options table<number, string> входящая таблица параметров
---@param action string имя заклинания для CastSpellByName
---@param func function вызов обратной функции
---@return void
local checkMacroActive = function(options, action, func)
	local unitKey, unit = options[1], nil
	local callAction = function(unitTarget, actionValue)
    local restore_target = true
		local ue = UnitExists("target");

		if UnitIsUnit("target", unitTarget) then
			restore_target = false
		end
		TargetUnit(unitTarget)
		CastSpellByName(actionValue)
		if (ue) then
			if restore_target then
				TargetLastTarget();
			end
		else
			ClearTarget();
		end
	end

	local _getMacroFrameLabel = function(frame)
		if (not frame) then 
			return nil;
		end
		if (frame.label and frame.id) then
			return frame.label .. frame.id;
		end
		if (frame.unit) then
			return frame.unit;
		end
		return nil;
	end

	local frame = GetMouseFocus();

	if not unitKey or not ANDRGITMACRO_TARGET[unitKey] then
		if GetCVar("autoSelfCast") == "1" then 
			unitKey = "@player"
		else
			return;
		end
	end

	local labelFrame = _getMacroFrameLabel(frame);
	
	unit = ANDRGITMACRO_TARGET[unitKey]
	if (labelFrame) then
		unit = labelFrame;
	elseif (unitKey == "@mouseoverframe" or not UnitExists(unit)) then
		return ;
	end
	
	local callEnabled = true
	for i = 2, table.getn(options) do
		local splitOptions = splitString(options[i], ':');
		local option, optionValue = splitOptions[1], splitOptions[2];
		
		if (option == ANDRGITMACRO_OPTION.HELP) then
			if not UnitCanAssist("player", unit) then
				callEnabled = false
				break;
			end
		elseif (option == ANDRGITMACRO_OPTION.HARM) then 
			if UnitIsFriend("player", unit) then
				callEnabled = false;
				break;
			end
		elseif (option == ANDRGITMACRO_OPTION.NOHARM) then
			if not UnitIsFriend("player", unit) then
				callEnabled = false;
				break;
			end
		elseif (option == ANDRGITMACRO_OPTION.DEAD) then
			if not UnitIsDead(unit) then
				callEnabled = false;
				break;
			end
		elseif (option == ANDRGITMACRO_OPTION.DEADORGHOST) then
			if not UnitIsDeadOrGhost(unit) then
				callEnabled = false;
				break;
			end
		elseif (option == ANDRGITMACRO_OPTION.NOBUFF) then
			if (ANDRGITMACRO_HasBuff(optionValue)) then
				callEnabled = false;
				break;
			end
		elseif (option == ANDRGITMACRO_OPTION.BUFF) then
			if (not ANDRGITMACRO_HasBuff(optionValue)) then
				callEnabled = false;
				break;
			end
		elseif (option == ANDRGITMACRO_OPTION.USABLEACTION) then
			if (not IsUsableAction(optionValue)) then
				callEnabled = false;
				break;
			end
		elseif (option == ANDRGITMACRO_OPTION.NOTUSABLEACTION) then
			if (IsUsableAction(optionValue)) then
				callEnabled = false;
				break;
			end
		elseif (option == ANDRGITMACRO_OPTION.CD) then
			local getSpellIndex = ANDRGITMACRO_GetSpellIndex(optionValue);
			local hasCD = getSpellIndex and GetSpellCooldown(getSpellIndex, BOOKTYPE_SPELL);
			if (not getSpellIndex or hasCD == 0) then
				callEnabled = false;
				break;
			end
		elseif (option == ANDRGITMACRO_OPTION.NOCD) then
			local getSpellIndex = ANDRGITMACRO_GetSpellIndex(optionValue);
			local hasCD = getSpellIndex and GetSpellCooldown(getSpellIndex, BOOKTYPE_SPELL);
			if (not getSpellIndex or hasCD > 0) then
				callEnabled = false;
				break;
			end
		else
			callEnabled = false
			break;
		end
	end

	if callEnabled then
		func(function() callAction(unit, action) end)
	end
end

---Начало работы с разбиением, проверкой и активацией кода по макросу
---@param str string
---@return void
function ANDRGITMACRO_StartMacro(str)
	local options, action = ANDRGITMACRO_ParseMacro(str)

	if not action then
		return
	end

	-- ANDRGITMACRO_TARGET

	if options then
		local isBreakLoop = false
		-- OR
		for i, orValue in pairs(options) do
			if orValue then
				checkMacroActive(orValue, action, function (targetFunc)
					if targetFunc then
						targetFunc();
						isBreakLoop = true
					end
				end)
			end
			if isBreakLoop then
				break;
			end
		end
	end
end

---Use item in bags by name
---@param name string full item name
---@return void
function ANDRGITMACRO_UseItemByName(name)
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) do
      local item = GetContainerItemLink(bag, slot);
			if item and string.find(item, name) then
				UseContainerItem(bag, slot);
				return;
			end
    end
  end
end

function ANDRGITMACRO_HasBuff(aura)
	for i=0, MAX_COUNT_BUFFS - 1 do
		local index = GetPlayerBuff(i, 'HELPFUL');
		if (index < 0) then
			break;
		end
		
		ANDRGITMACRO_Tooltip:SetPlayerBuff(index);
				
		local nameAura = getglobal("AndrgitMacroTooltipTextLeft1"):GetText();
		if (nameAura == aura) then
			return true;
		end
	end

	return false;
end

function ANDRGITMACRO_CancelAuras(auras)
	local tbAuras = {};
	local countAuras = 0;
	local findedAuras = 0;
	for _, value in pairs(auras) do
		tbAuras[value] = true;
		countAuras = countAuras + 1;
	end

	for i=0, MAX_COUNT_BUFFS - 1 do
		local index = GetPlayerBuff(i, 'HELPFUL');
		if (index < 0) then
			break;
		end
		
		ANDRGITMACRO_Tooltip:SetPlayerBuff(index);
				
		local nameAura = getglobal("AndrgitMacroTooltipTextLeft1"):GetText();
		if (nameAura and tbAuras[nameAura]) then
			findedAuras = findedAuras + 1;
			CancelPlayerBuff(index);
			if (countAuras == findedAuras) then
				break;
			end
		end
	end
end

function ANDRGITMACRO_ParserCancelAuras(names)
	if (string.len(names) == 0) then
		return;
	end
	
	local auraNames = splitString(names, ",");
	if (table.getn(auraNames) > 0) then
		ANDRGITMACRO_CancelAuras(auraNames);
	end
end


function ANDRGITMACRO_Memoize(name, func, updatetime)
	local key = name..tostring(func)..updatetime;
	if (MEMOIZE_CACHE_DATA[key]) then
		if (updatetime and (GetTime() - MEMOIZE_CACHE_DATA[key].time > updatetime)) then
			return MEMOIZE_CACHE_DATA[key].func;
		end
		return function()
			return MEMOIZE_CACHE_DATA[key];
		end;
	end

	MEMOIZE_CACHE_DATA[key] = {
		time = 0,
		data = nil,
		func = function(...)
			MEMOIZE_CACHE_DATA[key].data = func(unpack(arg));
			MEMOIZE_CACHE_DATA[key].time = GetTime();
	
			return MEMOIZE_CACHE_DATA[key];
		end,
	};
	return MEMOIZE_CACHE_DATA[key].func;
end

function ANDRGITMACRO_GetSpellsBookData()
	if (not AndrgitMacro.needUpdate.spellBookData and AndrgitMacro.cacheData.spellBookData) then
		return AndrgitMacro.cacheData.spellBookData;
	end

	local data = {};
	local MAX_TABS = GetNumSpellTabs()
	for tab=1, MAX_TABS do
		local name, texture, offset, numSpells = GetSpellTabInfo(tab)
		for spell=1, numSpells do
			local SpellID = spell + offset;

			ANDRGITMACRO_Tooltip:SetSpell(SpellID, BOOKTYPE_SPELL)
			local MAX_LINES = ANDRGITMACRO_Tooltip:NumLines()
			local spellName = getglobal(ANDRGITMACRO_TooltipPrefix.."TextLeft1"):GetText();
			if (spellName) then
				data[spellName] = {
					spellID = SpellID,
					["tab"] = name,
					["tooltipData"] = {},
				};
				for line=2, MAX_LINES do
					local left = getglobal(ANDRGITMACRO_TooltipPrefix .. "TextLeft" .. line)
					if left:GetText() then
						table.insert(data[spellName].tooltipData, left:GetText());
					end
				end
			end
		end
	end

	AndrgitMacro.cacheData.spellBookData = data;
	AndrgitMacro.needUpdate.spellBookData = false;
	return data;
end


function ANDRGITMACRO_GetSpellIndex(name)
	local spells = ANDRGITMACRO_GetSpellsBookData();
	for spell, data in pairs(spells) do
		if (spell == name) then
			return data.spellID;
		end
	end
	return nil;
end


SLASH_ANDRGITMACRO1 = "/andrgitmacro";
SLASH_ANDRGITMACRO2 = "/am";

SlashCmdList[ADDON_CMD_NAME] = ANDRGITMACRO_SlashCommand;

SLASH_ANDRGITMACRORELOAD1 = "/rl";
SlashCmdList["ANDRGITMACRORELOAD"] = ReloadUI;

SLASH_ANDRGITMACROUSEITEMBYNAME1 = "/amuseitem";
SlashCmdList["ANDRGITMACROUSEITEMBYNAME"] = ANDRGITMACRO_UseItemByName;

SLASH_ANDRGITMACROCANCELAURAS1 = "/amcancelauras";
SlashCmdList["ANDRGITMACROCANCELAURAS"] = ANDRGITMACRO_ParserCancelAuras;