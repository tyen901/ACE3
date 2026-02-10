#include "..\script_component.hpp"
#include "..\defines.hpp"
/*
 * Author: Alganthe, johnb43
 * Fills right panel.
 *
 * Arguments:
 * 0: Arsenal display <DISPLAY>
 * 1: Tab control <CONTROL>
 * 2: Animate panel refresh <BOOL> (default: true)
 *
 * Return Value:
 * None
 *
 * Public: No
*/

params ["_display", "_control", ["_animate", true]];

// Fade old control background
if (!isNil QGVAR(currentRightPanel)) then {
    private _previousCtrlBackground = _display displayCtrl (GVAR(currentRightPanel) - 1);
    _previousCtrlBackground ctrlSetFade 1;
    _previousCtrlBackground ctrlCommit ([0, FADE_DELAY] select _animate);
};

// Show new control background
private _ctrlIDC = ctrlIDC _control;
private _ctrlBackground = _display displayCtrl (_ctrlIDC - 1);
_ctrlBackground ctrlShow true;
_ctrlBackground ctrlSetFade 0;
_ctrlBackground ctrlCommit ([0, FADE_DELAY] select _animate);

private _searchbarCtrl = _display displayCtrl IDC_rightSearchbar;

// Show right search bar
if (!(ctrlShown _searchbarCtrl) || {ctrlFade _searchbarCtrl > 0}) then {
    _searchbarCtrl ctrlShow true;
    _searchbarCtrl ctrlSetFade 0;
    _searchbarCtrl ctrlCommit 0;
};

private _ctrlPanel = _display displayCtrl IDC_rightTabContent;
private _cfgMagazines = configFile >> "CfgMagazines";
private _rightPanelCache = uiNamespace getVariable QGVAR(rightPanelCache);
private _originalNameCache = uiNamespace getVariable [QGVAR(treeOriginalDisplayNameCache), createHashMap];
private _rightMetaCache = uiNamespace getVariable [QGVAR(treeRightItemMetaCache), createHashMap];

private _entries = [];
private _isContainer = false;
private _selectedItem = "";

(["getSelectedLeaf", [_ctrlPanel]] call FUNC(treeControlInterface)) params ["", "_selectedItem"];

private _currentCargo = [];
if (GVAR(favoritesOnly)) then {
    _currentCargo = itemsWithMagazines GVAR(center) + backpacks GVAR(center);
    _currentCargo = _currentCargo arrayIntersect _currentCargo;
};

private _fnc_shouldIncludeWeapon = {
    params ["_className"];

    private _skip = GVAR(favoritesOnly) && {!(_className in GVAR(currentItems))} && {!((toLowerANSI _className) in GVAR(favorites))};
    if (_skip) then {
        switch (GVAR(currentLeftPanel)) do {
            case IDC_buttonPrimaryWeapon: {
                _skip = !(_className in (GVAR(currentItems) select IDX_CURR_PRIMARY_WEAPON_ITEMS));
            };
            case IDC_buttonHandgun: {
                _skip = !(_className in (GVAR(currentItems) select IDX_CURR_HANDGUN_WEAPON_ITEMS));
            };
            case IDC_buttonSecondaryWeapon: {
                _skip = !(_className in (GVAR(currentItems) select IDX_CURR_PRIMARY_WEAPON_ITEMS));
            };
            case IDC_buttonBinoculars: {
                _skip = !(_className in (GVAR(currentItems) select IDX_CURR_BINO_ITEMS));
            };
        };
    };

    !_skip
};

private _fnc_pushEntry = {
    params [
        ["_className", "", [""]],
        ["_displayName", "", [""]],
        ["_picture", "", [""]],
        ["_tooltip", "", [""]],
        ["_isUnique", false, [false]],
        ["_quantity", 0, [0]],
        ["_baseDisplayName", "", [""]],
        ["_color", [], [[]]]
    ];

    _entries pushBack [_className, _displayName, _picture, _tooltip, _color, _quantity];

    if (_className != "") then {
        private _cacheKey = format ["%1|%2", _ctrlIDC, toLowerANSI _className];
        _originalNameCache set [_cacheKey, [_baseDisplayName, _displayName] select (_baseDisplayName == "")];
        _rightMetaCache set [_cacheKey, [_isUnique]];
    };
};

