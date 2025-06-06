global function GamemodeCampaign_Int

struct
{
int militia_npc_count = 0
int imc_npc_count = 0
int militia_spectre_count = 0
int imc_spectre_count = 0
array<entity> hardpoints
entity hardpointA
entity hardpointB
entity hardpointC
table<int,int> hardpointAnpccount
table<int,int> hardpointBnpccount
table<int,int> hardpointCnpccount
table<entity,int> hardpointprogress
table<entity,int> hardpointprogressteam
table<int,string> nexthardpointtarget
table<entity,entity> hardpointseatA
table<entity,entity> hardpointseatB
table<entity,entity> hardpointseatC
table<entity,entity> hardpointseatD
table<entity,bool> entityisusinghardpoint
array<string> gruntweapons = [ "mp_weapon_rspn101", "mp_weapon_dmr", "mp_weapon_r97", "mp_weapon_lmg" ]
array<string> spectreweapons = [ "mp_weapon_hemlok_smg", "mp_weapon_doubletake", "mp_weapon_mastiff" ]
string mode = ""
}file

array<string> aitdm_levels = [
"mp_angel_city",
"mp_colony02",
"mp_relic02",
"mp_lf_uma",
"mp_lf_stacks",
"mp_lf_deck",
"mp_lf_meadow",
"mp_lf_traffic",
"mp_lf_township",
]

array<string> cp_levels = [
"mp_black_water_canal",
]

void function GamemodeCampaign_Int()
{
string map = GetMapName()
//PrecacheModel( MODEL_ATTRITION_BANK )
PrecacheModel( $"models/communication/terminal_com_station.mdl" )
PrecacheModel( $"models/vehicle/hornet/hornet_fighter.mdl" )
ScoreEvent_SetupEarnMeterValuesForMixedModes()
SetSpawnpointGamemodeOverride( ATTRITION )
if( aitdm_levels.contains( map ) )
{
AddCallback_GameStateEnter( eGameState.Playing, Attrition )
return
}
if( cp_levels.contains( map ) )
{
AddCallback_GameStateEnter( eGameState.Playing, Hardpoint )
return
}
if( RandomInt( 100 ) < 50 )
AddCallback_GameStateEnter( eGameState.Playing, Hardpoint )
else
AddCallback_GameStateEnter( eGameState.Playing, Attrition )
}

/*
Attrition Logic
*/

void function Attrition()
{
file.mode = "Attrition"
AddCallback_OnNPCKilled( HandleScoreEvent )
AddCallback_OnPlayerKilled( HandleScoreEvent )
AddCallback_NPCLeeched( OnSpectreLeeched )
Intro()
thread Attrition_militia()
thread Attrition_imc()
}

void function Attrition_militia()
{
bool didwait = false
 while( file.militia_npc_count <= 12 )
 {
 WaitFrame()
 if ( RandomInt( 100 ) < 50 && file.militia_spectre_count <= 4 )
 thread SpawnNPCDroppod( TEAM_MILITIA, "npc_spectre" )
 else
 thread SpawnNPCDroppod( TEAM_MILITIA, "npc_soldier" )
 }
 while( true )
 {
  didwait = false
  if( GetGameState() != eGameState.Playing )
  return
  if( file.militia_npc_count <= 12 )
  {
  wait RandomFloatRange( 5, 10 )
  didwait = true
  if ( RandomInt( 100 ) < 50 && file.militia_spectre_count <= 4 )
  thread SpawnNPCDroppod( TEAM_MILITIA, "npc_spectre" )
  else
  thread SpawnNPCDroppod( TEAM_MILITIA, "npc_soldier" )
  }
  if( didwait == false )
  WaitFrame()
 }
}

void function Attrition_imc()
{
bool didwait = false
 while( file.imc_npc_count <= 12 )
 {
 WaitFrame()
 if ( RandomInt( 100 ) < 50 && file.imc_spectre_count <= 4 ) // Cap Spectre Count To 8 So Players Can't Spam Hack Them
 thread SpawnNPCDroppod( TEAM_IMC, "npc_spectre" )
 else
 thread SpawnNPCDroppod( TEAM_IMC, "npc_soldier" )
 }
 while( true )
 {
  didwait = false
  if( GetGameState() != eGameState.Playing )
  return
  if( file.imc_npc_count <= 12 )
  {
  wait RandomFloatRange( 5, 10 )
  didwait = true
  if ( RandomInt( 100 ) < 50 && file.imc_spectre_count <= 4 ) // Cap Spectre Count To 8 So Players Can't Spam Hack Them
  thread SpawnNPCDroppod( TEAM_IMC, "npc_spectre" )
  else
  thread SpawnNPCDroppod( TEAM_IMC, "npc_soldier" )
  }
  if( didwait == false )
  WaitFrame()
 }
}

void function DeathCheck( entity npc )
{
npc.EndSignal( "OnDestroy" )
npc.EndSignal( "OnDeath" )
int team = npc.GetTeam()
string npcclass = npc.GetClassName()
if( npcclass == "npc_spectre" )
thread SpectreTeamCheck( npc )
OnThreadEnd(
	function() : ( team, npcclass )
	{
		if( team == TEAM_MILITIA && npcclass != "npc_spectre" )
		file.militia_npc_count = file.militia_npc_count - 1
		if( team == TEAM_IMC && npcclass != "npc_spectre" )
		file.imc_npc_count = file.imc_npc_count - 1
		if( team == TEAM_MILITIA && npcclass == "npc_spectre" )
		file.militia_spectre_count = file.militia_spectre_count - 1
		if( team == TEAM_IMC && npcclass == "npc_spectre" )
		file.imc_spectre_count = file.imc_spectre_count - 1
	}
)
WaitForever()
}

