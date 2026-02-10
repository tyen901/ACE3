#include "..\script_component.hpp"
/*
 * Author: ACE3 Team
 * Standardized tree helper interface for Arsenal content panels.
 *
 * Arguments:
 * 0: Operation <STRING>
 * 1: Arguments <ARRAY>
 *
 * Return Value:
 * Depends on operation
 *
 * Public: No
 */

params ["_operation", ["_args", []]];

switch (_operation) do {
    case "groupKey": {
        _args params [["_displayName", "", [""]]];

        if (_displayName == "") exitWith {"#"};

        private _first = toUpperANSI (_displayName select [0, 1]);
        if !(_first regexMatch "[A-Z]") then {
            _first = "#";
        };

        _first
    };

    case "isGroupPath": {
        _args params ["_control", "_path"];
        ((_control tvData _path) find "GROUP:") == 0
    };

    case "ensureGroup": {
        _args params ["_control", "_groupKey"];

        private _groupData = "GROUP:" + _groupKey;
        private _groupPath = [];
        private _count = _control tvCount [];

        for "_i" from 0 to (_count - 1) do {
            private _path = [_i];
            if ((_control tvData _path) == _groupData) exitWith {
                _groupPath = _path;
            };
        };

        if (_groupPath isEqualTo []) then {
            private _index = _control tvAdd [[], _groupKey];
            _groupPath = [_index];
            _control tvSetData [_groupPath, _groupData];
            _control tvSetValue [_groupPath, -1];
        };

        _groupPath
    };

    case "addLeaf": {
        _args params [
            "_control",
            "_groupKey",
            ["_className", "", [""]],
            ["_displayName", "", [""]],
            ["_picture", "", [""]],
            ["_tooltip", "", [""]],
            ["_value", 0, [0]],
            ["_color", [], [[]]]
        ];

        private _groupPath = ["ensureGroup", [_control, _groupKey]] call FUNC(treeControlInterface);
        private _index = _control tvAdd [_groupPath, _displayName];
        private _path = _groupPath + [_index];

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

    case "getSelectedLeaf": {
        _args params ["_control"];

        private _path = tvCurSel _control;
        if (_path isEqualTo []) exitWith {[[], ""]};
        if (["isGroupPath", [_control, _path]] call FUNC(treeControlInterface)) exitWith {[[], ""]};

        [_path, _control tvData _path]
    };

    case "findLeafPathByData": {
        _args params ["_control", ["_className", "", [""]]];

        private _groupCount = _control tvCount [];
        private _foundPath = [];
        private _done = false;

        for "_groupIndex" from 0 to (_groupCount - 1) do {
            if (_done) exitWith {};

            private _groupPath = [_groupIndex];
            if !(["isGroupPath", [_control, _groupPath]] call FUNC(treeControlInterface)) then {
                if ((_control tvData _groupPath) == _className) then {
                    _foundPath = _groupPath;
                    _done = true;
                };
                continue;
            };

            private _leafCount = _control tvCount _groupPath;
            for "_leafIndex" from 0 to (_leafCount - 1) do {
                private _leafPath = _groupPath + [_leafIndex];
                if ((_control tvData _leafPath) == _className) exitWith {
                    _foundPath = _leafPath;
                    _done = true;
                };
            };
        };

        _foundPath
    };

    case "collectLeafPaths": {
        _args params ["_control", ["_includeEmpty", true, [true]]];

        private _paths = [];
        private _groupCount = _control tvCount [];
        private _groupPath = [];
        private _leafPath = [];

        for "_groupIndex" from 0 to (_groupCount - 1) do {
            _groupPath = [_groupIndex];

            if !(["isGroupPath", [_control, _groupPath]] call FUNC(treeControlInterface)) then {
                if (_includeEmpty || {(_control tvData _groupPath) != ""}) then {
                    _paths pushBack _groupPath;
                };
                continue;
            };

            for "_leafIndex" from 0 to ((_control tvCount _groupPath) - 1) do {
                _leafPath = _groupPath + [_leafIndex];
                if (_includeEmpty || {(_control tvData _leafPath) != ""}) then {
                    _paths pushBack _leafPath;
                };
            };
        };

        _paths
    };

    case "setLeafQuantityText": {
        _args params [
            "_control",
            "_path",
            ["_quantity", 0, [0]],
            ["_baseDisplayName", "", [""]]
        ];

        _control tvSetText [_path, format ["%1 (x%2)", _baseDisplayName, _quantity]];
        _control tvSetValue [_path, _quantity];
    };
};