private _fnc_createWeaponEntry = {
    params ["_configCategory", "_className", ["_pictureEntryName", "picture", [""]]];

    if !([_className] call _fnc_shouldIncludeWeapon) exitWith {};

    private _key = _configCategory + _className;

    (_rightPanelCache getOrDefaultCall [_key, {
        private _configPath = configFile >> _configCategory >> _className;

        [configName _configPath, getText (_configPath >> "displayName"), getText (_configPath >> _pictureEntryName)]
    }, true]) params ["_cfgClass", "_displayName", "_picture"];

    if (_cfgClass == "") exitWith {};

    private _color = [];
    if ((toLowerANSI _cfgClass) in GVAR(favorites)) then {
        _color = FAVORITES_COLOR;
    };

    [_cfgClass, _displayName, _picture, format ["%1\n%2", _displayName, _cfgClass], false, 0, _displayName, _color] call _fnc_pushEntry;
};

private _fnc_fillRightContainer = {
    params ["_configCategory", "_className", ["_isUnique", false, [false]], ["_unknownOrigin", false, [false]]];

    if (GVAR(favoritesOnly) && {!(_className in _currentCargo)} && {!((toLowerANSI _className) in GVAR(favorites))}) exitWith {};

    // If item is not in the arsenal, it must be unique
    if (!_isUnique && {!(_className in GVAR(virtualItemsFlat))}) then {
        _isUnique = true;
    };

    (_rightPanelCache getOrDefaultCall [_configCategory + _className, {
        private _configPath = configFile >> _configCategory >> _className;

        // "Misc. items" magazines (e.g. spare barrels, intel, photos)
        if (_className in (uiNamespace getVariable QGVAR(magazineMiscItems))) then {
            _configPath = _cfgMagazines >> _className;
        };

        // If an item with unknown origin is in the arsenal list, try to find it
        if (_unknownOrigin && {isNull _configPath}) then {
            _configPath = _className call CBA_fnc_getItemConfig;

            if (isNull _configPath) then {
                _configPath = _className call CBA_fnc_getObjectConfig;
            };
        };

        [getText (_configPath >> "displayName"), getText (_configPath >> "picture")]
    }, true]) params ["_displayName", "_picture"];

    private _color = [];
    if ((toLowerANSI _className) in GVAR(favorites)) then {
        _color = FAVORITES_COLOR;
    };

    [_className, _displayName, _picture, format ["%1\n%2", _displayName, _className], _isUnique, 0, _displayName, _color] call _fnc_pushEntry;
};

// Retrieve compatible items
private _container = objNull;
private _containerItems = [];
private _compatibleItems = [];
private _compatibleMagsMuzzle = [];
private _compatibleMagsAll = createHashMap;

