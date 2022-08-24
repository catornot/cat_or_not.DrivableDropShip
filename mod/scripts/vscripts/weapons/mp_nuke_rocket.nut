untyped

global function Init_NukeRocket
global function SetupRocketMarvin
global function TryFireNuke
global function DEV_NadeTest

void function Init_NukeRocket()
{
    
}

void function SetupRocketMarvin( DropShiptruct dropship )
{
    entity mover = dropship.dropship.mover
    
    vector origin =  ( mover.GetForwardVector() * 300 ) + mover.GetOrigin()
    entity marvin = CreateMarvin( mover.GetTeam(), origin, mover.GetAngles() )
	DispatchSpawn( marvin )
	marvin.SetInvulnerable()
    marvin.SetParent( mover )
	marvin.SetNoTarget( true )
	marvin.ContextAction_SetBusy()
	HideName( marvin )
	marvin.SetTitle( "dropship" )
	thread PlayAnim( marvin, "commander_MP_flyin_marvin_idle", mover )

    TakeAllWeapons( marvin )
    marvin.GiveWeapon( "mp_titanweapon_rocketeer_rocketstream" )
	marvin.GiveOffhandWeapon( "mp_weapon_frag_grenade", OFFHAND_ORDNANCE, [] )
	marvin.GiveOffhandWeapon( "mp_weapon_satchel", OFFHAND_SPECIAL, [] )
	marvin.SetActiveWeaponByName( "mp_titanweapon_rocketeer_rocketstream" )

	marvin.MakeInvisible()

    dropship.dropship.pilot = marvin
}

void function TryFireNuke( DropShiptruct dropship )
{
	// really jank // not anymore ( I think )
	entity mover = dropship.dropship.mover
	entity owner = dropship.dropship.pilot
	entity player = dropship.dropship.model.GetOwner()
	
	if ( !IsValid( owner ) )
		SetupRocketMarvin( dropship )
	
	owner = dropship.dropship.pilot
	entity weapon = owner.GetActiveWeapon()
	owner.SetAngles( mover.GetAngles() )

    if ( dropship.time_fired > Time() && dropship.gun_type == 0  )
    {
		EmitSoundOnEntityOnlyToPlayer( player, player, "UI_Networks_Invitation_Canceled" )
		return
	}
	else if ( dropship.gun_type == 0 )
		dropship.time_fired = Time() + 3
	
	if ( dropship.time_fired_1 > Time() && dropship.gun_type == 1  )
		return
	else if ( dropship.gun_type == 1 )
		dropship.time_fired_1 = Time() + 0.5

    
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
			
			entity weapon = owner.GetActiveWeapon()
			weapon = owner.GetOffhandWeapon( OFFHAND_SPECIAL )

			entity grenade = weapon.FireWeaponGrenade( attackParams.pos, <0,0,0>, <0,0,-10>, 8000, damageTypes.projectileImpact, damageTypes.explosive, false, true, false )
			grenade.SetScriptName( "nuke" )
			grenade.SetOwner( player )
			thread DoNuclearExplosion( grenade, eDamageSourceId.mp_titancore_nuke_missile )
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
			
			entity weapon = owner.GetActiveWeapon()
			weapon = owner.GetOffhandWeapon( OFFHAND_ORDNANCE )

			entity grenade = weapon.FireWeaponGrenade( attackParams.pos, <0,0,0>, <0,0,-10>, 0.1, damageTypes.projectileImpact, damageTypes.explosive, false, true, false )
			grenade.SetOwner( player )
		}
	)

	float life = float( missile.kv.lifetime ) + Time()

	while( life > Time() )
	{
		attackParams.pos = missile.GetOrigin()
		WaitFrame()
	}
}

void function DEV_NadeTest()
{
	entity player = GetPlayerByIndex(0)
	entity weapon = player.GetOffhandWeapon( OFFHAND_ORDNANCE )

	entity grenade = weapon.FireWeaponGrenade( player.GetOrigin(), <0,0,0>, <0,0,0>, 0, damageTypes.projectileImpact, damageTypes.explosive, false, true, false )
	thread DoNuclearExplosion( grenade, eDamageSourceId.mp_titancore_nuke_missile )
}