void function SpectreTeamCheck( entity npc )
{
npc.EndSignal( "OnDestroy" )
npc.EndSignal( "OnDeath" )
npc.EndSignal( "OnLeeched" )
int team = npc.GetTeam()
OnThreadEnd(
	function() : ( team )
	{
		if( team == TEAM_MILITIA )
		file.militia_npc_count = file.militia_npc_count - 1
		if( team == TEAM_IMC )
		file.imc_npc_count = file.imc_npc_count - 1
	}
)
WaitForever()
}

void function SpawnNPCDroppod( int team, string npc )
{
    array<entity> npcs
	array<entity> droppodspawns = SpawnPoints_GetTitan() // Replaced With SpawnPoints_GetTitan() Because Droppod Spawns Spawn The NPC Out Of Bounds
	bool isvaliddroppodspawn = false
	foreach( entity droppod in droppodspawns )
	{
	if( IsValid( droppod ) )
	isvaliddroppodspawn = true
	}
	if( isvaliddroppodspawn == false )
	droppodspawns = SpawnPoints_GetPilot()
	entity node = droppodspawns.getrandom()
	vector pos = node.GetOrigin()
	vector angles = node.GetAngles()
	entity pod = CreateDropPod( pos, angles )
	if( team == TEAM_MILITIA )
	file.militia_npc_count = file.militia_npc_count + 4
	if( team == TEAM_IMC )
	file.imc_npc_count = file.imc_npc_count + 4
	if( team == TEAM_MILITIA && npc == "npc_spectre" )
	file.militia_spectre_count = file.militia_spectre_count + 4
	if( team == TEAM_IMC && npc == "npc_spectre" )
	file.imc_spectre_count = file.imc_spectre_count + 4
	entity hardpoint
	string nexthardpointtarget = "A"
	if( team in file.nexthardpointtarget )
	nexthardpointtarget = file.nexthardpointtarget[team]
	nexthardpointtarget = GetLowestNPCCountHardpoint( team, nexthardpointtarget )
	if( npc == "npc_spectre" )
	nexthardpointtarget = ""
	if( nexthardpointtarget == "A" )
	file.nexthardpointtarget[team] <- "B"
	if( nexthardpointtarget == "B" )
	file.nexthardpointtarget[team] <- "C"
	if( nexthardpointtarget == "C" )
	file.nexthardpointtarget[team] <- "A"

	if( nexthardpointtarget == "A" )
	{
	hardpoint = file.hardpointA
	if( team in file.hardpointAnpccount )
	file.hardpointAnpccount[team] <- file.hardpointAnpccount[team] + 4
	if( !(team in file.hardpointAnpccount) )
	file.hardpointAnpccount[team] <- 4
	}
	if( nexthardpointtarget == "B" )
	{
	hardpoint = file.hardpointB
	if( team in file.hardpointBnpccount )
	file.hardpointBnpccount[team] <- file.hardpointBnpccount[team] + 4
	if( !(team in file.hardpointAnpccount) )
	file.hardpointBnpccount[team] <- 4
	}
	if( nexthardpointtarget == "C" )
	{
	hardpoint = file.hardpointC
	if( team in file.hardpointCnpccount )
	file.hardpointCnpccount[team] <- file.hardpointCnpccount[team] + 4
	if( !(team in file.hardpointAnpccount) )
	file.hardpointCnpccount[team] <- 4
	}
	
	InitFireteamDropPod( pod )
		
	waitthread LaunchAnimDropPod( pod, "pod_testpath", pos, angles )

	string squadName = MakeSquadName( team, UniqueString( "" ) )
	for ( int i = 0; i < 4; i++ )
	{
		entity entitynpc = CreateNPC( npc, team, pos, angles )
		DispatchSpawn( entitynpc )
		entitynpc.SetEnemyChangeCallback( OnNPCEnemyChange )
		if( npc == "npc_spectre" )
		{
		EnableLeeching( entitynpc )
		entitynpc.SetUsableByGroup( "enemies pilot" )
		}
		thread DeathCheck( entitynpc )
		SetSquad( entitynpc, squadName )
		
		SetUpNPCWeapons( entitynpc )
		TakeWeaponsForArray( entitynpc, entitynpc.GetMainWeapons() )
		if( npc == "npc_spectre" )
		entitynpc.GiveWeapon( file.spectreweapons.getrandom() )
		if( npc != "npc_spectre" )
		entitynpc.GiveWeapon( file.gruntweapons.getrandom() )
		entitynpc.GiveWeapon( "mp_weapon_rocket_launcher" )
		
		entitynpc.SetParent( pod, "ATTACH", true )
		entitynpc.Minimap_AlwaysShow( GetOtherTeam( team ), null )
		if( file.mode == "Hardpoint" && IsValid( hardpoint ) && npc != "npc_spectre" )
		{
		entitynpc.Signal( "StopHardpointBehavior" )
	    int followBehavior = GetDefaultNPCFollowBehavior( entitynpc )
	    entitynpc.InitFollowBehavior( hardpoint, followBehavior )
	    entitynpc.EnableBehavior( "Follow" )
		entitynpc.DisableBehavior( "Assault" )
		thread ChangeHardpointNPCCount( entitynpc, nexthardpointtarget )
		thread NPCHardpointSeat( entitynpc, hardpoint.GetOwner() )
		}
		
		npcs.append( entitynpc )
	}
	
	ActivateFireteamDropPod( pod, npcs )

	if( npc == "npc_spectre" || file.mode == "Attrition" ) // This Moves The NPCs Away From The Hardpoint
	thread SquadHandler( npcs )
	if( GetMapName().find( "mp_lf_") != null ) // These Maps Spawn The NPC Outside The Map
 	{
 	foreach( entity entitynpc in npcs )
 	thread PutDroppodNPCInSafePos( entitynpc, pod )
 	}
 }
 
 void function PutDroppodNPCInSafePos( entity npc, entity npcpod )
 {
 npc.EndSignal( "OnDestroy" )
 npc.EndSignal( "OnDeath" )
 npcpod.EndSignal( "OnDestroy" )
 npcpod.EndSignal( "OnDeath" )
 WaittillAnimDone( npc )
 PutEntityInSafeSpot( npc, null, null, npcpod.GetOrigin(), npc.GetOrigin() )
 }