switch (GVAR(currentLeftPanel)) do {
    // If weapons or binoculars are chosen, get their compatible magazines & items
    // Weapons and binoculars
    case IDC_buttonPrimaryWeapon;
    case IDC_buttonHandgun;
    case IDC_buttonSecondaryWeapon;
    case IDC_buttonBinoculars: {
        (switch (GVAR(currentLeftPanel)) do {
            case IDC_buttonPrimaryWeapon: {
                [IDX_CURR_PRIMARY_WEAPON, IDX_CURR_PRIMARY_WEAPON_ITEMS]
            };
            case IDC_buttonHandgun: {
                [IDX_CURR_HANDGUN_WEAPON, IDX_CURR_HANDGUN_WEAPON_ITEMS]
            };
            case IDC_buttonSecondaryWeapon: {
                [IDX_CURR_SECONDARY_WEAPON, IDX_CURR_SECONDARY_WEAPON_ITEMS]
            };
            case IDC_buttonBinoculars: {
                [IDX_CURR_BINO, IDX_CURR_BINO_ITEMS]
            };
        }) params ["_currentWeaponIndex", "_currentWeaponItemsIndex"];

        private _index = [IDC_buttonMuzzle, IDC_buttonItemAcc, IDC_buttonOptic, IDC_buttonBipod, IDC_buttonCurrentMag, IDC_buttonCurrentMag2] find _ctrlIDC;
        private _weapon = GVAR(currentItems) select _currentWeaponIndex;

        // Check if weapon attachement or magazine
        if (_index != -1) then {
            _selectedItem = (GVAR(currentItems) select _currentWeaponItemsIndex) select _index;

            // If weapon attachment, get base weapon; Get compatible items
            if (_index <= 3) then {
                _compatibleItems = compatibleItems _weapon;
                _selectedItem = _selectedItem call FUNC(baseWeapon);
            } else {
                // Get compatible magazines for primary & secondary muzzle (secondary muzzle is not guaranteed to exist)
                // Assumption: One weapon can have two muzzles maximum
                _compatibleMagsMuzzle = compatibleMagazines [_weapon, (_weapon call CBA_fnc_getMuzzles) param [_index - 4, ""]];
            };
        };
    };
    case IDC_buttonUniform;
    case IDC_buttonVest;
    case IDC_buttonBackpack: {
        // Uniform, vest or backpack
        _isContainer = true;

        _container = switch (GVAR(currentLeftPanel)) do {
            // Uniform
            case IDC_buttonUniform: {
                // Update load bar
                // Get all items from container
                _containerItems = uniformItems GVAR(center);
                (_display displayCtrl IDC_loadIndicatorBar) progressSetPosition (loadUniform GVAR(center));
                uniformContainer GVAR(center)
            };
            // Vest
            case IDC_buttonVest: {
                // Update load bar
                // Get all items from container
                _containerItems = vestItems GVAR(center);
                (_display displayCtrl IDC_loadIndicatorBar) progressSetPosition (loadVest GVAR(center));
                vestContainer GVAR(center)
            };
            // Backpack
            case IDC_buttonBackpack: {
                // Update load bar
                // Get all items from container
                _containerItems = backpackItems GVAR(center);
                (_display displayCtrl IDC_loadIndicatorBar) progressSetPosition (loadBackpack GVAR(center));
                backpackContainer GVAR(center)
            };
        };

        if (_ctrlIDC == IDC_buttonMag) then {
            // This is for the "compatible magazines" tab when a container is open
            // Get all compatibles magazines with unit's weapons (including compatible magazines that aren't in configItems)
            {
                _compatibleMagsAll insert [true, compatibleMagazines _x, []];
            } forEach [
                GVAR(currentItems) select IDX_CURR_PRIMARY_WEAPON,
                GVAR(currentItems) select IDX_CURR_HANDGUN_WEAPON,
                GVAR(currentItems) select IDX_CURR_SECONDARY_WEAPON,
                GVAR(currentItems) select IDX_CURR_BINO
            ];
        };
    };
};

// Force a "refresh" animation of the panel
if (_animate) then {
    _ctrlPanel ctrlSetFade 1;
    _ctrlPanel ctrlCommit 0;
    _ctrlPanel ctrlSetFade 0;
    _ctrlPanel ctrlCommit FADE_DELAY;
};

private _leftPanelState = GVAR(currentLeftPanel) in [IDC_buttonPrimaryWeapon, IDC_buttonHandgun, IDC_buttonSecondaryWeapon, IDC_buttonBinoculars];

// Add an empty entry if left panel is a weapon or bino
if (_leftPanelState && {_ctrlIDC in [RIGHT_PANEL_ACC_IDCS, IDC_buttonCurrentMag, IDC_buttonCurrentMag2]}) then {
    _entries pushBack ["", format [" <%1>", localize "str_empty"], "", "", [], -1];
};

