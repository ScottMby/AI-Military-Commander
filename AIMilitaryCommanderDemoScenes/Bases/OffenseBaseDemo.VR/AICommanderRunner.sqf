//Configurations for AI Commander.
_aiSide = west; //Change to side you want AI to play as
_pollingRate = 2; //Amount of time in seconds between each call of the environment query script. Higher rate means more up to date information for AI.
_baseTriggers = [Friendly_Base, Enemy_Base]; //To create bases, add triggers that surrond the base and add the variable name here. Add the side you would like to posses the base to the triggers activation.
_responseTime = [15, 120]; //Minimum to Maximum time (give or take 25%) between squad taking in information to commander telling squad what to do.

missionNamespace setVariable ["_aiSide", _aiSide];
missionNamespace setVariable ["_baseTriggers", _baseTriggers];

//systemChat format ["%1", _x];
[] execVM "EnvironmentQueries.sqf";