void function OnNPCEnemyChange( entity guy )
{
	if ( !IsAlive( guy ) )
		return

	if ( guy.IsFrozen() )
		return

	entity enemy = guy.GetEnemy()
	if ( !IsAlive( enemy ) )
		return

	array<entity> weapons = guy.GetMainWeapons()
	if ( weapons.len() < 2 )
		return

	entity activeWeapon = guy.GetActiveWeapon()
	if ( !IsValid( activeWeapon ) )
		return

	string activeWeaponName = activeWeapon.GetWeaponClassName()
	bool antiTitanActive = activeWeapon != weapons[0] && !activeWeapon.GetWeaponSettingBool( eWeaponVar.titanarmor_critical_hit_required )

	bool isHeavyArmorTarget = enemy.GetArmorType() == ARMOR_TYPE_HEAVY

	string weaponToChange = ""
	if ( isHeavyArmorTarget )
	{
		if ( antiTitanActive )
			return

		foreach ( entity weapon in weapons )
		{
			string className = weapon.GetWeaponClassName()
			if ( activeWeaponName == className )
				continue
			bool isMainWeapon = weapon == weapons[0]
			bool isAntiTitan = !weapon.GetWeaponSettingBool( eWeaponVar.titanarmor_critical_hit_required )
			if ( isAntiTitan && !isMainWeapon )
			{
				weaponToChange = className
				break
			}
		}
	}
	else if ( antiTitanActive )
	{
		foreach ( entity weapon in weapons )
		{
			string className = weapon.GetWeaponClassName()
			if ( activeWeaponName == className )
				continue
			bool isMainWeapon = weapon == weapons[0]
			bool isAntiTitan = !weapon.GetWeaponSettingBool( eWeaponVar.titanarmor_critical_hit_required )
			if ( isMainWeapon || !isAntiTitan )
			{
				weaponToChange = className
				break
			}
		}
	}
 
	if ( weaponToChange == "" )
		return

		guy.SetActiveWeaponByName( weaponToChange )
}

void function SetUpNPCWeapons( entity guy )
{
	string className = guy.GetClassName()
	array<string> mainWeapons
	/*
	if ( className in file.npcWeaponsTable )
		mainWeapons = file.npcWeaponsTable[ className ]
	*/
	
	if ( mainWeapons.len() == 0 ) // no valid weapons
		return

	// take off existing main weapons, or sometimes they'll have a archer by default
	foreach ( entity weapon in guy.GetMainWeapons() )
		guy.TakeWeapon( weapon.GetWeaponClassName() )

	if ( mainWeapons.len() > 0 )
	{
		string weaponName = mainWeapons[ RandomInt( mainWeapons.len() ) ]
		guy.GiveWeapon( weaponName )
		guy.SetActiveWeaponByName( weaponName )
	}
}

void function SquadHandler( array<entity> guys )
{
	int team = guys[0].GetTeam()
	bool hasHeavyArmorWeapon = false // let's check if guys has heavy armor weapons
	foreach ( entity guy in guys )
	{
		if ( hasHeavyArmorWeapon ) // found heavy armor weapon
			break

		foreach ( entity weapon in guy.GetMainWeapons() )
		{
			if ( !weapon.GetWeaponSettingBool( eWeaponVar.titanarmor_critical_hit_required ) )
			{
				hasHeavyArmorWeapon = true
				break
			}
		}
	}
	//print( "hasHeavyArmorWeapon: " + string( hasHeavyArmorWeapon ) )

	array<entity> points
	vector point
	
	// Setup AI
	foreach ( guy in guys )
	{
		// show the squad enemy radar
		AddMinimapForNPC( guy )

		guy.EnableNPCFlag( NPC_ALLOW_PATROL | NPC_ALLOW_INVESTIGATE | NPC_ALLOW_HAND_SIGNALS | NPC_ALLOW_FLEE )
		if ( hasHeavyArmorWeapon ) // squads won't flee if they got heavy armor weapon
			guy.DisableNPCFlag( NPC_ALLOW_FLEE )

		guy.AssaultSetGoalRadius( 1600 ) // 1600 is minimum for npc_stalker, works fine for others
	
		//thread AITdm_CleanupBoredNPCThread( guy )
	}
	
	wait 3 // initial wait before guys disembark from droppod
	
	// Every 5 - 15 secs get a closest target and go to them
	while ( true )
	{
		WaitFrame() // wait a frame each loop

		// remove dead guys
		ArrayRemoveDead( guys )
		foreach ( guy in guys )
		{
			// check leechable guys
			if ( guy.GetTeam() != team )
				guys.removebyvalue( guy )
		}
		// Stop func if our squad has been killed off
		if ( guys.len() == 0 )
			return

		// Get point and send our whole squad to it
		points = []
		array<entity> pointsToSearch = []
		// try to find from npc targets
		pointsToSearch.extend( GetNPCArrayOfEnemies( team ) )
		// start searching
		foreach ( entity ent in pointsToSearch )
		{
			// general check
			if ( !IsValidNPCAssaultTarget( ent ) )
				continue

			// infantry specific
			// only search for targets with light armor if we don't have proper weapon
			if ( !hasHeavyArmorWeapon && ent.GetArmorType() == ARMOR_TYPE_HEAVY )
				continue

			points.append( ent )
		}

		ArrayRemoveDead( points ) // remove dead targets
		if ( points.len() == 0 ) // can't find any points here
			continue

		// get nearest enemy and send our full squad to it
		entity enemy = GetClosest2D( points, guys[0].GetOrigin() )
		if ( !IsAlive( enemy ) )
			continue
		point = enemy.GetOrigin()
		
		// get clamped pos for first guy of guys
		vector ornull clampedPos = NavMesh_ClampPointForAI( point, guys[0] )
		if ( clampedPos == null )
			continue
		expect vector( clampedPos )

		foreach ( guy in guys )
		{
			if ( IsAlive( guy ) )
				guy.AssaultPoint( clampedPos )
		}

		wait RandomFloatRange(5.0,15.0)
	}
}

