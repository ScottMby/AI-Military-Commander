_aiSide = missionNamespace getVariable "_aiSide";

//Run for every squad on the AI's Side
{
	
	_controlSquad = _x;
	_controlSquad setVariable["_needReinforcement", false];
	SCM_fnc_SquadQueryRunner = {
		params["_controlSquad"];
		_reactionTime = 10;
		[_controlSquad, getPos leader _controlSquad, 1000]call BIS_fnc_taskPatrol;
		_controlSquad setVariable ["_knownBases", []];
		_controlSquad setVariable ["_LastState", "patrol"];

		//Sets up event handlers
		{
			_x addEventHandler ["FiredNear", {
						params ["_unit", "_firer", "_distance", "_weapon", "_muzzle", "_mode", "_ammo", "_gunner"];
						group _x setVariable ["_isEngaged", true];
					}];
		} forEach units _controlSquad;

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
					_squadMagazines = _squadMagazines + count magazines _x;
				};
				_squadMagazines;
			};

			_unitsInjured = 0;
			_squadMagazines = 0;
			_squadEquipment = [];
			_unitsAlive = count units _controlSquad;

			{
				_unitsAlive = [_x, _unitsAlive] call SCM_fnc_checkAlive;
				_unitsInjured = [_x] call SCM_fnc_getDamage;
				_squadMagazines = [_x] call SCM_fnc_getMagazines;
				//Divide by the amount of squad members alive
				
			} forEach units _controlSquad;

			if(_unitsAlive > 0) then
			{
				_squadMagazines = _squadMagazines / _unitsAlive;
			}
			else{
				deleteGroup _controlSquad;
			};

			_controlSquad setVariable ["_unitsAlive", _unitsAlive];
			_controlSquad setVariable ["_unitsInjured", _unitsInjured];
			_controlSquad setVariable ["_squadMagazines", _squadMagazines];
			_controlSquad setVariable ["_squadEquipment", _squadEquipment];
		};

		//Gets the enemy targets from squad leader and returns [Soldier/Vehicle, Type of Solider/Vehicle, [X pos, Y pos]]
		SCM_fnc_targetsQuery = {
			params["_controlSquad"];
			_allTargets = [];
			_targets = leader _controlSquad targetsQuery[objNull, east, "", [], 0];
			_targets;
		};

		//Returns the list of bases that a squad knows about. Format is [base name, side, targets array, knows about].
		SCM_squadBaseKnowledge = {
			params["_bases", "_controlSquad", "_targetObjects"];
			_knownBases = [];
			{
				if(_x select 1 == side _controlSquad) then 
				{
					_knownBases pushBack [_x select 0, west, "", true];
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
					};
				};
			} forEach _bases;
			//systemChat format ["%1", _knownBases];
			_knownBases;
		};

		//Returns average of squad skill from range of 0 to 1
		SCM_fnc_getSquadSkill = {
			params["_controlSquad"];	
			_squadSkillAvg = 0;	
			{
				_squadSkillAvg = _squadSkillAvg + skill _x;
			} forEach units _controlSquad;
			_squadSkillAvg = _squadSkillAvg / count units _controlSquad;
			//systemChat format ["squad skill is %1", _squadSkillAvg];
			_squadSkillAvg;
		};

		//Takes in input value and makes them inaccurate to simulate inacurracy within information exchanged from a squad to the commander.
		SCM_fnc_squadInaccuracies = {
			params["_controlSquad", "_squadMagazines", "_unitsAlive", "_unitsInjured", "_knownBases", "_squadSkill", "_squadEngaged"];
			_squadLeaderDown = !alive leader _controlSquad;
			_reactionTimeMultiplier = 1;
			//Uses a number of factors to calculate a misinformation multiplier that is applied to a weighted rng to calculate the chance of the squad delievering misinformation to the commander.
			_misinformationMultiplier = (1 - _squadSkill) * 10;
			_misinformationMultiplier = _misinformationMultiplier + (sunOrMoon * 5);
			if(_squadLeaderDown) then
			{
				_misinformationMultiplier = _misinformationMultiplier + 5;
			};
			if(_squadEngaged) then
			{
				_misinformationMultiplier = _misinformationMultiplier + 5;
			};
			_misinformationMultiplier = _misinformationMultiplier / 100;
			{
				if(_x > 0) then 
				{
					if(_forEachIndex != 3) then
					{
					//Randomise whether the multiplier has a positive or negative effect.
					_misinformationMultiplier = selectRandom [-_misinformationMultiplier, _misinformationMultiplier];
					};
					//Use a weighted RNG to randomise the chance of misinfomation while being effected by the previous factors.
					_misinformationMultiplier = random [0.75, 1 + _misinformationMultiplier, 1.25];

					_x = _x * _misinformationMultiplier;
				}
				else
				{
					_x = 0;
				};
			} foreach [_squadMagazines, _unitsInjured, _unitsAlive, _reactionTimeMultiplier];
			{
				//systemChat format ["!!! %1", _x select 1];
				if(_x select 1 != side _controlSquad) then
				{
					//Randomise whether the multiplier has a positive or negative effect.
				_misinformationMultiplier = selectRandom [-_misinformationMultiplier, _misinformationMultiplier];

				//Use a weighted RNG to randomise the chance of misinfomation while being effected by the previous factors.
				_misinformationMultiplier = random [0.75, 1 + _misinformationMultiplier, 1.25];

				_x set [4, (_x select 4) * _misinformationMultiplier];
				};
			} foreach _knownBases;
			//fuzzification
			_squadMagazinesApprox = [_squadMagazines, [0,2,7,10,12]] call SCM_fnc_fuzzifier;
			//systemChat format["squadmagsapprox %1", _squadMagazinesApprox];
			_unitsInjuredApprox = [_unitsInjured, [0,1,3,4,6]] call SCM_fnc_fuzzifier;
			{
				if(_x select 1 != side _controlSquad) then 
				{
					if (count (_x select 2) > 0) then
					{
						_knownBasesUnitsApprox = [(count (_x select 2)), [0,5,7,12,15]] call SCM_fnc_fuzzifier;
						_x pushBack _knownBasesUnitsApprox;
					}
					else
					{
						_knownBasesUnitsApprox = 0;
						_x pushBack _knownBasesUnitsApprox;
					};
				}
			} forEach _knownBases;
			_inaccurateValues = [_knownBases, _unitsAlive, _unitsInjuredApprox, _squadMagazinesApprox, _squadEngaged, _reactionTimeMultiplier];
			_inaccurateValues;
		};

		SCM_fnc_fuzzifier = {
			params["_fuzzyInput", "_ranges"];

			#define HIGH 2
			#define MID 1
			#define LOW 0

			_fuzzyInputApprox = "null";

			if(_fuzzyInput <= _ranges select 1) then
			{
				_fuzzyInputApprox = LOW;
			};
			if(_fuzzyInput > _ranges select 1 && _fuzzyInput <= _ranges select 2) then
			{
				difference = (_ranges select 2) - (_ranges select 1);
				temp = _fuzzyInput - (_ranges select 1);
				low = -1/difference * temp + 1;
				high = 1/difference * temp;
				rndm = random 100;
				if(rndm <= (low * 100)) then
				{
					_fuzzyInputApprox = LOW;
				}
				else{
					_fuzzyInputApprox = MID;
				};
			};
			if(_fuzzyInput > _ranges select 2 && _fuzzyInput <= _ranges select 3) then
			{
				_fuzzyInputApprox = MID;
			};
			if(_fuzzyInput > _ranges select 3 && _fuzzyInput <= _ranges select 4) then
			{
				difference = (_ranges select 4) - (_ranges select 3);
				temp = _fuzzyInput - (_ranges select 3);
				low = -1/difference * temp + 1;	
				high = 1/difference * temp;
				rndm = random 100;
				if(rndm <= (low * 100)) then
				{
					_fuzzyInputApprox = MID;
				}
				else{
					_fuzzyInputApprox = HIGH;
				};
			};
			if(_fuzzyInput > _ranges select 4) then
			{
					_fuzzyInputApprox = HIGH;
			};
			_fuzzyInputApprox;
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
			_newBases = [_bases, _controlSquad, _targetObjects] call SCM_squadBaseKnowledge;
				
			_knownBases append _newBases;

			_knownBases = _knownBases arrayIntersect _knownBases;

			_squadEngaged = _controlSquad getVariable "_isEngaged";
			_unitsAlive = _controlSquad getVariable "_unitsAlive";
			_unitsInjured = _controlSquad getVariable "_unitsInjured";
			_squadMagazines = _controlSquad getVariable "_squadMagazines";

			_squadSkill = [_controlSquad] call SCM_fnc_getSquadSkill;
			_inaccurateValues = [_controlSquad, _squadMagazines, _unitsAlive, _unitsInjured, _knownBases, _squadSkill, _squadEngaged] call SCM_fnc_squadInaccuracies;
		
			_controlSquad setVariable ["_processedSquadMagazines", _inaccurateValues select 3];
			_controlSquad setVariable ["_processedUnitsAlive", _inaccurateValues select 1];
			_controlSquad setVariable ["_processedUnitsInjured", _inaccurateValues select 2];
			_controlSquad setVariable ["_processedKnownBases", _inaccurateValues select 0];
			_controlSquad setVariable ["_processedSquadSkill", _squadSkill];
			_reactionTimeMutli = _inaccurateValues select 5;
			_reactionTime = (60 * _reactionTimeMutli);
			_reactionTime;
		};
		
		_aliveUnits = units _controlSquad;

		while {count (_aliveUnits) > 0} do {

		_baseTriggers = missionNamespace getVariable "_baseTriggers";
		_controlSquad setVariable ["_bases", [_baseTriggers] call SCM_fnc_getBases]; //Add bases that have been configured
		_controlSquad setVariable ["_squadSkill",[_controlSquad] call SCM_fnc_getSquadSkill];
		_controlSquad setVariable ["_isEngaged", false];

		_knownBases = _controlSquad getVariable "_knownBases";

		_reactionTime = [[_controlSquad], _baseTriggers, _knownBases, _reactionTime] call SCM_fnc_queryLoop;

		sleep _reactionTime;
		
		systemChat format ["Environment Queries called. Reaction Time: %1", _reactionTime];

		_LastState = _controlSquad getVariable "_LastState";

		[_controlSquad, _LastState] execVM "CommandDecisionProcessor.sqf";

		_aliveUnits = [];
		{
			if(alive _x) then 
			{
				_aliveUnits pushBack _x;
			}
		} forEach units _controlSquad;
		};
	};
	[_controlSquad] spawn SCM_fnc_SquadQueryRunner;
	
} forEach groups _aiSide;