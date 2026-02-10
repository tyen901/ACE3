#include "..\script_component.hpp"
#include "..\defines.hpp"
/*
 * Author: Alganthe, Dedmen, Brett Mayson, johnb43
 * Sort an arsenal panel.
 *
 * Arguments:
 * 0: Control <CONTROL>
 *
 * Return Value:
 * None
 *
 * Public: No
*/

params ["_control"];

// https://community.bistudio.com/wiki/toString, see comment
// However, using 55295 did not work as expected, 55291 was found by trial and error
#define HIGHEST_VALUE_CHAR 55291

// When filling the sorting panel, FUNC(sortPanel) is called twice, so ignore first call
if (GVAR(ignoreFirstSortPanelCall)) exitWith {
    GVAR(ignoreFirstSortPanelCall) = false;
};

private _display = ctrlParent _control;
private _rightSort = (ctrlIDC _control) in [IDC_sortRightTab, IDC_sortRightTabDirection];
private _right = _rightSort && {GVAR(currentLeftPanel) in [IDC_buttonUniform, IDC_buttonVest, IDC_buttonBackpack]};
private _sortCtrl = _display displayCtrl ([IDC_sortLeftTab, IDC_sortRightTab] select _rightSort);
private _sortDirectionCtrl = _display displayCtrl ([IDC_sortLeftTabDirection, IDC_sortRightTabDirection] select _rightSort);

private _cfgMagazines = configFile >> "CfgMagazines";
private _cfgFaces = configFile >> "CfgFaces";
private _cfgUnitInsignia = configFile >> "CfgUnitInsignia";
private _cfgUnitInsigniaCampaign = campaignConfigFile >> "CfgUnitInsignia";
private _cfgUnitInsigniaMission = missionConfigFile >> "CfgUnitInsignia";

if (_rightSort) then {
    [
        _display displayCtrl IDC_rightTabContent,
        switch (GVAR(currentRightPanel)) do {
            case IDC_buttonCurrentMag;
            case IDC_buttonCurrentMag2;
            case IDC_buttonThrow;
            case IDC_buttonPut;
            case IDC_buttonMag;
            case IDC_buttonMagALL: {_cfgMagazines};
            default {configFile >> "CfgWeapons"};
        },
        GVAR(sortListRightPanel) select (
            switch (GVAR(currentRightPanel)) do {
                case IDC_buttonOptic: { 0 };
                case IDC_buttonItemAcc: { 1 };
                case IDC_buttonMuzzle: { 2 };
                case IDC_buttonBipod: { 3 };
                case IDC_buttonCurrentMag;
                case IDC_buttonCurrentMag2;
                case IDC_buttonMag;
                case IDC_buttonMagALL: { 4 };
                case IDC_buttonThrow: { 5 };
                case IDC_buttonPut: { 6 };
                case IDC_buttonMisc: { 7 };
            }
        )
    ]
} else {
    [
        _display displayCtrl IDC_leftTabContent,
        switch (GVAR(currentLeftPanel)) do {
            case IDC_buttonBackpack: {configFile >> "CfgVehicles"};
            case IDC_buttonGoggles: {configFile >> "CfgGlasses"};
            case IDC_buttonFace: {_cfgFaces};
            case IDC_buttonVoice: {configFile >> "CfgVoice"};
            case IDC_buttonInsignia: {_cfgUnitInsignia};
            default {configFile >> "CfgWeapons"};
        },
        (GVAR(sortListLeftPanel) select ([
            IDC_buttonPrimaryWeapon,
            IDC_buttonHandgun,
            IDC_buttonSecondaryWeapon,
            IDC_buttonUniform,
            IDC_buttonVest,
            IDC_buttonBackpack,
            IDC_buttonHeadgear,
            IDC_buttonGoggles,
            IDC_buttonNVG,
            IDC_buttonBinoculars,
            IDC_buttonMap,
            IDC_buttonGPS,
            IDC_buttonRadio,
            IDC_buttonCompass,
            IDC_buttonWatch,
            IDC_buttonFace,
            IDC_buttonVoice,
            IDC_buttonInsignia
        ] find GVAR(currentLeftPanel)))
    ]
} params ["_panel", "_cfgClass", "_sorts"];

