//Configurations for AI Commander.
_aiSide = west; //Change to side you want AI to play as
_pollingRate = 2;


//Run queries for every squad on the blufor side
{
	//systemChat format ["%1", _x];
	[_x, _pollingRate] execVM "EnvironmentQueries.sqf";
}forEach groups west;