void function AddMinimapForNPC( entity guy )
{
	if ( !IsAlive( guy ) )
		return
	
	// map
	guy.Minimap_AlwaysShow( TEAM_IMC, null )
	guy.Minimap_AlwaysShow( TEAM_MILITIA, null )
	foreach ( entity player in GetPlayerArray() )
		guy.Minimap_AlwaysShow( 0, player )
	guy.Minimap_SetHeightTracking( true )

	/*
	if ( GAMETYPE == AI_TDM ) // eMinimapObject_npc.AI_TDM_AI only works for attrition!
	{
		// can be found in cl_gamemode_aitdm.nut
		const array<string> AITDM_VALID_MINIMAP_NPCS =
		[
			"npc_soldier",
			"npc_spectre",
			"npc_stalker",
			"npc_super_spectre"
		]
		if ( AITDM_VALID_MINIMAP_NPCS.contains( guy.GetClassName() ) )
			guy.Minimap_SetCustomState( eMinimapObject_npc.AI_TDM_AI )
	}
	*/
}

bool function IsValidNPCAssaultTarget( entity ent )
{
	// got killed but still valid?
	if ( !IsAlive( ent ) )
		return false

	// cannot be targeted?
	if ( ent.GetNoTarget() ) 
		return false

	// is invulnerable?
	if ( ent.IsInvulnerable() )
		return false

	// been cloaked?
	if ( IsCloaked( ent ) )
		return false
	
	// doing phase shift?
	if ( ent.IsPhaseShifted() )
		return false
	
	// npc
	if ( ent.IsNPC() )
	{
		// titan
		if ( ent.IsTitan() )
		{
			// is hot dropping?
			if ( ent.e.isHotDropping )
				return false

			// is player owned?
			if ( ent.GetBossPlayer() )
				return false
		}
	}

	// all checks passed
	return true
}

void function HandleScoreEvent( entity victim, entity attacker, var damageInfo )
{
	// Basic checks
	if ( victim == attacker /*|| !( attacker.IsPlayer() || attacker.IsTitan() )*/ || GetGameState() != eGameState.Playing )
		return
	// Hacked spectre filter
	if ( victim.GetOwner() == attacker )
		return
	bool attackerhasplayersonteam = false // Lets Have It So If The Enemy Team Has No Players We Let The NPCs Get Score For The Team
	if( !attacker.IsPlayer() )
	{
	 foreach( entity player in GetPlayerArray() )
	 {
	 if( player.GetTeam() == attacker.GetTeam() )
	 attackerhasplayersonteam = true
	 }
	}
	// NPC titans without an owner player will not count towards any team's score
	//if ( attackerhasplayersonteam == true && attacker.IsNPC() && attacker.IsTitan() && !IsValid( GetPetTitanOwner( attacker ) ) )
		//return
	
	// Split score so we can check if we are over the score max
	// without showing the wrong value on client
	int teamScore
	int playerScore
	string eventName
	
	// Handle AI, marvins aren't setup so we check for them to prevent crash
	if ( victim.IsNPC() && victim.GetClassName() != "npc_marvin" )
	{
		switch ( victim.GetClassName() )
		{
			case "npc_soldier":
			case "npc_spectre":
			case "npc_stalker":
				playerScore = 1
				break
			case "npc_super_spectre":
				playerScore = 3
				break
			default:
				playerScore = 0
				break
		}
		
		// Titan kills get handled bellow this
		if ( eventName != "KillNPCTitan"  && eventName != "" )
			playerScore = ScoreEvent_GetPointValue( GetScoreEvent( eventName ) )
	}
	
	if ( victim.IsPlayer() )
		playerScore = 5
	
	// Player ejecting triggers this without the extra check
	if ( victim.IsTitan() && victim.GetBossPlayer() != attacker )
		playerScore += 10

	//if( !attacker.IsPlayer() && playerScore == 1 )
	//return // Don't Give Score If An NPC Kills A Normal NPC

	//if ( !attacker.IsPlayer() && playerScore == 1 && RandomInt( 100 ) < 75 ) // Lets Do A 25% Chance For NPCs To Get Points If They Kill A Normal NPC
	//return

	if( !attacker.IsPlayer() && attackerhasplayersonteam == true && playerScore == 1 && !IsValid( attacker.GetBossPlayer() ) && RandomInt( 100 ) < 50 )
	return
	
	
	teamScore = playerScore
	
	// Check score so we dont go over max
	if ( GameRules_GetTeamScore(attacker.GetTeam()) + teamScore > GetScoreLimit_FromPlaylist() )
		teamScore = GetScoreLimit_FromPlaylist() - GameRules_GetTeamScore(attacker.GetTeam())
	
	// Add score + update network int to trigger the "Score +n" popup
	AddTeamScore( attacker.GetTeam(), teamScore )
	if( attacker.IsPlayer() )
	attacker.AddToPlayerGameStat( PGS_SCORE, playerScore )
}

void function OnSpectreLeeched( entity spectre, entity player )
{
	spectre.SetOwner( player )
	AddTeamScore( player.GetTeam(), 1 )
	player.AddToPlayerGameStat( PGS_SCORE, 1 )
}

