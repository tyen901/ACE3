#include "..\script_component.hpp"
#include "..\defines.hpp"
/*
 * Author: Tyen, ACE3 Team
 * Fill an Arsenal tree panel using selected grouping mode.
 *
 * Arguments:
 * 0: Tree control <CONTROL>
 * 1: Entries <ARRAY>
 *  - Entry format: [className, displayName, picture, tooltip, color, value]
 * 2: Expand groups <BOOL> (default: true)
 * 3: Group mode <NUMBER> (default: GROUP_BY_FIRST_LETTER)
 *
 * Return Value:
 * None
 *
 * Public: No
 */

params [
    "_control",
    ["_entries", [], [[]]],
    ["_expandGroups", true, [true]],
    ["_groupByMode", GROUP_BY_FIRST_LETTER, [0]]
];

tvClear _control;
private _groupPaths = createHashMap;
private _groupNameCache = uiNamespace getVariable [QGVAR(treeGroupNameCache), createHashMap];

private _fnc_addTopLevelLeaf = {
    params [
        "_control",
        ["_className", "", [""]],
        ["_displayName", "", [""]],
        ["_picture", "", [""]],
        ["_tooltip", "", [""]],
        ["_color", [], [[]]],
        ["_value", 0, [0]]
    ];

    private _path = [_control tvAdd [[], _displayName]];
    _control tvSetData [_path, _className];
    _control tvSetValue [_path, _value];
    _control tvSetTooltip [_path, _tooltip];

    if (_picture != "") then {
        _control tvSetPicture [_path, _picture];
    };

    if (_color isNotEqualTo []) then {
        _control tvSetColor [_path, _color];
    };

    _path
};

private _fnc_getModGroupKey = {
    params ["_className"];

    if (_className == "") exitWith {"#"};

    _groupNameCache getOrDefaultCall [toLowerANSI _className, {
        private _configPath = _className call CBA_fnc_getItemConfig;

        if (isNull _configPath) then {
            _configPath = _className call CBA_fnc_getObjectConfig;
        };

        if (isNull _configPath) then {
            {
                private _candidate = configFile >> _x >> _className;
                if (isClass _candidate) exitWith {
                    _configPath = _candidate;
                };
            } forEach ["CfgWeapons", "CfgMagazines", "CfgVehicles", "CfgGlasses", "CfgVoice", "CfgUnitInsignia"];
        };

        private _groupName = "#";
        if !(isNull _configPath) then {
            _groupName = [_configPath] call FUNC(sortStatement_mod);
        };

        if (_groupName == "") then {
            _groupName = "#";
        };

        _groupName
    }, true]
};

{
    _x params [
        ["_className", "", [""]],
        ["_displayName", "", [""]],
        ["_picture", "", [""]],
        ["_tooltip", "", [""]],
        ["_color", [], [[]]],
        ["_value", 0, [0]]
    ];

    if (_className == "" || {_groupByMode == GROUP_BY_OFF}) then {
        [_control, _className, _displayName, _picture, _tooltip, _color, _value] call _fnc_addTopLevelLeaf;
        continue;
    };

    private _groupKey = switch (_groupByMode) do {
        case GROUP_BY_MOD: {
            [_className] call _fnc_getModGroupKey
        };
        default {
            ["groupKey", [_displayName]] call FUNC(treeControlInterface)
        };
    };

    private _path = ["addLeaf", [_control, _groupKey, _className, _displayName, _picture, _tooltip, _value, _color]] call FUNC(treeControlInterface);
    _groupPaths set [_groupKey, _path select [0, 1]];
} forEach _entries;

if (_expandGroups && {_groupByMode != GROUP_BY_OFF}) then {
    {
        _control tvExpand (_groupPaths get _x);
    } forEach (keys _groupPaths);
};

uiNamespace setVariable [QGVAR(treeGroupNameCache), _groupNameCache];
