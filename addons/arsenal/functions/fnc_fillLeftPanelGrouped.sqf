#include "..\script_component.hpp"
/*
 * Author: Tyen
 * Fill a grouped Arsenal tree panel using first-letter groups.
 *
 * Arguments:
 * 0: Tree control <CONTROL>
 * 1: Entries <ARRAY>
 *  - Entry format: [className, displayName, picture, tooltip, color, value]
 * 2: Expand groups <BOOL> (default: true)
 *
 * Return Value:
 * None
 *
 * Public: No
 */

params ["_control", ["_entries", [], [[]]], ["_expandGroups", true, [true]]];

tvClear _control;
private _groupPaths = createHashMap;

{
    _x params [
        ["_className", "", [""]],
        ["_displayName", "", [""]],
        ["_picture", "", [""]],
        ["_tooltip", "", [""]],
        ["_color", [], [[]]],
        ["_value", 0, [0]]
    ];

    if (_className == "") then {
        private _path = [_control tvAdd [[], _displayName]];
        _control tvSetData [_path, ""];
        _control tvSetValue [_path, _value];
        _control tvSetTooltip [_path, _tooltip];
        if (_picture != "") then {
            _control tvSetPicture [_path, _picture];
        };
        if (_color isNotEqualTo []) then {
            _control tvSetColor [_path, _color];
        };
        continue;
    };

    private _groupKey = ["groupKey", [_displayName]] call FUNC(treeControlInterface);
    private _path = ["addLeaf", [_control, _groupKey, _className, _displayName, _picture, _tooltip, _value, _color]] call FUNC(treeControlInterface);
    _groupPaths set [_groupKey, _path select [0, 1]];
} forEach _entries;

if (_expandGroups) then {
    {
        _control tvExpand (_groupPaths get _x);
    } forEach (keys _groupPaths);
};