void function InfiniteTitanAmmo( entity titan )
{
titan.EndSignal( "OnDestroy" )
titan.EndSignal( "OnDeath" )
titan.EndSignal( "OnAnimationInterrupted" )
titan.EndSignal( "OnAnimationDone" )
if( titan.GetMainWeapons().len() == 0 )
return
array<entity> weapons = titan.GetMainWeapons()
entity trueweapon
foreach( entity weapon in weapons )
trueweapon = weapon
 while( true )
 {
 if( IsValid( trueweapon ) )
 trueweapon.SetWeaponPrimaryClipCount( trueweapon.GetWeaponPrimaryClipCountMax() )
 if( !IsValid( trueweapon ) )
 return
 WaitFrame()
 }
}

void function OnTitanBodyGroupChange( entity titan )
{
 while( true )
 {
 if( !IsValid( titan ) )
 return
 if( !titan.IsTitan() )
 return
 if ( titan.GetModelName() != $"models/titans/atlas/atlas_titan.mdl" )
 return
 if ( titan.GetBodyGroupState( 4 ) != 1 )
 titan.SetBodygroup( 4, 1 )
 WaitFrame()
 }
}

void function KillNPC( entity npc )
{
wait 13.5
if( IsValid( npc ) )
npc.Destroy()
}

/*
Hardpoint Logic
*/

void function Hardpoint()
{
file.mode = "Hardpoint"
AddCallback_NPCLeeched( OnSpectreLeechedHardpoint )
thread Hardpoints()
Intro()
thread HardpointThink()
thread HardpointPointsThink()
thread Attrition_militia()
thread Attrition_imc()
}

void function Hardpoints()
{
	foreach ( entity spawnpoint in GetEntArrayByClass_Expensive( "info_hardpoint" ) )
	{
		if ( spawnpoint.HasKey( "gamemode_cp" ) && (spawnpoint.kv["gamemode_cp"] == "0" || spawnpoint.kv["gamemode_cp"] == "") )
		{
		    spawnpoint.Destroy()
		    continue
		}

		// spawnpoints are CHardPoint entities
		// init the hardpoint ent
		int hardpointID = 0
		string group = GetHardpointGroup(spawnpoint)
			if ( group == "B" )
				hardpointID = 1
			else if ( group == "C" )
				hardpointID = 2

		spawnpoint.SetHardpointID( hardpointID )

		//entity hardpoint = CreatePropDynamic( MODEL_ATTRITION_BANK, spawnpoint.GetOrigin(), spawnpoint.GetAngles(), 6 )
		//thread PlayAnim( hardpoint, "mh_inactive_idle" )
		entity hardpoint = CreatePropDynamic( $"models/communication/terminal_com_station.mdl", spawnpoint.GetOrigin(), spawnpoint.GetAngles(), 6 )
		file.hardpointseatA[hardpoint] <- hardpoint
        file.hardpointseatB[hardpoint] <- hardpoint
        file.hardpointseatC[hardpoint] <- hardpoint
        file.hardpointseatD[hardpoint] <- hardpoint
		entity coolerhardpoint = CreateEntity( "prop_script" )
		DispatchSpawn( coolerhardpoint )
		coolerhardpoint.SetOwner( hardpoint )
		coolerhardpoint.SetParent( hardpoint, "ORIGIN" )
		if( group == "A" )
		file.hardpointA = coolerhardpoint
		if( group == "B" )
		file.hardpointB = coolerhardpoint
		if( group == "C" )
		file.hardpointC = coolerhardpoint

		entity trigger = CreateEntity( "prop_script" )
		DispatchSpawn( trigger )
		trigger.SetParent( hardpoint, "ORIGIN" )
		thread SpawnHardpointMinimapIcon( trigger, spawnpoint.GetHardpointID() + 1, hardpoint )
		entity enemytrigger = CreateEntity( "prop_script" )
		DispatchSpawn( enemytrigger )
		enemytrigger.SetParent( hardpoint, "ORIGIN" )
		thread SpawnHardpointMinimapIcon( enemytrigger, spawnpoint.GetHardpointID() + 1, hardpoint, true )

		file.hardpoints.append( hardpoint )
	}
}

string function GetHardpointGroup(entity hardpoint) //Hardpoint Entity B on Homestead is missing the Hardpoint Group KeyValue
{
	if((GetMapName()=="mp_homestead")&&(!hardpoint.HasKey("hardpointGroup")))
		return "B"

	return string(hardpoint.kv.hardpointGroup)
}

void function SpawnHardpointMinimapIcon( entity spawnpoint, int miniMapObjectHardpoint, entity hardpoint, bool usedasenemymapicon = false )
{
spawnpoint.EndSignal( "OnDestroy" )
spawnpoint.EndSignal( "OnDeath" )
 while( true )
 {
	// map hardpoint id to eMinimapObject_info_hardpoint enum id
	//int miniMapObjectHardpoint = spawnpoint.GetHardpointID() + 1

	spawnpoint.Minimap_SetCustomState( miniMapObjectHardpoint )
	if( usedasenemymapicon == false || hardpoint.GetTeam() != TEAM_MILITIA )
	spawnpoint.Minimap_AlwaysShow( TEAM_MILITIA, null )
	if( usedasenemymapicon == false || hardpoint.GetTeam() != TEAM_IMC )
	spawnpoint.Minimap_AlwaysShow( TEAM_IMC, null )
	if( usedasenemymapicon == true )
	{
	if( hardpoint.GetTeam != TEAM_IMC )
	spawnpoint.Minimap_Hide( TEAM_IMC, null )
	if( hardpoint.GetTeam != TEAM_MILITIA )
	spawnpoint.Minimap_Hide( TEAM_MILITIA, null )
	}
	if( usedasenemymapicon == false )
	{
	if( hardpoint.GetTeam == TEAM_IMC )
	spawnpoint.Minimap_Hide( TEAM_IMC, null )
	if( hardpoint.GetTeam == TEAM_MILITIA )
	spawnpoint.Minimap_Hide( TEAM_MILITIA, null )
	}
	spawnpoint.Minimap_SetAlignUpright( true )

	if( usedasenemymapicon == false )
	SetTeam( spawnpoint, hardpoint.GetTeam() )
	if( usedasenemymapicon == true && (hardpoint.GetTeam() == TEAM_MILITIA || hardpoint.GetTeam() == TEAM_IMC) )
	SetTeam( spawnpoint, GetOtherTeam( hardpoint.GetTeam() ) )
	WaitFrame()
 }
}

