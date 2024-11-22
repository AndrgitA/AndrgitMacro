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
	["NODEBUFF"] = "nodebuff",
	["DEBUFF"] = "debuff",
	
	["CD"] = "cd",
	["NOCD"] = "nocd",
	["USEACTIONSLOT"] = "useactionslot",
	["UNUSEACTIONSLOT"] = "unuseactionslot",
	["USEACTIONSPELL"] = "useactionspell",
	["UNUSEACTIONSPELL"] = "unuseactionspell",
	["USEACTIONITEM"] = "useactionitem",
	["UNUSEACTIONITEM"] = "unuseactionitem",
};

local MEMOIZE_CACHE_DATA = {};
local MAX_COUNT_BUFFS = 64;

AndrgitMacro = CreateFrame("Frame", nil, UIParent);
AndrgitMacro.needUpdate = {
	spellBookData = true,
	actionBarData = true,
};
AndrgitMacro.cacheData = {
	spellBookData = nil,
	actionBarData = nil,
};

AndrgitMacro:RegisterEvent("ADDON_LOADED");
AndrgitMacro:RegisterEvent("CHARACTER_POINTS_CHANGED");
AndrgitMacro:RegisterEvent("SPELLS_CHANGED");
AndrgitMacro:RegisterEvent("LEARNED_SPELL_IN_TAB");
AndrgitMacro:RegisterEvent("ACTIONBAR_SHOWGRID");
AndrgitMacro:RegisterEvent("ACTIONBAR_HIDEGRID");
AndrgitMacro:SetScript("OnEvent", function()
	if (
		event == "CHARACTER_POINTS_CHANGED" or
		event == "SPELLS_CHANGED" or
		event == "LEARNED_SPELL_IN_TAB"
	) then
		this.needUpdate.spellBookData = true;
	end
	
	if (
		event == "ACTIONBAR_SHOWGRID" or
		event == "ACTIONBAR_HIDEGRID"
	) then
		this.needUpdate.actionBarData = true;
	end

	
end)

local ANDRGITMACRO_TooltipName = "AndrgitMacroTooltip";
local ANDRGITMACRO_Tooltip = CreateFrame("GameTooltip", ANDRGITMACRO_TooltipName, nil, "GameTooltipTemplate");
ANDRGITMACRO_Tooltip:SetOwner(WorldFrame, "ANCHOR_NONE");

local ANDRGITMACRO_TooltipAuraName = "AndrgitMacroTooltipAura";
local ANDRGITMACRO_TooltipAura = CreateFrame("GameTooltip", ANDRGITMACRO_TooltipAuraName, nil, "GameTooltipTemplate");
ANDRGITMACRO_TooltipAura:SetOwner(WorldFrame, "ANCHOR_NONE");

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
		return nil;
	end
	
  local count = 0;
  for _ in pairs(T) do 
		count = count + 1;
	end
	return count;
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
	DEFAULT_CHAT_FRAME:AddMessage(" [nodebuff:DEBUFFNAME]"..textColor.."- проверка, что на игроке нет указанного дебаффа DEBUFFNAME");
	DEFAULT_CHAT_FRAME:AddMessage(" [debuff:DEBUFFNAME]"..textColor.."- проверка, что на игроке есть указанный дебафф DEBUFFNAME");
	DEFAULT_CHAT_FRAME:AddMessage(" [useactionslot:slotID]"..textColor.."- проверка, что возможно нажать на actionbar slotID");
	DEFAULT_CHAT_FRAME:AddMessage(" [unuseactionslot:slotID]"..textColor.."- проверка, что нельзя нажать на actionbar slotID");
	DEFAULT_CHAT_FRAME:AddMessage(" [useactionspell:SPELLNAME]"..textColor.."- проверка, что возможно нажать на actionbar для SPELL");
	DEFAULT_CHAT_FRAME:AddMessage(" [unuseactionspell:SPELLNAME]"..textColor.."- проверка, что нельзя нажать на actionbar для SPELL");
	DEFAULT_CHAT_FRAME:AddMessage(" [useactionitem:ITEMNAME]"..textColor.."- проверка, что возможно нажать на actionbar для ITEM");
	DEFAULT_CHAT_FRAME:AddMessage(" [unuseactionitem:ITEMNAME]"..textColor.."- проверка, что нельзя нажать на actionbar для ITEM");
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


