/*
 * Author: commy2
 * hint the Variable ACE_isUsedBy from the input Object every frame
 *
 * Argument:
 * <OBJECT>
 *
 * Return Value:
 * None
 *
 * Public: No
 */
#include "script_component.hpp"

if (!isNil QGVAR(showUserPFH)) then {
    [GVAR(showUserPFH)] call CBA_fnc_removePerFrameHandler;
};

GVAR(showUserPFH) = [{
    hintSilent str ((_this select 0) getVariable ["ACE_isUsedBy", objNull]);
}, 0, _this] call CBA_fnc_addPerFrameHandler;