void function HardpointThink()
{
 while( true )
 {
  if( GetGameState() != eGameState.Playing )
  return
  foreach( entity hardpoint in file.hardpoints )
  {
   if( IsValid( hardpoint ) )
   {
    int closeplayermilitia = 0
	int closeplayerimc = 0
	int closenpcmilitia = 0
	int closenpcimc = 0
	string message = "Hardpoint at "
	if( hardpoint in file.hardpointprogress )
	message = message + file.hardpointprogress[hardpoint] + "%"
    foreach( entity playerarray in GetPlayerArray() )
    {
	 if( IsValid( playerarray ) )
	 {
	  if( IsAlive( playerarray ) )
	  {
       int playersteam = playerarray.GetTeam()
       if( Distance( playerarray.GetOrigin(), hardpoint.GetOrigin() ) <= 250 && !playerarray.IsTitan() )
	   {
	    int pointstoadd = 1
	    if( playersteam == TEAM_MILITIA )
	    closeplayermilitia = closeplayermilitia + pointstoadd
	    if( playersteam == TEAM_IMC )
	    closeplayerimc = closeplayerimc + pointstoadd
		SendHudMessage( playerarray, message, -1, 0.4, 255, 255, 255, 255, 0.0, 0.5, 0.5 )
	   }
	  }
	 }
	}
	if( file.hardpointseatA[hardpoint] != hardpoint )
	{
	 if( IsValid( file.hardpointseatA[hardpoint] ) )
	 {
	 if( file.hardpointseatA[hardpoint].GetTeam() == TEAM_MILITIA )
	 closeplayermilitia = closeplayermilitia + 1
	 else
	 closeplayerimc = closeplayerimc + 1
	 }
	}
	if( file.hardpointseatB[hardpoint] != hardpoint )
	{
	 if( IsValid( file.hardpointseatB[hardpoint] ) )
	 {
	 if( file.hardpointseatB[hardpoint].GetTeam() == TEAM_MILITIA )
	 closeplayermilitia = closeplayermilitia + 1
	 else
	 closeplayerimc = closeplayerimc + 1
	 }
	}
	if( file.hardpointseatC[hardpoint] != hardpoint )
	{
	 if( IsValid( file.hardpointseatC[hardpoint] ) )
	 {
	 if( file.hardpointseatC[hardpoint].GetTeam() == TEAM_MILITIA )
	 closeplayermilitia = closeplayermilitia + 1
	 else
	 closeplayerimc = closeplayerimc + 1
	 }
	}
	if( file.hardpointseatD[hardpoint] != hardpoint )
	{
	 if( IsValid( file.hardpointseatD[hardpoint] ) )
	 {
	 if( file.hardpointseatD[hardpoint].GetTeam() == TEAM_MILITIA )
	 closeplayermilitia = closeplayermilitia + 1
	 else
	 closeplayerimc = closeplayerimc + 1
	 }
	}
	int pointstoaddtoprogress = 0
	int teamprogresstoremove = 0
	int teamtoprogressto = 0
    if( closeplayerimc - closeplayermilitia > 0 )
	{
    teamtoprogressto = TEAM_IMC
	pointstoaddtoprogress = closeplayerimc - closeplayermilitia
	}
    if( closeplayermilitia - closeplayerimc > 0 )
	{
    teamtoprogressto = TEAM_MILITIA
	pointstoaddtoprogress = closeplayermilitia - closeplayerimc
	}
	if( hardpoint in file.hardpointprogressteam )
	{
	if( file.hardpointprogressteam[hardpoint] != 0 )
	teamprogresstoremove = GetOtherTeam( file.hardpointprogressteam[hardpoint] )
	}
    int hardpointprogress = 0
    if( hardpoint in file.hardpointprogress )
    hardpointprogress = file.hardpointprogress[hardpoint]
    if( hardpointprogress <= 0 )
    file.hardpointprogressteam[hardpoint] <- teamtoprogressto
	if( hardpointprogress <= 0 && hardpoint.GetTeam() != 0 )
	SetTeam( hardpoint, 0 )
	if( teamprogresstoremove != teamtoprogressto )
	hardpointprogress = hardpointprogress + pointstoaddtoprogress
	if( teamprogresstoremove == teamtoprogressto )
	file.hardpointprogress[hardpoint] <- hardpointprogress - pointstoaddtoprogress
    if( hardpointprogress > 100 )
    hardpointprogress = 100
	if( hardpointprogress < 0 )
	hardpointprogress = 0
    if( teamtoprogressto != 0 && teamtoprogressto != teamprogresstoremove )
    file.hardpointprogress[hardpoint] <- hardpointprogress
    if( hardpointprogress == 100 && teamtoprogressto != 0 && teamprogresstoremove != teamtoprogressto )
    SetTeam( hardpoint, teamtoprogressto )
    //print( hardpointprogress )
   }
  }
  WaitFrame()
 }
}