local MACRO_RULES_METHODS = {
	[ANDRGITMACRO_OPTION.HELP] = function(unit)
		return UnitCanAssist("player", unit);
	end,
	[ANDRGITMACRO_OPTION.NOHARM] = function(unit)
		return UnitIsFriend("player", unit);
	end,
	[ANDRGITMACRO_OPTION.HARM] = function(unit)
		return not UnitIsFriend("player", unit);
	end,
	[ANDRGITMACRO_OPTION.DEAD] = function(unit)
		return UnitIsDead(unit);
	end,
	[ANDRGITMACRO_OPTION.DEADORGHOST] = function(unit)
		return UnitIsDeadOrGhost(unit);
	end,
	[ANDRGITMACRO_OPTION.BUFF] = function(unit, name)
		return ANDRGITMACRO_HasBuff(name);
	end,
	[ANDRGITMACRO_OPTION.NOBUFF] = function(unit, name)
		return not ANDRGITMACRO_HasBuff(name);
	end,
	[ANDRGITMACRO_OPTION.DEBUFF] = function(unit, name)
		return ANDRGITMACRO_HasDeBuff(name);
	end,
	[ANDRGITMACRO_OPTION.NODEBUFF] = function(unit, name)
		return not ANDRGITMACRO_HasDeBuff(name);
	end,
	[ANDRGITMACRO_OPTION.CD] = function(unit, name)
		local getSpellIndex = ANDRGITMACRO_GetSpellIndex(name);
		local hasCD = getSpellIndex and GetSpellCooldown(getSpellIndex, BOOKTYPE_SPELL);
		return hasCD > 0;
	end,
	[ANDRGITMACRO_OPTION.NOCD] = function(unit, name)
		local getSpellIndex = ANDRGITMACRO_GetSpellIndex(name);
		local hasCD = getSpellIndex and GetSpellCooldown(getSpellIndex, BOOKTYPE_SPELL);
		return hasCD == 0;
	end,
	[ANDRGITMACRO_OPTION.USEACTIONSLOT] = function(unit, slot)
		return IsUsableAction(slot);
	end,
	[ANDRGITMACRO_OPTION.UNUSEACTIONSLOT] = function(unit, slot)
		return not IsUsableAction(slot);
	end,
	[ANDRGITMACRO_OPTION.USEACTIONSPELL] = function(unit, name)
		local spell = ANDRGITMACRO_GetActionBarData().spells[name];
		return spell and IsUsableAction(spell[1].actionBarID);
	end,
	[ANDRGITMACRO_OPTION.UNUSEACTIONSPELL] = function(unit, name)
		local spell = ANDRGITMACRO_GetActionBarData().spells[name];
		return spell and not IsUsableAction(spell[1].actionBarID);
	end,
	[ANDRGITMACRO_OPTION.USEACTIONITEM] = function(unit, name)
		local item = ANDRGITMACRO_GetActionBarData().items[name];
		return item and IsUsableAction(item[1].actionBarID);
	end,
	[ANDRGITMACRO_OPTION.UNUSEACTIONITEM] = function(unit, name)
		local item = ANDRGITMACRO_GetActionBarData().items[name];
		return item and not IsUsableAction(item[1].actionBarID);
	end,
};

local isAcceptMacroRules = function(options, unit, action)
	for i = 2, table.getn(options) do
		local splitOptions = splitString(options[i], ':');
		local option, optionValue = splitOptions[1], splitOptions[2];

		if (not (MACRO_RULES_METHODS[option] and MACRO_RULES_METHODS[option](unit, optionValue))) then
			return false;
		end
	end

	return true;
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
	
	if (isAcceptMacroRules(options, unit, action)) then
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

function ANDRGITMACRO_HasAura(aura, type)
	local auraType = type or "HELPFUL";
	for i=0, MAX_COUNT_BUFFS - 1 do
		local index = GetPlayerBuff(i, auraType);
		if (index < 0) then
			break;
		end
		
		ANDRGITMACRO_TooltipAura:ClearLines();
		ANDRGITMACRO_TooltipAura:SetPlayerBuff(index, auraType);
		
		local nameAura = getglobal(ANDRGITMACRO_TooltipAuraName.."TextLeft1"):GetText();
		if (nameAura == aura) then
			return true;
		end
	end

	return false;
end

function ANDRGITMACRO_HasBuff(aura)
	return ANDRGITMACRO_HasAura(aura, "HELPFUL");
end

