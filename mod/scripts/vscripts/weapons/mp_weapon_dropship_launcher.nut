untyped

global function DropShipMainAttack_Init
global function SetupWeaponMarvin
global function TryFireMissle
global function TryFireBullet
global function TryFireBombs
global function DEV_NadeTest


void function DropShipMainAttack_Init()
{
    
}

void function SetupWeaponMarvin( DropShiptruct dropship, int shipType )
{
    entity mover = dropship.dropship.mover
	entity player = dropship.dropship.model.GetOwner()
    
    vector origin =  ( mover.GetForwardVector() * 300 ) + mover.GetOrigin()
    entity marvin = CreateMarvin( mover.GetTeam(), origin, mover.GetAngles() )
	DispatchSpawn( marvin )
	marvin.SetInvulnerable()
    marvin.SetParent( mover )
	marvin.SetNoTarget( true )
	marvin.ContextAction_SetBusy()
	marvin.SetOwner( player )
	HideName( marvin )
	marvin.SetTitle( "dropship" )
	thread PlayAnim( marvin, "commander_MP_flyin_marvin_idle", mover )

    TakeAllWeapons( marvin )
	if( shipType == eDrivableShipType.GunShip )
	{
		marvin.GiveWeapon( "mp_titanweapon_sticky_40mm" )
		marvin.GiveWeapon( "mp_weapon_defender" )
		marvin.SetBossPlayer( player ) // so hitscan weapons' kills will count as player's kills
	}
	else
	{
		marvin.GiveWeapon( "mp_titanweapon_rocketeer_rocketstream" )
		marvin.GiveWeapon( "mp_weapon_softball" )
		marvin.GiveOffhandWeapon( "mp_weapon_frag_grenade", OFFHAND_ORDNANCE, [] )
		marvin.GiveOffhandWeapon( "mp_weapon_satchel", OFFHAND_SPECIAL, [] )
		marvin.SetActiveWeaponByName( "mp_titanweapon_rocketeer_rocketstream" )
	}

	marvin.MakeInvisible()

    dropship.dropship.pilot = marvin
}

