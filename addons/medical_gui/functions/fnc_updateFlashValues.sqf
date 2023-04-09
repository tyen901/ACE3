#include "script_component.hpp"

params ["_ctrlGroup", "_deltaTime"];

private _flashSpeed = 4; // Increase this value to make the flash fade faster
private _maxFlashIntensity = 1; // Set the maximum flash intensity (0 to 1)

// Iterate through the body parts and update the flash value
{
    _x params ["_bodyPartIDC", "_flashIntensity"];
    private _ctrlBodyPart = _ctrlGroup controlsGroupCtrl _bodyPartIDC;

    // Reduce the flash intensity based on delta time and speed
    _flashIntensity = _flashIntensity - (_deltaTime * _flashSpeed);

    // Clamp the flash intensity between 0 and _maxFlashIntensity
    _flashIntensity = _flashIntensity max 0 min _maxFlashIntensity;

    // Update the flash intensity in the body part's flash array
    GVAR(bodyPartFlashArray) set [_forEachIndex, [_bodyPartIDC, _flashIntensity]];

    // Update the body part color based on flash intensity
    private _baseColor = _ctrlBodyPart getVariable "ace_medical_gui_baseColor";
    private _flashedColor = [_baseColor, _flashIntensity] call FUNC(mixColors);
    _ctrlBodyPart ctrlSetTextColor _flashedColor;
} forEach GVAR(bodyPartFlashArray);