function ANDRGITMACRO_HasDeBuff(aura)
	return ANDRGITMACRO_HasAura(aura, "HARMFUL");
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

		ANDRGITMACRO_TooltipAura:ClearLines();
		ANDRGITMACRO_TooltipAura:SetPlayerBuff(index);
				
		local nameAura = getglobal(ANDRGITMACRO_TooltipAuraName.."TextLeft1"):GetText();
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

			ANDRGITMACRO_Tooltip:ClearLines();
			ANDRGITMACRO_Tooltip:SetSpell(SpellID, BOOKTYPE_SPELL);

			local MAX_LINES = ANDRGITMACRO_Tooltip:NumLines();
			local spellName = getglobal(ANDRGITMACRO_TooltipName.."TextLeft1"):GetText();
			if (spellName) then
				if (not data[spellName]) then
					data[spellName] = {};
				end
				
				local spellData = {
					spellID = SpellID,
					["tab"] = name,
					texture = texture,
					["tooltipData"] = {},
					rank = table.getn(data[spellName]) + 1,
				};
				for line=2, MAX_LINES do
					local left = getglobal(ANDRGITMACRO_TooltipName .. "TextLeft" .. line)
					if left:GetText() then
						table.insert(spellData.tooltipData, left:GetText());
					end
				end
				
				table.insert(data[spellName], spellData);
			end
		end
	end

	AndrgitMacro.cacheData.spellBookData = data;
	AndrgitMacro.needUpdate.spellBookData = false;
	return data;
end

local lockedActionBarData = false;
function ANDRGITMACRO_GetActionBarData(skipLocked)
	if (
		not AndrgitMacro.needUpdate.actionBarData or
		(lockedActionBarData and skipLocked ~= true)
	) then
		return AndrgitMacro.cacheData.actionBarData;
	end

	lockedActionBarData = true;

	local data = {
		spells = {},
		items = {},
		macros = {},
		actionBars = {},
	};
	local MAX_ACTIONS = 280;
	local macroName, isASpell, spellName, rank, itemName, texture;
	local spellBookData = ANDRGITMACRO_GetSpellsBookData();
	
	for index=1, MAX_ACTIONS do
		if (HasAction(index)) then
			macroName, isASpell, spellName, rank, itemName = nil, nil, nil, nil, nil;
			local actionData = {
				spell = nil,
				macro = nil,
				item = nil,
				texture = nil,
				tooltipData = nil,
			}
			
			texture = GetActionTexture(index);
			if (texture) then
				actionData.texture = texture;
			end

			macroName = GetActionText(index);
			if (macroName) then
				actionData.macro = macroName;
			else
				ANDRGITMACRO_Tooltip:ClearLines();
				ANDRGITMACRO_Tooltip:SetAction(index);
				
				local left, right = getglobal(ANDRGITMACRO_TooltipName.."TextLeft1"), getglobal(ANDRGITMACRO_TooltipName.."TextRight1");
				if (left and spellBookData[left:GetText()]) then
					isASpell = true;
				end
				-- PickupAction(index);
				-- isASpell = CursorHasSpell();
				-- PlaceAction(index);

				if (isASpell) then
					spellName = nil;
					rank = nil;
					if (left:IsShown()) then
						spellName = left:GetText();
					end
					if (right:IsShown()) then
						rank = right:GetText();
					end
					actionData.spell = {
						name = spellName,
						rank = rank,
					};
				else
					itemName = nil;
					if (left:IsShown()) then
						itemName = left:GetText();
					end
					actionData.item = itemName;
				end

				local MAX_LINES = ANDRGITMACRO_Tooltip:NumLines();

				if (MAX_LINES > 0) then
					actionData.tooltipData = {};
					for line=1, MAX_LINES do
						local left = getglobal(ANDRGITMACRO_TooltipName .. "TextLeft" .. line)
						if left:GetText() then
							table.insert(actionData.tooltipData, left:GetText());
						end
					end
				end
			end

			if (spellName) then
				if (not data.spells[spellName]) then
					data.spells[spellName] = {};
				end
				table.insert(data.spells[spellName], {
					actionBarID = index,
					texture = texture,
					rank = rank,
					tooltipData = actionData.tooltipData;
				});
			elseif (macroName) then
				if (not data.macros[macroName]) then
					data.macros[macroName] = {};
				end
				table.insert(data.macros[macroName], {
					actionBarID = index,
					texture = texture,
					tooltipData = actionData.tooltipData;
				});
			elseif (itemName) then
				if (not data.items[itemName]) then
					data.items[itemName] = {};
				end
				table.insert(data.items[itemName], {
					actionBarID = index,
					texture = texture,
					tooltipData = actionData.tooltipData;
				});
			end
			
			data.actionBars[index] = actionData;
		end
	end

	lockedActionBarData = false;
	AndrgitMacro.cacheData.actionBarData = data;
	AndrgitMacro.needUpdate.actionBarData = false;
	return data;
end

function ANDRGITMACRO_GetSpellIndex(name)
	local spells = ANDRGITMACRO_GetSpellsBookData();
	for spell, data in pairs(spells) do
		if (spell == name) then
			return data[1].spellID;
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