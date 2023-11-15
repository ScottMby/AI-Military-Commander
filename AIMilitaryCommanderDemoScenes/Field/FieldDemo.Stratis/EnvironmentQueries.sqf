_aiSide = missionNamespace getVariable "_aiSide";

//Run for every squad on the AI's Side
{
	_pollingRate = missionNamespace getVariable "_pollingRate";
	_baseTriggers = missionNamespace getVariable "_baseTriggers";

	_controlSquad = _x;

	_controlSquad setVariable ["_priority", "MEDIUM"]; //Sets default sqaud priority
	_controlSquad setVariable ["_currentState", "START"]; //Sets default squad state

	//Returns trigger of a base along with its side.
	SCM_fnc_getBases = {
		params["_baseTriggers"];
		_bases = [];
		{
			_triggerActivation = triggerActivation _x;
			if (_triggerActivation select 0 == "WEST") then
			{
				_bases pushBack [_x, west, [], false];
			};
			if (_triggerActivation select 0 == "EAST") then
			{
				_bases pushBack [_x, east, [], false];
			};
		} forEach _baseTriggers;
		_bases;
	};

	//Add bases that have been configured
	_controlSquad setVariable ["_bases", [_baseTriggers] call SCM_fnc_getBases];

	//Initialize any variables
	_controlSquad setVariable ["_isSuppressed", false];
	_knownBases = [];

	//Sets up event handlers
	{
		_x addEventHandler ["Suppressed", {
					params ["_unit", "_firer", "_distance", "_weapon", "_muzzle", "_mode", "_ammo", "_gunner"];
					group _x setVariable ["_isSuppressed", true];
				}];
	} forEach units _controlSquad;

	//Queries the squads condition, equipment etc...
	SCM_fnc_getSquadInformation = {
		params["_controlSquad"];

		//Checks the amount of squad members alive
		SCM_fnc_checkAlive = {
			params ["_x", "_unitsAlive"];
			if(!alive _x) then
			{
				_unitsAlive = _unitsAlive - 1;
			};
			_unitsAlive;
		};

		//Checks the amount of injured soldiers in a squad
		SCM_fnc_getDamage = {
			params ["_x"];
			if(_x call ACE_medical_ai_fnc_isInjured) then
			{
				_unitsInjured = _unitsInjured + 1;
			};
			_unitsInjured;
		};

		//Gets average of magazines left in squads inventory
		SCM_fnc_getMagazines = {
			params ["_x"];
			if(alive _x) then{
				_groupMagazines = _groupMagazines + count magazines _x;
			};
			_groupMagazines;
		};

		_unitsInjured = 0;
		_groupMagazines = 0;
		_groupEquipment = [];
		_unitsAlive = count units _controlSquad;

		{
			_unitsAlive = [_x, _unitsAlive] call SCM_fnc_checkAlive;
			_unitsInjured = [_x] call SCM_fnc_getDamage;
			_groupMagazines = [_x] call SCM_fnc_getMagazines;
			_groupEquipment = [_x, _groupEquipment] call SCM_fnc_squadEquipment;
			//Divide by the amount of squad members alive
			
		} forEach units _controlSquad;
		//systemChat format ["%1", _groupEquipment];

		if(_unitsAlive > 0) then
		{
			_groupMagazines = _groupMagazines / _unitsAlive;
		};

		_controlSquad setVariable ["_unitsAlive", _unitsAlive];
		_controlSquad setVariable ["_unitsInjured", _unitsInjured];
		_controlSquad setVariable ["_groupMagazines", _groupMagazines];
		_controlSquad setVariable ["_groupEquipment", _groupEquipment];
	};

	//Gets the enemy targets from squad leader and returns [Soldier/Vehicle, Type of Solider/Vehicle, [X pos, Y pos]]
	SCM_fnc_targetsQuery = {
		params["_controlSquad"];
		_allTargets = [];
		_targets = leader _controlSquad targetsQuery[objNull, east, "", [], 0];
		_allTargets append _targets;
		_formattedTargets = [];
		{
			_targetObject = _x select 1;
			_targetClass = typeOf _targetObject;
			_targetType = _targetClass call BIS_fnc_objectType;
			_formattedTarget = _targetType;
			_targetPosition = _x select 4;
			_formattedTarget pushBack _targetPosition;
			_formattedTargets pushBack _formattedTarget;
		}forEach _allTargets;
		//systemChat format ["%1", _formattedTargets];
		_controlSquad setVariable ["_squadTargets", _formattedTargets];
		_targets;
	};

	//Queries for specific classes within the squad in order to know what equipment is avaiable to them.
	SCM_fnc_squadEquipment = {
		params ["_x", "_unitEquipment"];
		_launcherAT = ["ACE_launch_NLAW_ready_F", "launch_RPG32_green_F", "launch_RPG32_ghex_F", "launch_RPG32_F", "launch_RPG7_F", "launch_O_Titan_short_F" , "launch_I_Titan_short_F", "launch_O_Titan_short_ghex_F", "launch_launch_B_Titan_short_F", "launch_B_Titan_short_tna_F", "launch_MRAWS_green_rail_F", "launch_MRAWS_olive_rail_F", "launch_MRAWS_sand_rail_F", "launch_MRAWS_green_F", "launch_MRAWS_olive_F", "launch_MRAWS_sand_F", "launch_O_Vorona_brown_F", "launch_O_Vorona_green_F"];
		_launcherAA = ["launch_I_Titan_F","launch_O_Titan_F", "launch_O_Titan_ghex_F", "launch_I_Titan_eaf_F", "launch_B_Titan_F", "launch_B_Titan_olive_F", "launch_B_Titan_tna_F"];
		_sniper = "srifle";
		if(secondaryWeapon _x in _launcherAT) then
		{
			_unitEquipment pushBack "AT";
		};

		if(secondaryWeapon _x in _launcherAA) then
		{
			_unitEquipment pushBack "AA";
		};

		_targetObject = _x;
		_targetClass = typeOf _targetObject;
		_targetType = _targetClass call BIS_fnc_objectType;

		_soldierType = _targetType select 1;

		if(_soldierType == "MG") then
		{
			if(count magazines _x > 0) then
			{
				_unitEquipment pushBack "MG";
			};
		};

		if(_soldierType == "MEDIC") then
		{
			_unitEquipment pushBack "MEDIC";
		};

		if(_sniper in primaryWeapon _x) then
		{
			_unitEquipment pushBack "SNIPER";
		};
		//systemChat format ["%1", _unitEquipment];
		_unitEquipment;
	};

	//Returns the list of bases that a squad knows about. Format is [base name, side, targets array, knows about].
	SCM_squadBaseKnowledge = {
		params["_bases", "_knownBases", "_controlSquad", "_targetObjects"];
		_knownBases = [];
		index = 0;
		{
			if(_x select 1 == side _controlSquad) then 
			{
				_knownBases pushBack [_x select 0, west, [], true];
			}
			else
			{
				_y = _x select 0; //So we can access both itterated elements.

				//We have several approches here to check whether any of our units have seen an enemy base. 
				//This implementation checks if the squad see any targets in base areas.
				//If the targets are in the base areas, we will assunme that the squad also saw the base.

				_baseTargets = []; //targets within base
				{
					_trigger = _y;
					_target = _x select 1;
					if(_target inArea _trigger) then {
						_baseTargets pushBack _x;
					};
				} forEach _targetObjects;

				if(count _baseTargets > 0) then
				{
					_knownBases pushBack [_y, east, _baseTargets, true];
				}
				else{
					_currentBase = _bases select index;
					_knownBases pushBack [_y, east, [], _currentBase select 3];
				};
			};
			index = index + 1;
		} forEach _bases;
		_controlSquad setVariable ["_bases", _knownBases];
		//systemChat format ["%1", _knownBases];
		_knownBases;
	};

	//Calls all queries
	SCM_fnc_queryLoop = {
		params["_args"];

		_controlSquad = _args select 0;
		_baseTriggers = _args select 1;
		_knownBases = _args select 2;
		_bases = _controlSquad getVariable "_bases";

		[_controlSquad] call SCM_fnc_getSquadInformation;
		_targetObjects = [_controlSquad] call SCM_fnc_targetsQuery;

		_knownBases = [_bases, _knownBases, _controlSquad, _targetObjects] call SCM_squadBaseKnowledge;


		_squadSuppressed = _controlSquad getVariable "_isSuppressed";
		_unitsAlive = _controlSquad getVariable "_unitsAlive";
		_unitsInjured = _controlSquad getVariable "_unitsInjured";
		_groupMagazines = _controlSquad getVariable "_groupMagazines";

		//Prints for debugging and test purposes
			//systemChat format ["Squad: %4. There are %1 soldiers left in the squad with %2 injured soldiers. They have %3 magazines on average", _unitsAlive, _unitsInjured, _groupMagazines, _controlSquad];

			if(_squadSuppressed) then 
			{
				//systemChat "squad is suppressed";
				_controlSquad setVariable ["_isSuppressed", false];
			}; 
	};
	//Calls query loop every two seconds
	[SCM_fnc_queryLoop, _pollingRate, [_controlSquad, _baseTriggers, _knownBases]] call CBA_fnc_addPerFrameHandler;

} forEach groups _aiSide;