void function TryFireMissle( DropShiptruct dropship )
{
	// really jank // not anymore ( I think )
	entity mover = dropship.dropship.mover
	entity owner = dropship.dropship.pilot
	entity player = dropship.dropship.model.GetOwner()
	int shipType = dropship.shipType
	
	if ( !IsValid( owner ) )
		SetupWeaponMarvin( dropship, shipType )
	
	owner = dropship.dropship.pilot
	entity weapon = owner.GetActiveWeapon()
	owner.SetAngles( mover.GetAngles() )

    if ( dropship.time_fired > Time() && dropship.gun_type == eDrivableShipWeapon.Nuke )
		return
	else if ( dropship.gun_type == eDrivableShipWeapon.Nuke )
		dropship.time_fired = Time() + 3


	if ( dropship.time_fired > Time() && dropship.gun_type == eDrivableShipWeapon.Missile )
		return
	else if ( dropship.gun_type == eDrivableShipWeapon.Missile )
		dropship.time_fired = Time() + 0.5

    
    weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	bool shouldPredict = weapon.ShouldPredictProjectiles()

    WeaponPrimaryAttackParams attackParams
    attackParams.pos = mover.GetOrigin() + ( mover.GetForwardVector() * 400 ) + ( mover.GetUpVector() * -100 )
    attackParams.dir = mover.GetForwardVector() * 1000


	vector attackDir = attackParams.dir
	vector attackPos = attackParams.pos
	attackDir = Normalize( attackDir )
	entity missile = weapon.FireWeaponMissile( attackPos, attackDir, 3000, (damageTypes.projectileImpact | DF_DOOM_FATALITY), damageTypes.explosive, false, shouldPredict )
	EmitSoundAtPosition( owner.GetTeam(), mover.GetOrigin(), "Weapon_FlightCore_Incoming_Projectile" )

	if ( missile )
	{
		TraceResults result = TraceLine( attackParams.pos, attackParams.pos + attackParams.dir*50000, [ owner ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_BLOCK_WEAPONS )
		missile.kv.lifetime = 30
		attackParams.pos = result.endPos
		missile.InitMissileForRandomDriftFromWeaponSettings( attackPos, attackDir )
		missile.SetSpeed( 100 )
		missile.SetOwner( owner )
		EmitSoundAtPosition( owner.GetTeam(), attackParams.pos, "Weapon_FlightCore_Incoming_Projectile" )
		
		if ( dropship.gun_type == 0 )
			thread NukeMissileThink( missile, owner, player, attackParams )
		else
			thread MissileThink( missile, owner, player, attackParams )
    }
}

void function TryFireBullet( DropShiptruct dropship )
{
	entity mover = dropship.dropship.mover
	entity owner = dropship.dropship.pilot
	entity player = dropship.dropship.model.GetOwner()
	int shipType = dropship.shipType
	
	if ( !IsValid( owner ) )
		SetupWeaponMarvin( dropship, shipType )
	
	owner = dropship.dropship.pilot
	entity weapon
	if( dropship.gun_type == eDrivableShipWeapon.Gun )
		weapon = owner.GetMainWeapons()[0]
	if( dropship.gun_type == eDrivableShipWeapon.Lazer )
		weapon = owner.GetMainWeapons()[1]

	owner.SetAngles( mover.GetAngles() )

	if( !IsValid( weapon ) )
		return

    if ( dropship.time_fired > Time() && dropship.gun_type == eDrivableShipWeapon.Gun )
		return
	else if ( dropship.gun_type == eDrivableShipWeapon.Gun )
		dropship.time_fired = Time() + 0.2

	if ( dropship.time_fired > Time() && dropship.gun_type == eDrivableShipWeapon.Lazer  )
		return
	else if ( dropship.gun_type == eDrivableShipWeapon.Lazer )
		dropship.time_fired = Time() + 0.8

    
    weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	bool shouldPredict = weapon.ShouldPredictProjectiles()

    WeaponPrimaryAttackParams attackParams
    attackParams.pos = mover.GetOrigin() + ( mover.GetForwardVector() * 400 ) + ( mover.GetUpVector() * -100 )
    attackParams.dir = mover.GetForwardVector() * 1000

	vector attackDir = attackParams.dir
	vector attackPos = attackParams.pos
	attackDir = Normalize( attackDir )

	if ( dropship.gun_type == eDrivableShipWeapon.Gun )
	{
		entity bolt = weapon.FireWeaponBolt( attackPos, attackDir, 8000, damageTypes.gibBullet | DF_IMPACT | DF_EXPLOSION | DF_RAGDOLL | DF_KNOCK_BACK, DF_EXPLOSION | DF_RAGDOLL | DF_KNOCK_BACK, false , 0 )
		EmitSoundAtPosition( owner.GetTeam(), mover.GetOrigin(), "Weapon_40mm_Fire_3P" )
		if( bolt )
		{
			bolt.SetOwner( player )
		}
	}
	if ( dropship.gun_type == eDrivableShipWeapon.Lazer )
	{
		weapon.FireWeaponBullet( attackPos, attackDir, 1, weapon.GetWeaponDamageFlags() )
		EmitSoundAtPosition( owner.GetTeam(), mover.GetOrigin(), "Weapon_ChargeRifle_Fire_3P" )
		vector traceEnd = attackPos + attackDir * 56756 //max length
		TraceResults result = TraceLine( attackPos, traceEnd, [], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )
		CreateWeaponTracer( attackPos , result.endPos ,0.05 )
	}
}

void function TryFireBombs( DropShiptruct dropship )
{
	entity mover = dropship.dropship.mover
	entity owner = dropship.dropship.pilot
	entity player = dropship.dropship.model.GetOwner()
	
	if ( !IsValid( owner ) )
		SetupWeaponMarvin( dropship, dropship.shipType )
	
	owner = dropship.dropship.pilot

	entity weapon = owner.GetOffhandWeapon( OFFHAND_SPECIAL )
	if( !IsValid( weapon ) )
		return

	if ( dropship.time_fired > Time() )
		return
	else 
		dropship.time_fired = Time() + 1.0

	vector attackPos = mover.GetOrigin() + ( mover.GetForwardVector() * 400 ) + ( mover.GetUpVector() * -100 )
	
	vector attackDir = AnglesToForward( < mover.GetAngles().x, mover.GetAngles().y, 0.0 > ) * 100 + <0,0,-300>

	entity grenade = weapon.FireWeaponGrenade( attackPos, attackDir, attackDir, 1, damageTypes.projectileImpact, damageTypes.explosive, false, true, false )
	
	if( grenade )
	{
		grenade.SetScriptName( "nuke" )
		grenade.SetOwner( player )
		grenade.ClearBossPlayer()
		SetTeam( grenade, player.GetTeam() )

		thread BombThink( grenade, player )
	}

	
}

void function CreateWeaponTracer( vector startPos, vector endPos, float lifeDuration, asset tracerAsset = $"P_wpn_hand_laser_beam_BC" )
{
	entity cpEnd = CreateEntity( "info_placement_helper" )
	cpEnd.SetOrigin( endPos )
	SetTargetName( cpEnd, UniqueString( "arc_cannon_beam_cpEnd" ) )
	DispatchSpawn( cpEnd )

	entity tracer = CreateEntity( "info_particle_system" )
	tracer.kv.cpoint1 = cpEnd.GetTargetName()

	tracer.SetValueForEffectNameKey( tracerAsset )

	tracer.kv.start_active = 1
	tracer.SetOrigin( startPos )

	DispatchSpawn( tracer )

	tracer.Fire( "Start" )
	tracer.Fire( "StopPlayEndCap", "", lifeDuration )
	tracer.Kill_Deprecated_UseDestroyInstead( lifeDuration )
	cpEnd.Kill_Deprecated_UseDestroyInstead( lifeDuration )

}

void function NukeMissileThink( entity missile, entity owner, entity player, WeaponPrimaryAttackParams attackParams )
{
	missile.EndSignal( "OnDestroy" )

	attackParams.pos = missile.GetOrigin()

	OnThreadEnd(
		function() : ( missile, owner, player, attackParams )
		{
			if ( IsValid( missile ) )
				missile.Destroy()
			
			if ( !IsValid( owner ) || !IsValid( player ) )
				return
			
			//entity weapon = owner.GetActiveWeapon()
			//weapon = owner.GetOffhandWeapon( OFFHAND_SPECIAL )
			entity weapon = owner.GetOffhandWeapon( OFFHAND_SPECIAL )
			if( !IsValid( weapon ) )
				return

			entity grenade = weapon.FireWeaponGrenade( attackParams.pos, <0,0,0>, <0,0,-10>, 800, damageTypes.projectileImpact, damageTypes.explosive, false, true, false )
			if( grenade )
			{
				grenade.SetScriptName( "nuke" )
				grenade.SetOwner( player )
				thread DoNuclearExplosion( grenade, eDamageSourceId.mp_titancore_nuke_missile )
			}
		}
	)

	float life = float( missile.kv.lifetime ) + Time()

	while( life > Time() )
	{
		attackParams.pos = missile.GetOrigin()
		WaitFrame()
	}
}

void function MissileThink( entity missile, entity owner, entity player, WeaponPrimaryAttackParams attackParams )
{
	missile.EndSignal( "OnDestroy" )

	attackParams.pos = missile.GetOrigin()

	OnThreadEnd(
		function() : ( missile, owner, player, attackParams )
		{
			if ( IsValid( missile ) )
				missile.Destroy()
			
			if ( !IsValid( owner ) || !IsValid( player ) )
				return
			
			//entity weapon = owner.GetActiveWeapon()
			//weapon = owner.GetOffhandWeapon( OFFHAND_ORDNANCE )
			entity weapon = owner.GetMainWeapons()[1]
			if( !IsValid( weapon ) )
				return

			entity grenade = weapon.FireWeaponGrenade( attackParams.pos, <0,0,0>, <0,0,-10>, 0.1, damageTypes.projectileImpact, damageTypes.explosive, false, true, false )
			if( grenade )
			{
				grenade.SetOwner( player )
				grenade.ClearBossPlayer()
			}
		}
	)

	float life = float( missile.kv.lifetime ) + Time()

	while( life > Time() )
	{
		attackParams.pos = missile.GetOrigin()
		WaitFrame()
	}
}

void function BombThink( entity bomb, entity owner )
{
	int team = owner.GetTeam()
	bomb.EndSignal( "OnDestroy" )
	bomb.EndSignal( "Planted" )
	
	OnThreadEnd(
		function() : ( team, bomb, owner )
		{
			if ( !IsValid( bomb ) )
				return

			vector origin = bomb.GetOrigin()

			entity inflictor = CreateExplosionInflictor( origin )
				
			entity explosionOwner
			if ( IsValid( owner ) )
				explosionOwner = owner
			else
				explosionOwner = GetTeamEnt( team )
			
			foreach( int dist in [300,400,500] )
				RadiusDamage_DamageDefSimple(
					damagedef_fd_explosive_barrel,
					origin,								// origin
					explosionOwner,						// owner
					inflictor,							// inflictor
					dist )								// dist from attacker
			
		}
	)

	bomb.WaitSignal( "Planted" )
}

void function DEV_NadeTest()
{
	entity player = GetPlayerByIndex(0)
	entity weapon = player.GetOffhandWeapon( OFFHAND_ORDNANCE )

	entity grenade = weapon.FireWeaponGrenade( player.GetOrigin(), <0,0,0>, <0,0,0>, 0, damageTypes.projectileImpact, damageTypes.explosive, false, true, false )
	thread DoNuclearExplosion( grenade, eDamageSourceId.mp_titancore_nuke_missile )
}