void function HardpointPointsThink()
{
 while( true )
 {
  if( GetGameState() != eGameState.Playing )
  return
  foreach( entity hardpoint in file.hardpoints )
  {
   int hardpointteam = hardpoint.GetTeam()
   if( hardpointteam == TEAM_MILITIA || hardpointteam == TEAM_IMC )
   {
   int teamScore = 1
   if ( GameRules_GetTeamScore(hardpointteam) + teamScore > GetScoreLimit_FromPlaylist() )
   teamScore = GetScoreLimit_FromPlaylist() - GameRules_GetTeamScore(hardpointteam)
   AddTeamScore( hardpointteam, teamScore )
   }
  }
  wait 1.5
 }
}

string function GetLowestNPCCountHardpoint( int team, string nexthardpointtarget )
{
int hardpointAnpccount = 0
int hardpointBnpccount = 0
int hardpointCnpccount = 0
if( team in file.hardpointAnpccount )
hardpointAnpccount = file.hardpointAnpccount[team]
if( team in file.hardpointBnpccount )
hardpointBnpccount = file.hardpointBnpccount[team]
if( team in file.hardpointCnpccount )
hardpointCnpccount = file.hardpointCnpccount[team]
int hardpointtoint = 0
int hardpointtointagain = 0
int hardpointlowestnpccount = 69
array<int> hardpoints
hardpoints.extend([hardpointAnpccount,hardpointBnpccount,hardpointCnpccount])
foreach( int hardpoint in hardpoints )
{
 hardpointtoint = hardpointtoint + 1
 if( hardpoint <= hardpointlowestnpccount )
 {
 hardpointlowestnpccount = hardpoint
 hardpointtointagain = hardpointtoint
 }
}
if( hardpointtointagain == 1 )
return "A"
if( hardpointtointagain == 2 )
return "B"
if( hardpointtointagain == 3 )
return "C"
return nexthardpointtarget
}

void function ChangeHardpointNPCCount( entity npc, string nexthardpointtarget )
{
npc.EndSignal( "OnDestroy" )
npc.EndSignal( "OnDeath" )
npc.EndSignal( "OnLeeched" )
int team = npc.GetTeam()
OnThreadEnd(
	function() : ( team, nexthardpointtarget )
	{
		if( nexthardpointtarget == "A" && team in file.hardpointAnpccount )
	    file.hardpointAnpccount[team] <- file.hardpointAnpccount[team] - 1
		if( nexthardpointtarget == "B" && team in file.hardpointBnpccount )
	    file.hardpointBnpccount[team] <- file.hardpointBnpccount[team] - 1
		if( nexthardpointtarget == "C" && team in file.hardpointCnpccount )
	    file.hardpointCnpccount[team] <- file.hardpointCnpccount[team] - 1
	}
)
WaitForever()
}

void function NPCHardpointSeat( entity npc, entity hardpoint )
{
 while( IsValid( npc ) && IsAlive( npc ) )
 {
  //foreach( entity hardpoint in file.hardpoints )
  //{
   if( IsValid( hardpoint ) )
   {
   bool entityisusinghardpoint = false
   if( npc in file.entityisusinghardpoint )
   entityisusinghardpoint = file.entityisusinghardpoint[npc]
   int hardpointprogress = 0
   if( hardpoint in file.hardpointprogress )
   hardpointprogress = file.hardpointprogress[hardpoint]
   if( hardpointprogress != 100 && !npc.Anim_IsActive() && (!IsValid( npc.GetEnemy() ) && !IsAlive( npc.GetEnemy() ) || Distance( npc.GetOrigin(), npc.GetEnemy().GetOrigin() ) >= 1250) && entityisusinghardpoint == false && npc.GetParent() == null && Distance( npc.GetOrigin(), hardpoint.GetOrigin() ) <= 150 && (file.hardpointseatA[hardpoint] == hardpoint || file.hardpointseatB[hardpoint] == hardpoint || file.hardpointseatC[hardpoint] == hardpoint || file.hardpointseatD[hardpoint] == hardpoint) )
   {
   	 string attachID = ""
	 if ( file.hardpointseatA[hardpoint] == hardpoint )
	 {
		 attachID = "SEAT_N"
		 file.hardpointseatA[hardpoint] <- npc
	 }
	 else if ( file.hardpointseatB[hardpoint] == hardpoint )
	 {
		 attachID = "SEAT_W"
		 file.hardpointseatB[hardpoint] <- npc
	 }
	 else if ( file.hardpointseatC[hardpoint] == hardpoint )
	 {
		 attachID = "SEAT_S"
		 file.hardpointseatC[hardpoint] <- npc
	 }
	 else if ( file.hardpointseatD[hardpoint] == hardpoint )
	 {
		 attachID = "SEAT_E"
		 file.hardpointseatD[hardpoint] <- npc
	 }
	 if( attachID != "" )
	 {
	 array<string> sittingAnims = [ "pt_console_runin_R", "pt_console_runin_L" ]
	 file.entityisusinghardpoint[npc] <- true
	 entityisusinghardpoint = true
	 npc.EndSignal( "OnDestroy" )
     npc.EndSignal( "OnDeath" )
	 OnThreadEnd( function() : ( npc, hardpoint, attachID ) 
	 {
	  if( IsValid( hardpoint ) )
      {
	   if( !IsValid( npc ) || !IsAlive( npc ) )
	   {
       if( attachID == "SEAT_N" )
	   file.hardpointseatA[hardpoint] <- hardpoint
       if( attachID == "SEAT_W" )
	   file.hardpointseatB[hardpoint] <- hardpoint
       if( attachID == "SEAT_S" )
	   file.hardpointseatC[hardpoint] <- hardpoint
       if( attachID == "SEAT_E" )
	   file.hardpointseatD[hardpoint] <- hardpoint
	   }
      }
	 })
	 npc.SetVelocity( < 0, 0, 0 > )
	 npc.SetParent( hardpoint, attachID )
	 npc.SetCanBeMeleeExecuted( false )
	 waitthread PlayAnimGravity( npc, sittingAnims.getrandom(), hardpoint, attachID )
	 npc.SetVelocity( < 0, 0, 0 > )
	 thread PlayAnimGravity( npc, "pt_console_idle", hardpoint, attachID )
	  while( entityisusinghardpoint == true )
	  {
	   int hardpointprogress = 0
	   if( hardpoint in file.hardpointprogress )
	   hardpointprogress = file.hardpointprogress[hardpoint]
	   if( hardpointprogress == 100 || (IsValid( npc.GetEnemy() ) && IsAlive( npc.GetEnemy() ) && Distance( npc.GetOrigin(), npc.GetEnemy().GetOrigin() ) < 1250) )
	   {
	   array<string> exitAnims = [ "pt_console_runout_R", "pt_console_runout_L" ]
	   npc.SetVelocity( < 0, 0, 0 > )
	    if( npc.GetParent() != hardpoint )
	    {
	    npc.ClearParent()
	    npc.SetParent( hardpoint, attachID )
	    }
	   waitthread PlayAnimGravity( npc, exitAnims.getrandom(), hardpoint, attachID )
	   if( npc.GetParent() == hardpoint )
	   npc.ClearParent()
       if( attachID == "SEAT_N" )
	   file.hardpointseatA[hardpoint] <- hardpoint
       if( attachID == "SEAT_W" )
	   file.hardpointseatB[hardpoint] <- hardpoint
       if( attachID == "SEAT_S" )
	   file.hardpointseatC[hardpoint] <- hardpoint
       if( attachID == "SEAT_E" )
	   file.hardpointseatD[hardpoint] <- hardpoint
	   thread NPCHardpointSeat( npc, hardpoint )
	   file.entityisusinghardpoint[npc] <- false
	   entityisusinghardpoint = false
	   npc.SetCanBeMeleeExecuted( true )
	   return
	   }
	   WaitFrame()
	  }
	 }
	}
   }
  //}
  WaitFrame()
 }
}

