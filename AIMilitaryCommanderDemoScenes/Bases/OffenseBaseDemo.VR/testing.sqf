{
	{
		[_x] spawn {params["_thisUnit"]; while{true} do {diag_log format["HELLOITSSCOTT, %1, %2, %3", time, getPos _thisUnit, name _thisUnit]; sleep 1};};
	} forEach units _x;
}forEach groups west;