// Get sort & sort direction
private _sortName = _sortCtrl lbData (0 max lbCurSel _sortCtrl);
private _sortDirection = _sortDirectionCtrl lbValue (0 max lbCurSel _sortDirectionCtrl);
(_sorts select (0 max (_sorts findIf {(_x select 0) == _sortName}))) params ["", "_displayName", "_statement"];

// Update last sort & sort direction
missionNamespace setVariable [
    [QGVAR(lastSortLeft), QGVAR(lastSortRight)] select _rightSort,
    _displayName
];

missionNamespace setVariable [
    [QGVAR(lastSortDirectionLeft), QGVAR(lastSortDirectionRight)] select _rightSort,
    _sortDirection
];

// Get currently selected item
(["getSelectedLeaf", [_panel]] call FUNC(treeControlInterface)) params ["", "_selected"];

private _itemCfg = configNull;
private _value = "";
private _fillerChar = toString [1];

private _magazineMiscItems = uiNamespace getVariable QGVAR(magazineMiscItems);
private _sortCache = uiNamespace getVariable QGVAR(sortCache);
private _faceCache = uiNamespace getVariable QGVAR(faceCache);
private _insigniaCache = uiNamespace getVariable QGVAR(insigniaCache);
private _displayNameCache = uiNamespace getVariable [QGVAR(treeOriginalDisplayNameCache), createHashMap];

private _emptyEntries = [];
private _groupEntries = [];

// Build a transient representation of the tree
for "_groupIndex" from 0 to ((_panel tvCount []) - 1) do {
    private _groupPath = [_groupIndex];

    if (["isGroupPath", [_panel, _groupPath]] call FUNC(treeControlInterface)) then {
        private _groupLabel = _panel tvText _groupPath;
        private _leaves = [];

        for "_leafIndex" from 0 to ((_panel tvCount _groupPath) - 1) do {
            private _path = _groupPath + [_leafIndex];
            _leaves pushBack [
                _panel tvData _path,
                _panel tvText _path,
                _panel tvPicture _path,
                _panel tvTooltip _path,
                [[1, 1, 1, 1], FAVORITES_COLOR] select ((toLowerANSI (_panel tvData _path)) in GVAR(favorites)),
                _panel tvValue _path,
                ""
            ];
        };

        _groupEntries pushBack [_groupLabel, _leaves];
    } else {
        _emptyEntries pushBack [
            _panel tvData _groupPath,
            _panel tvText _groupPath,
            _panel tvPicture _groupPath,
            _panel tvTooltip _groupPath,
            [1, 1, 1, 1],
            _panel tvValue _groupPath
        ];
    };
};

{
    _x params ["_groupLabel", "_leaves"];

    {
        _x params ["_item", "_nodeText", "", "", "", "_nodeValue"];

        // Get item and item's count
        private _quantity = [0, _nodeValue] select _right;

        // "Misc. items" magazines (e.g. spare barrels, intel, photos)
        private _itemCfgClass = _cfgClass;
        if (_item in _magazineMiscItems) then {
            _itemCfgClass = _cfgMagazines;
        };

        // Check item's config
        _itemCfg = if !(_itemCfgClass in [_cfgFaces, _cfgUnitInsignia]) then {
            _itemCfgClass >> _item
        } else {
            // If insignia, check for correct config: First mission, then campaign and finally regular config
            if (_itemCfgClass == _cfgUnitInsignia) then {
                _itemCfg = _cfgUnitInsigniaMission >> _item;

                if (isNull _itemCfg) then {
                    _itemCfg = _cfgUnitInsigniaCampaign >> _item;
                };

                if (isNull _itemCfg) then {
                    _itemCfg = _cfgUnitInsignia >> _item;
                };

                _itemCfg
            } else {
                // If face, check correct category
                _itemCfgClass >> (_faceCache getOrDefault [_item, []]) param [2, "Man_A3"] >> _item
            };
        };

        // Some items may not belong to the config class for the panel (e.g. misc. items panel can have unique items)
        if (isNull _itemCfg) then {
            _itemCfg = _item call CBA_fnc_getItemConfig;
        };

        // Value can be any type
        _value = _sortCache getOrDefaultCall [format ["%1_%2_%3", _sortName, _item, _quantity], {
            private _value = [_itemCfg, _item, _quantity] call _statement;

            // If number, convert to string (keep 2 decimal after comma; Needed for correct weight sorting)
            if (_value isEqualType 0) then {
                _value = [_value, 8, 2] call CBA_fnc_formatNumber;
            };

            // If empty string, add alphabetically small char at beginning to make it sort correctly
            if (_value isEqualTo "") then {
                _value = "_";
            };

            _value
        }, true];

        // Set the sort key temporarily, so it can be used for sorting
        private _displayNameForSort = _nodeText;
        if (_right) then {
            private _cacheKey = format ["%1|%2", GVAR(currentRightPanel), toLowerANSI _item];
            _displayNameForSort = _displayNameCache getOrDefault [_cacheKey, _nodeText];
        };

        // Use value, display name and classname to sort, which means a fixed alphabetical order is guaranteed
        // Filler char has lowest lexicographical value possible
        _x set [6, format ["%1%2%4%3", _value, _displayNameForSort, _item, _fillerChar]];
    } forEach _leaves;

    _leaves sort (_sortDirection == ASCENDING);
} forEach _groupEntries;