// Fill right panel according to category choice
switch (_ctrlIDC) do {
    // Optics, flashlights, muzzle attachments, bipods
    case IDC_buttonOptic;
    case IDC_buttonItemAcc;
    case IDC_buttonMuzzle;
    case IDC_buttonBipod: {
        private _index = [IDX_VIRT_OPTICS_ATTACHMENTS, IDX_VIRT_FLASHLIGHT_ATTACHMENTS, IDX_VIRT_MUZZLE_ATTACHMENTS, IDX_VIRT_BIPOD_ATTACHMENTS] select ([RIGHT_PANEL_ACC_IDCS] find _ctrlIDC);

        if (_leftPanelState) then {
            {
                if (_x in ((GVAR(virtualItems) get IDX_VIRT_ATTACHMENTS) get _index)) then {
                    ["CfgWeapons", _x] call _fnc_createWeaponEntry;
                };
            } forEach _compatibleItems;
        } else {
            {
                ["CfgWeapons", _x] call _fnc_fillRightContainer;
            } forEach (keys ((GVAR(virtualItems) get IDX_VIRT_ATTACHMENTS) get _index));

            {
                ["CfgWeapons", _x, true] call _fnc_fillRightContainer;
            } forEach (keys ((GVAR(virtualItems) get IDX_VIRT_UNIQUE_ATTACHMENTS) get _index));
        };
    };
    case IDC_buttonCurrentMag;
    case IDC_buttonCurrentMag2: {
        // Current primary & secondary muzzle compatible magazines
        if (_leftPanelState) then {
            {
                if (_x in (GVAR(virtualItems) get IDX_VIRT_ITEMS_ALL)) then {
                    ["CfgMagazines", _x] call _fnc_createWeaponEntry;
                };
            } forEach _compatibleMagsMuzzle;
        };
    };
    // All compatible magazines
    case IDC_buttonMag: {
        {
            if (_x in (GVAR(virtualItems) get IDX_VIRT_ITEMS_ALL)) then {
                ["CfgMagazines", _x] call _fnc_fillRightContainer;
                continue;
            };

            if (_x in (GVAR(virtualItems) get IDX_VIRT_UNIQUE_VIRT_ITEMS_ALL)) then {
                ["CfgMagazines", _x, true] call _fnc_fillRightContainer;
            };
        } forEach (keys _compatibleMagsAll);
    };
    // All magazines
    case IDC_buttonMagALL: {
        {
            ["CfgMagazines", _x] call _fnc_fillRightContainer;
        } forEach (keys (GVAR(virtualItems) get IDX_VIRT_ITEMS_ALL));

        {
            ["CfgMagazines", _x, true] call _fnc_fillRightContainer;
        } forEach (keys (GVAR(virtualItems) get IDX_VIRT_UNIQUE_VIRT_ITEMS_ALL));
    };
    // Grenades
    case IDC_buttonThrow: {
        {
            ["CfgMagazines", _x] call _fnc_fillRightContainer;
        } forEach (keys (GVAR(virtualItems) get IDX_VIRT_GRENADES));

        {
            ["CfgMagazines", _x, true] call _fnc_fillRightContainer;
        } forEach (keys (GVAR(virtualItems) get IDX_VIRT_UNIQUE_GRENADES));
    };
    // Explosives
    case IDC_buttonPut: {
        {
            ["CfgMagazines", _x] call _fnc_fillRightContainer;
        } forEach (keys (GVAR(virtualItems) get IDX_VIRT_EXPLOSIVES));

        {
            ["CfgMagazines", _x, true] call _fnc_fillRightContainer;
        } forEach (keys (GVAR(virtualItems) get IDX_VIRT_UNIQUE_EXPLOSIVES));
    };
    // Misc. items
    case IDC_buttonMisc: {
        // Don't add items that will be in a custom right panel button
        private _items = createHashMap;

        if (!isNil QGVAR(customRightPanelButtons)) then {
            {
                if (!isNil "_x") then {
                    _items insert [true, _x select 0, []];
                };
            } forEach GVAR(customRightPanelButtons);
        };

        // "Regular" misc. items
        {
            if !(_x in _items) then {
                ["CfgWeapons", _x] call _fnc_fillRightContainer;
            };
        } forEach (keys (GVAR(virtualItems) get IDX_VIRT_MISC_ITEMS));
        // Unique items
        {
            if !(_x in _items) then {
                ["CfgWeapons", _x, true] call _fnc_fillRightContainer;
            };
        } forEach (keys (GVAR(virtualItems) get IDX_VIRT_UNIQUE_MISC_ITEMS));
        // Unique backpacks
        {
            if !(_x in _items) then {
                ["CfgVehicles", _x, true] call _fnc_fillRightContainer;
            };
        } forEach (keys (GVAR(virtualItems) get IDX_VIRT_UNIQUE_BACKPACKS));
        // Unique goggles
        {
            if !(_x in _items) then {
                // _y indicates if an item is truly unique or if it's a non-inventory item in a container (e.g. goggles in backpack)
                ["CfgGlasses", _x, _y] call _fnc_fillRightContainer;
            };
        } forEach (GVAR(virtualItems) get IDX_VIRT_UNIQUE_GOGGLES);
        // Unknown items
        {
            if !(_x in _items) then {
                // _y indicates if an item is truly unique or if it's a non-inventory item in a container (e.g. helmet in backpack)
                ["CfgWeapons", _x, _y, true] call _fnc_fillRightContainer;
            };
        } forEach (GVAR(virtualItems) get IDX_VIRT_UNIQUE_UNKNOWN_ITEMS);
    };
    // Custom buttons
    default {
        private _items = (GVAR(customRightPanelButtons) param [[RIGHT_PANEL_CUSTOM_BUTTONS] find _ctrlIDC, []]) param [0, []];

        if (_items isNotEqualTo []) then {
            {
                switch (true) do {
                    // "Regular" misc. items
                    case (_x in (GVAR(virtualItems) get IDX_VIRT_MISC_ITEMS)): {
                        ["CfgWeapons", _x] call _fnc_fillRightContainer;
                    };
                    // Unique items
                    case (_x in (GVAR(virtualItems) get IDX_VIRT_UNIQUE_MISC_ITEMS)): {
                        ["CfgWeapons", _x, true] call _fnc_fillRightContainer;
                    };
                    // Unique backpacks
                    case (_x in (GVAR(virtualItems) get IDX_VIRT_UNIQUE_BACKPACKS)): {
                        ["CfgVehicles", _x, true] call _fnc_fillRightContainer;
                    };
                    // Unique goggles
                    case (_x in (GVAR(virtualItems) get IDX_VIRT_UNIQUE_GOGGLES)): {
                        ["CfgGlasses", _x, GVAR(virtualItems) get IDX_VIRT_UNIQUE_GOGGLES get _x] call _fnc_fillRightContainer;
                    };
                    // Unknown items
                    case (_x in (GVAR(virtualItems) get IDX_VIRT_UNIQUE_UNKNOWN_ITEMS)): {
                        ["CfgWeapons", _x, GVAR(virtualItems) get IDX_VIRT_UNIQUE_UNKNOWN_ITEMS get _x, true] call _fnc_fillRightContainer;
                    };
                };
            } forEach _items;
        };
    };
};