void function OnSpectreLeechedHardpoint( entity spectre, entity player )
{
	spectre.SetOwner( player )
}

/*
Intro
*/

void function Intro()
{
 if( GetMapName() == "mp_angel_city" )
 {
 thread IntroMilitiaAngelCity()
 IntroIMCAngelCity()
 wait 2.5
 }
}

void function IntroMilitiaAngelCity()
{
	entity titan = CreateNPCTitan( "titan_atlas_tracker", TEAM_MILITIA, < -2656.28, 4325.78, 125.575 >, < 0, -16.22, 0 > )
	entity npc = CreateNPC( "npc_soldier", TEAM_MILITIA, < 0, 0, 0 >, < 0, 0, 0 > )
	DispatchSpawn( titan )
	DispatchSpawn( npc )
	#if TITANFALL1_MODEL
	titan.SetModel($"models/titans/atlas/atlas_titan.mdl")
	thread OnTitanBodyGroupChange( titan )
	#endif
	#if !TITANFALL1_RANDOM_WEAPON
	TakeWeaponsForArray( titan, titan.GetMainWeapons() )
	titan.GiveWeapon( "mp_titanweapon_sticky_40mm" )
	#endif
	titan.SetTitle( "Captain Hainey" )
	titan.SetInvulnerable()
	npc.SetInvulnerable()
	entity soul = titan.GetTitanSoul()
	if( IsValid( soul ) )
	soul.SetShieldHealth( soul.GetShieldHealthMax() )
	thread KillNPC( npc )
	npc.SetParent( titan, "HAND_R" )
	npc.EnableNPCFlag( NPC_IGNORE_ALL )
	DisableTitanRodeo( titan ) // No Free Batteries
	if( GetCurrentPlaylistVarInt( "classic_mp", 1 ) == 0 )
	{
	foreach( entity player in GetPlayerArray() )
	{
	if( player.GetTeam() == TEAM_MILITIA )
	player.SetOrigin( < -2584.16, 4654.72, 120.031 > )
	}
	}
	waitthread PlayAnim( titan, "at_angelcity_MILITIA_intro" )
	titan.ClearInvulnerable()
	EnableTitanRodeo( titan )
	titan.AssaultPoint( < -902.682, 420.162, 120.031 > )
}

void function IntroIMCAngelCity()
{
	entity titan = CreateNPCTitan( "titan_atlas_vanguard", TEAM_IMC, < 1888, -1384, 128 >, < 0, 0, 0 > )
	DispatchSpawn( titan )
	entity hornet = CreatePropDynamic( $"models/vehicle/hornet/hornet_fighter.mdl", < 1888, -1384, 128 >, < 0, 0, 0 > )
	#if TITANFALL1_MODEL
	titan.SetModel($"models/titans/atlas/atlas_titan.mdl")
	thread OnTitanBodyGroupChange( titan )
	#endif
	#if !TITANFALL1_RANDOM_WEAPON
	TakeWeaponsForArray( titan, titan.GetMainWeapons() )
	titan.GiveWeapon( "mp_titanweapon_xo16_vanguard" )
	#endif
	titan.SetTitle( "Captain Bracken" )
	titan.SetInvulnerable()
	entity soul = titan.GetTitanSoul()
	if( IsValid( soul ) )
	soul.SetShieldHealth( soul.GetShieldHealthMax() )
	DisableTitanRodeo( titan ) // No Free Batteries
	thread InfiniteTitanAmmo( titan )
	thread PlayAnim( hornet, "ht_angelcity_IMC_ground_intro" )
	waitthread PlayAnim( titan, "at_angelcity_IMC_ground_intro" )
	titan.ClearInvulnerable()
	EnableTitanRodeo( titan )
	if( IsValid( hornet ) )
	hornet.Destroy()
	titan.AssaultPoint( < -902.682, 420.162, 120.031 > )
}