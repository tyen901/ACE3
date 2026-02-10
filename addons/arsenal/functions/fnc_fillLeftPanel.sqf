#include "..\script_component.hpp"
#include "..\defines.hpp"
/*
 * Author: Alganthe, johnb43, LinkIsGrim
 * Fills left panel.
 *
 * Arguments:
 * 0: Arsenal display <DISPLAY>
 * 1: Tab control <CONTROL>
 * 2: Animate panel refresh <BOOL>
 *
 * Return Value:
 * None
 *
 * Public: No
*/

params ["_display", "_control", ["_animate", true]];

private _ctrlIDC = ctrlIDC _control;
private _ctrlPanel = _display displayCtrl IDC_leftTabContent;
private _idxVirt = GVAR(idxMap) getOrDefault [_ctrlIDC, -1, true];

// Fade old control background
if (!isNil QGVAR(currentLeftPanel)) then {
    private _previousCtrlBackground = _display displayCtrl (GVAR(currentLeftPanel) - 1);
    _previousCtrlBackground ctrlSetFade 1;
    _previousCtrlBackground ctrlCommit ([0, FADE_DELAY] select _animate);

    // When switching tabs, clear searchbox
    if (GVAR(currentLeftPanel) != _ctrlIDC) then {
        (_display displayCtrl IDC_leftSearchbar) ctrlSetText "";
        (_display displayCtrl IDC_rightSearchbar) ctrlSetText "";
    };
};

// Show new control background
private _ctrlBackground = _display displayCtrl (_ctrlIDC - 1);
_ctrlBackground ctrlSetFade 0;
_ctrlBackground ctrlCommit ([0, FADE_DELAY] select _animate);

// Force a "refresh" animation of the panel
if (_animate) then {
    _ctrlPanel ctrlSetFade 1;
    _ctrlPanel ctrlCommit 0;
    _ctrlPanel ctrlSetFade 0;
    _ctrlPanel ctrlCommit FADE_DELAY;
};

private _selectedItem = "";
if (_idxVirt != -1) then {
    _selectedItem = GVAR(currentItems) select _idxVirt;
};

// Purge old data
// For every left tab except faces and voices, add "Empty" entry
private _entries = [];
if !(_ctrlIDC in [IDC_buttonFace, IDC_buttonVoice]) then {
    _entries pushBack ["", format [" <%1>", localize "str_empty"], "", "", [], -1];
};