if (_isContainer) then {
    private _countMap = createHashMap;
    {
        _countMap set [_x, (_countMap getOrDefault [_x, 0]) + 1];
    } forEach _containerItems;

    {
        _x params ["_className", "_displayName", "", "", "", ["_quantity", 0]];
        if (_className == "") then { continue; };

        _quantity = _countMap getOrDefault [_className, 0];
        _x set [1, format ["%1 (x%2)", _displayName, _quantity]];
        _x set [5, _quantity];
        _entries set [_forEachIndex, _x];
    } forEach _entries;
};

private _groupByMode = missionNamespace getVariable [QGVAR(lastGroupByRightMode), GROUP_BY_OFF];
[_ctrlPanel, _entries, true, _groupByMode] call FUNC(fillLeftPanelGrouped);

// When switching tabs, clear searchbox
if (GVAR(currentRightPanel) != _ctrlIDC) then {
    (_display displayCtrl IDC_rightSearchbar) ctrlSetText "";
};

GVAR(currentRightPanel) = _ctrlIDC;
uiNamespace setVariable [QGVAR(treeOriginalDisplayNameCache), _originalNameCache];
uiNamespace setVariable [QGVAR(treeRightItemMetaCache), _rightMetaCache];
[_display, _display displayCtrl IDC_groupRightTab] call FUNC(fillGroupBy);

// Trigger event
[QGVAR(rightPanelFilled), [_display, GVAR(currentLeftPanel), _ctrlIDC]] call CBA_fnc_localEvent;

// Sorting
[_display, _control, _display displayCtrl IDC_sortRightTab, _display displayCtrl IDC_sortRightTabDirection] call FUNC(fillSort);

if (_selectedItem != "") then {
    private _path = ["findLeafPathByData", [_ctrlPanel, _selectedItem]] call FUNC(treeControlInterface);
    if (_path isNotEqualTo []) then {
        _ctrlPanel tvSetCurSel _path;
    };
    } else {
    if (!_isContainer) then {
        private _path = ["findLeafPathByData", [_ctrlPanel, ""]] call FUNC(treeControlInterface);
        if (_path isEqualTo []) then {
            private _leafPaths = ["collectLeafPaths", [_ctrlPanel, true]] call FUNC(treeControlInterface);
            _path = _leafPaths param [0, []];
        };
        if (_path isNotEqualTo []) then {
            _ctrlPanel tvSetCurSel _path;
    };
    };
};

    if (_isContainer) then {
    [_ctrlPanel, _container, _containerItems isNotEqualTo []] call FUNC(updateRightPanel);
};
