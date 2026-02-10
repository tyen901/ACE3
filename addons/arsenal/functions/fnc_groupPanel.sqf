#include "..\script_component.hpp"
#include "..\defines.hpp"
/*
 * Author: ACE3 Team
 * Handles selection changes in group-by dropdown controls.
 *
 * Arguments:
 * 0: Group-by control <CONTROL>
 *
 * Return Value:
 * None
 *
 * Public: No
 */

params ["_control"];

if (GVAR(ignoreFirstGroupPanelCall)) exitWith {
    GVAR(ignoreFirstGroupPanelCall) = false;
};

private _display = ctrlParent _control;
private _isRight = ctrlIDC _control == IDC_groupRightTab;
private _groupByMode = _control lbValue (0 max lbCurSel _control);

if !(_groupByMode in [GROUP_BY_OFF, GROUP_BY_FIRST_LETTER, GROUP_BY_MOD]) then {
    _groupByMode = GROUP_BY_OFF;
};

missionNamespace setVariable [
    [QGVAR(lastGroupByLeftMode), QGVAR(lastGroupByRightMode)] select _isRight,
    _groupByMode
];

if (_isRight) then {
    if (isNil QGVAR(currentRightPanel)) exitWith {};

    [_display, _display displayCtrl GVAR(currentRightPanel), !GVAR(refreshing)] call FUNC(fillRightPanel);

    private _searchbarCtrl = _display displayCtrl IDC_rightSearchbar;
    if (ctrlText _searchbarCtrl != "") then {
        [_display, _searchbarCtrl, false] call FUNC(handleSearchbar);
    };
} else {
    if (isNil QGVAR(currentLeftPanel)) exitWith {};

    [_display, _display displayCtrl GVAR(currentLeftPanel), !GVAR(refreshing)] call FUNC(fillLeftPanel);

    private _searchbarCtrl = _display displayCtrl IDC_leftSearchbar;
    if (ctrlText _searchbarCtrl != "") then {
        [_display, _searchbarCtrl, false] call FUNC(handleSearchbar);
    };
};