private _fnc_shouldInclude = {
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

private _fnc_createEntry = {
    params ["_configCategory", "_className", ["_pictureEntryName", "picture", [""]], ["_configRoot", 0, [0]], ["_forcedDisplayName", "", [""]], ["_forcedPicture", "", [""]]];

    if !([_className] call _fnc_shouldInclude) exitWith {[]};

    private _key = _configCategory + _className + str _configRoot;

    ((uiNamespace getVariable QGVAR(addListBoxItemCache)) getOrDefaultCall [_key, {
        private _configPath = ([configFile, campaignConfigFile, missionConfigFile] select _configRoot) >> _configCategory >> _className;

        [
            configName _configPath,
            [getText (_configPath >> "displayName"), _forcedDisplayName] select (_forcedDisplayName != ""),
            [if (_pictureEntryName == "") then {""} else {getText (_configPath >> _pictureEntryName)}, _forcedPicture] select (_forcedPicture != "")
        ]
    }, true]) params ["_cfgClass", "_displayName", "_picture"];

    if (_cfgClass == "") exitWith {[]};

    private _color = [];
    if ((toLowerANSI _cfgClass) in GVAR(favorites)) then {
        _color = FAVORITES_COLOR;
    };

    [_cfgClass, _displayName, _picture, format ["%1\n%2", _displayName, _cfgClass], _color, 0]
};

// Don't reset the current right panel for weapons, binos and containers
if !(_idxVirt in [IDX_VIRT_PRIMARY_WEAPONS, IDX_VIRT_SECONDARY_WEAPONS, IDX_VIRT_HANDGUN_WEAPONS, IDX_VIRT_BINO, IDX_VIRT_UNIFORM, IDX_VIRT_VEST, IDX_VIRT_BACKPACK]) then {
    GVAR(currentRightPanel) = nil;
};
GVAR(currentLeftPanel) = _ctrlIDC;

private _originalNameCache = uiNamespace getVariable [QGVAR(treeOriginalDisplayNameCache), createHashMap];

// Add items to the listbox/tree
if (_idxVirt != -1) then {
    private _configParent = switch (_idxVirt) do {
        case IDX_VIRT_GOGGLES: {"CfgGlasses"};
        case IDX_VIRT_BACKPACK: {"CfgVehicles"};
        default {"CfgWeapons"};
    };

    private _items = if (_idxVirt < IDX_VIRT_HEADGEAR) then {
        keys ((GVAR(virtualItems) get IDX_VIRT_WEAPONS) get _idxVirt)
    } else {
        keys (GVAR(virtualItems) get _idxVirt)
    };

    {
        private _entry = [_configParent, _x] call _fnc_createEntry;
        if (_entry isEqualTo []) then { continue; };

        _entries pushBack _entry;
        _originalNameCache set [format ["%1|%2", IDC_leftTabContent, toLowerANSI (_entry select 0)], _entry select 1];
    } forEach _items;
} else {
    switch (_ctrlIDC) do {
        // Faces
        case IDC_buttonFace: {
            {
                _y params ["_displayName", "_modPicture"];
                // Faces need to be added like this because their config path is
                // configFile >> "CfgFaces" >> face category >> className
                if !([_x] call _fnc_shouldInclude) then { continue; };

                private _entry = [_x, _displayName, _modPicture, format ["%1\n%2", _displayName, _x], [], 0];
                _entries pushBack _entry;
                _originalNameCache set [format ["%1|%2", IDC_leftTabContent, toLowerANSI (_entry select 0)], _entry select 1];
            } forEach GVAR(faceCache);

            _selectedItem = GVAR(currentFace);
        };
        // Voices
        case IDC_buttonVoice: {
            {
                private _entry = ["CfgVoice", _x, "icon"] call _fnc_createEntry;
                if (_entry isEqualTo []) then { continue; };

                _entries pushBack _entry;
                _originalNameCache set [format ["%1|%2", IDC_leftTabContent, toLowerANSI (_entry select 0)], _entry select 1];
            } forEach (keys GVAR(voiceCache));

            _selectedItem = GVAR(currentVoice);
        };
        // Insignia
        case IDC_buttonInsignia: {
            {
                private _entry = ["CfgUnitInsignia", _x, "texture", _y] call _fnc_createEntry;
                if (_entry isEqualTo []) then { continue; };

                _entries pushBack _entry;
                _originalNameCache set [format ["%1|%2", IDC_leftTabContent, toLowerANSI (_entry select 0)], _entry select 1];
            } forEach GVAR(insigniaCache);

            _selectedItem = GVAR(currentInsignia);
        };
        // Unknown
        default {
            WARNING_1("Unknown arsenal left panel with IDC %1, update ace_arsenal_idxMap and relevant macros if adding a new tab",_ctrlIDC);
            _selectedItem = "";
        };
    };
};

uiNamespace setVariable [QGVAR(treeOriginalDisplayNameCache), _originalNameCache];

[_ctrlPanel, _entries] call FUNC(fillLeftPanelGrouped);

// Trigger event
[QGVAR(leftPanelFilled), [_display, _ctrlIDC, GVAR(currentRightPanel)]] call CBA_fnc_localEvent;

// Sort
[_display, _control, _display displayCtrl IDC_sortLeftTab, _display displayCtrl IDC_sortLeftTabDirection] call FUNC(fillSort);

// Try to select previously selected item again, otherwise select first item ("Empty")
private _targetPath = [];
if (_selectedItem != "") then {
    _targetPath = ["findLeafPathByData", [_ctrlPanel, _selectedItem]] call FUNC(treeControlInterface);
};

if (_targetPath isEqualTo []) then {
    _targetPath = ["findLeafPathByData", [_ctrlPanel, ""]] call FUNC(treeControlInterface);
};

if (_targetPath isEqualTo []) then {
    private _leafPaths = ["collectLeafPaths", [_ctrlPanel, true]] call FUNC(treeControlInterface);
    _targetPath = _leafPaths param [0, []];
};

if (_targetPath isNotEqualTo []) then {
    _ctrlPanel tvSetCurSel _targetPath;
};