// Sort alphabetically, rebuild tree, and select the previously selected item again
_groupEntries sort true;

tvClear _panel;

{
    _x params ["_item", "_text", "_picture", "_tooltip", "_color", "_nodeValue"];

    private _path = [_panel tvAdd [[], _text]];
    _panel tvSetData [_path, _item];
    _panel tvSetValue [_path, _nodeValue];
    _panel tvSetTooltip [_path, _tooltip];

    if (_picture != "") then {
        _panel tvSetPicture [_path, _picture];
    };

    if (_color isNotEqualTo []) then {
        _panel tvSetColor [_path, _color];
    };
} forEach _emptyEntries;

{
    _x params ["_groupLabel", "_leaves"];

    private _groupIndex = _panel tvAdd [[], _groupLabel];
    private _groupPath = [_groupIndex];

    _panel tvSetData [_groupPath, "GROUP:" + _groupLabel];
    _panel tvSetValue [_groupPath, -1];

    {
        _x params ["_item", "_text", "_picture", "_tooltip", "_color", "_nodeValue"];

        private _leafPath = _groupPath + [_panel tvAdd [_groupPath, _text]];
        _panel tvSetData [_leafPath, _item];
        _panel tvSetValue [_leafPath, _nodeValue];
        _panel tvSetTooltip [_leafPath, _tooltip];

        if (_picture != "") then {
            _panel tvSetPicture [_leafPath, _picture];
        };

        if (_color isNotEqualTo []) then {
            _panel tvSetColor [_leafPath, _color];
        };
    } forEach _leaves;

    _panel tvExpand _groupPath;
} forEach _groupEntries;

if (_selected != "") then {
    private _selectedPath = ["findLeafPathByData", [_panel, _selected]] call FUNC(treeControlInterface);
    if (_selectedPath isNotEqualTo []) then {
        _panel tvSetCurSel _selectedPath;
    };
} else {
    private _selectedPath = ["findLeafPathByData", [_panel, ""]] call FUNC(treeControlInterface);
    if (_selectedPath isNotEqualTo []) then {
        _panel tvSetCurSel _selectedPath;
    };
};

if (_rightSort && {_right}) then {
    private _container = switch (GVAR(currentLeftPanel)) do {
        case IDC_buttonUniform: {uniformContainer GVAR(center)};
        case IDC_buttonVest: {vestContainer GVAR(center)};
        case IDC_buttonBackpack: {backpackContainer GVAR(center)};
    };

    private _hasItems = switch (GVAR(currentLeftPanel)) do {
        case IDC_buttonUniform: {(GVAR(currentItems) select IDX_CURR_UNIFORM_ITEMS) isNotEqualTo []};
        case IDC_buttonVest: {(GVAR(currentItems) select IDX_CURR_VEST_ITEMS) isNotEqualTo []};
        case IDC_buttonBackpack: {(GVAR(currentItems) select IDX_CURR_BACKPACK_ITEMS) isNotEqualTo []};
    };

    [_panel, _container, _hasItems] call FUNC(updateRightPanel);
};
