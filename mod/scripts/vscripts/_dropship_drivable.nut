global function SpawnDrivableDropShip
global function DEV_SpawnDrivableDropShip

global function DropShipDied

global struct DropShiptruct
{
    ShipStruct& dropship
    entity mover
    entity camera
    entity panel
    float acceleration = 0.0
    float time_enter = 0.0
    float time_sound = 0.0
    float time_fired = 0.0
    float time_fired_1 = 0.0
    float time_cam = 0.0
    int cam_state = 0
    int gun_type = 0
    float time_gun_switch = 0.0
    string shipType // gunship, dropship
    entity crosshair
    entity laser
}

const float drop_ship_base_speed = 1000.0
const int base_rotation = 20
const flight_limit = 10000

const DRIVABLE_DROPSHIP_HEALTH = 3500
const DRIVABLE_GUNSHIP_HEALTH = 4000

/*
███████╗███████╗████████╗██╗   ██╗██████╗ 
██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
███████╗█████╗     ██║   ██║   ██║██████╔╝
╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ 
███████║███████╗   ██║   ╚██████╔╝██║     
╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     
                                          
*/

DropShiptruct function SpawnDrivableDropShip( vector origin, vector angles = CONVOYDIR, int team = TEAM_IMC, string shipType = "dropship" )
{
    InitKeyTracking()

    DropShiptruct dropship

    ShipStruct ship = SpawnDropShipLight( WorldToLocalOrigin( origin ), angles, team, true, shipType == "gunship" ? true : false )
    ship.behavior = eBehavior.CUSTOM
    
    ship.mover.SetPusher( true )
    ship.model.SetPusher( true )

    dropship.shipType = shipType
    int curShipHealth = DRIVABLE_DROPSHIP_HEALTH
    if( shipType == "gunship" )
    {
        curShipHealth = DRIVABLE_GUNSHIP_HEALTH
        // if ( team == TEAM_IMC ) // TODO: make this work
        // {
        ship.model.SetModel( $"models/vehicle/straton/straton_imc_gunship_01.mdl" )
        ship.model.SetValueForModelKey( $"models/vehicle/straton/straton_imc_gunship_01.mdl" )
        // }
        // else 
        // {
        //     ship.model.SetModel( $"models/vehicle/hornet/hornet_fighter.mdl" )
        //     ship.model.SetValueForModelKey( $"models/vehicle/hornet/hornet_fighter.mdl" )
        // }
    }
    if( shipType == "dropship" )
        thread PlayAnim( ship.model, "dropship_open_doorL", dropship.dropship.mover )

    ship.model.SetMaxHealth( curShipHealth )
	ship.model.SetHealth( ship.model.GetMaxHealth() )
    ship.model.SetUsableByGroup( "pilot" )
    ship.model.SetUsePrompts( "Hold %use% to embark", "Press %use% to embark" )
    

    ship.model.SetTitle( "dropship" )
    ship.model.SetScriptName( "drivable_dropship" )
    ShowName( ship.model )
    dropship.dropship = ship

    // vector origin = ship.mover.GetForwardVector() * 250
    // origin += ship.mover.GetUpVector() * -70
    // origin += ship.mover.GetOrigin()

    // entity turret = CreateNPC( "npc_turret_sentry", TEAM_BOTH, origin, <180,180,0> + ship.model.GetAngles() )
    // SetSpawnOption_AISettings( turret, "npc_turret_sentry" )
    // DispatchSpawn( turret )
    // HideName( turret )
    // turret.SetParent( ship.mover )
    // turret.EnableTurret()
    // dropship.panel = turret // placeholder

    // SetupRocketMarvin( dropship )
    // SetupDropshipTurret( dropship )

    thread DropShipWaitForDriver( dropship )
    
    return dropship
}

void function DropShipWaitForDriver( DropShiptruct dropship )
{
    entity model = dropship.dropship.model
    model.SetUsable()
    model.SetOwner( null )
    StopSoundOnEntity( model, "amb_emit_s2s_rushing_wind_strong_v2_02b" )
    StopSoundOnEntity( model, "amb_emit_s2s_distant_ambient_ships" )
    dropship.cam_state = 0

    // if ( IsValid( dropship.panel ) )
    //     dropship.panel.DisableTurret()

    entity player = expect entity( model.WaitSignal( "OnPlayerUse" ).player )

    model.UnsetUsable()

    if ( IsValid( model.GetOwner() ) || model.GetOwner() == player )
        return
    
    if ( !IsValid( player ) || player.IsTitan() || IsValid( player.GetParent() ) )
    {
        thread DropShipWaitForDriver( dropship )
        return
    }
        
    SendHudMessage( player, "Drive the Ship：\nPress 'JUMP' to Speed up, 'CROUCH' to Slow down\n'BOOST' to Switch Weapons, 'TACTICAL' to Toggle First Person" , -1, -0.2, 255, 255, 0, 255, 0.15, 10, 1 )
    dropship.time_enter = Time()
    SpawnDropshipCamera( player, dropship )
    SpawnDropShipCrosshair( dropship )
    player.SetOrigin( dropship.mover.GetOrigin() + <0,0,50> )
    player.SetParent( dropship.mover )
    player.MakeInvisible()
    player.SetInvulnerable()
    dropship.dropship.mover.SetOwner( player )
    ScreenFade( player, 0, 0, 0, 255, 0.3, 0.3, (FFADE_IN | FFADE_PURGE) )

    // if ( IsValid( dropship.panel ) )
    // {
    //     dropship.panel.EnableTurret()
    //     dropship.panel.SetOwner( player )
    //     SetTeam( dropship.panel, player.GetTeam() )
    // }

    thread DropShipDrive( dropship )
}

void function DropShipDrive( DropShiptruct dropship )
{
    ShipStruct ship = dropship.dropship
    entity mover = ship.mover
    entity model = ship.model
    entity player = model.GetOwner()

    player.EndSignal( "OnDeath" )
    player.EndSignal( "OnDestroy" )
    model.EndSignal( "OverDamaged" )
    EndSignal( ship, "engineFailure_Complete" )
    model.EndSignal( "OnDeath" )
    model.EndSignal( "OnDestroy" )

    OnThreadEnd(
		function () : ( dropship, ship, model )
		{
            print( "dropship driving loop is over" )
            print( "player :" + model.GetOwner() )
            print( "location :" + model.GetOrigin() )
            print( "health :" + model.GetHealth() )
            print( "did colide :" + DidColide( dropship ) )
            print( "behavior :" + ship.behavior )
			if ( !IsValid( model ) || model.GetHealth() < 10 || DidColide( dropship ) || ship.behavior == eBehavior.DEATH_ANIM || ship.behavior == eBehavior.ENGINE_FAILURE )
                thread DropShipDied( dropship, model )
            else if ( !IsValid( model.GetOwner() ) || !IsAlive( model.GetOwner() ) )
                HandlePlayerDeathInDropship( dropship, model )
            else if ( IsValid( model.GetOwner() ) )
                HandleExitRequest( dropship, model.GetOwner() )
		}
	)

    vector angles
    vector attack_angles
    vector thing
    array< bool > keys

    for(;;)
    {
        if ( ship.behavior == eBehavior.DEATH_ANIM )
            return
        
        thing = mover.GetOrigin()
        if ( thing.x > flight_limit || thing.x < -flight_limit || thing.y > flight_limit || thing.y < -flight_limit || thing.z > flight_limit - 3000 || thing.z < -flight_limit + 3000 )
            model.TakeDamage( model.GetHealth() - 1, null, null, { damageSourceId=damagedef_suicide } )

        keys = GetPlayerKeysList( player )

        if ( keys[KJ] )
        {
            IncreaseAcceleration( dropship )
        }
        else if ( keys[KD] ) 
        {
            DecreaseAcceleration( dropship )
        }

        if ( HasEnoughSpeed( dropship ) )
        {
            MoveDropShip( dropship, mover.GetForwardVector() )
        }

        
        if ( DidColide( dropship ) )
        {
            if ( true || GetAcceleration( dropship ) > 0.50 ) // currently the dropship just poofs with no sfx if this is false
            {
                model.TakeDamage( model.GetHealth() - 1, null, null, { damageSourceId=damagedef_suicide } )
                model.Signal( "OverDamaged" )
            }
            else
            {
                dropship.acceleration = -dropship.acceleration
                MoveDropShip( dropship, mover.GetForwardVector() * -300 )
                return
            }
        }
            
        
        angles = <0,0,0>
        attack_angles = mover.GetAngles()
        
        if ( dropship.cam_state == 2 )
        {
            vector pangles = player.EyeAngles()

            pangles.x = pangles.x - attack_angles.x
            pangles.x = ( pangles.x + 180 ) % 360 - 180
            pangles.y = pangles.y - attack_angles.y
            pangles.y = ( pangles.y + 180 ) % 360 - 180

            // print( " before : player: " + pangles + ", ship: " + attack_angles )
            
            // pangles.y = pangles.y.tointeger().tofloat()
            // pangles.x = pangles.x.tointeger().tofloat()
            // pangles += <360,360,0>

            attack_angles = <0,0,0>
            
            // print( "after : player: " + pangles + ", ship: " + attack_angles )
            // pain

            if ( abs( ( pangles.y - attack_angles.y ).tointeger() ) < 10 )
            {
                //hehe
            }
            else if ( pangles.y.tointeger() < attack_angles.y )
            {
                angles.y = -base_rotation
            }
            else
            {
                angles.y = base_rotation
            }
            
            if ( abs( ( pangles.x - attack_angles.x ).tointeger() ) < 10 )
            {
                //hehe
            }
            else if ( pangles.x.tointeger() < attack_angles.x.tointeger() )
            {
                angles.x = -base_rotation
            }
            else
            {
                angles.x = base_rotation
            }
        }

        if ( keys[KL] )
        {
            angles.y = base_rotation
        }
        else if ( keys[KR] )
        {
            angles.y = -base_rotation
        }

        if ( keys[KB] && attack_angles.x > -50 )
        {
            // thing = mover.GetUpVector() * -base_rotation
            // angles += thing
            angles.x = -base_rotation
        }
        else if ( keys[KF] && attack_angles.x < 50 )
        {
            // thing = mover.GetUpVector() * base_rotation
            // angles += thing
            angles.x = base_rotation
        }

        RotateDropShip( dropship, angles )

        if ( keys[KO4] )
            SwitchWepon( dropship )  

        if ( keys[KO0] )
        {
            if( dropship.shipType == "gunship" )
                TryFireBullet( dropship )
            else
                TryFireMissle( dropship )
        }
        
        if ( dropship.time_cam > Time() )
            keys[KO1] = false
        else if ( keys[KO1] )
            dropship.time_cam = Time() + 0.5

        if ( keys[KO1] && !HasEnoughSpeed( dropship ) && dropship.cam_state <= 2 )
            dropship.cam_state += 1

        UpdatedCameraPosition( dropship )
        UpdateDropshipCrosshair( dropship )
        //DisplayHealthToDriver( dropship )

        if ( dropship.time_sound < Time() ) // add hover and flight sounds
        {
            StopSoundOnEntity( model, "amb_emit_s2s_distant_ambient_ships" )
            EmitSoundOnEntity( model, "amb_emit_s2s_rushing_wind_strong_v2_02b" )
            EmitSoundOnEntity( model, "amb_emit_s2s_distant_ambient_ships" )
            dropship.time_sound = Time() + 10
        }

        if ( dropship.time_enter < Time() - 1 && keys[KU] )
            return
        
        WaitFrame()
    }
}

void function DropShipDied( DropShiptruct dropship, entity model )
{
    vector origin = dropship.dropship.mover.GetOrigin()
    entity player = model.GetOwner()
    int team = model.GetTeam()
    model.EndSignal( "OnDestroy" )

    if ( IsValid( player ) )
    {
        DestroyDropShipCamera( dropship )
        player.MakeVisible()
        player.ClearParent()
        player.SetOrigin( origin + <0,0,150> )
        player.ClearInvulnerable()
        thread PlayerFlyOut( player )
    }
    if ( IsValid( dropship.crosshair ) )
        dropship.crosshair.kv.VisibilityFlags = 0
    if( IsValid( dropship.laser ) )
        dropship.laser.Destroy()
    if ( IsValid( dropship.dropship.pilot ) )
        dropship.dropship.pilot.Destroy() // or .Die()
    //EmitSoundAtPosition( TEAM_ANY, origin, "s2s_goblin_blow_up" )
    EmitSoundAtPosition( TEAM_ANY, origin, "titan_death_explode" )
    int fxID = GetParticleSystemIndex( GOBLIN_DEATH_FX_S2S )
    if ( dropship.dropship.mover.GetTeam() == TEAM_MILITIA )
        fxID = GetParticleSystemIndex( CROW_DEATH_FX_S2S )  
    StartParticleEffectInWorld( fxID, origin, CONVOYDIR )

    if( IsValid( model ) )
        model.Destroy()
    if ( IsValid( dropship.dropship.mover ) )
        dropship.dropship.mover.Destroy()
    
    // if ( IsValid( dropship.panel ) )
    //     dropship.panel.Die()
    
    print( "dropship is being destroyed ( probably death anim )" )
    
    WaitFrame()
    
    if ( IsValid( dropship.dropship.mover ) )
        dropship.dropship.mover.UnsetUsable()
    
    OnThreadEnd(
		function () : ()
		{
            print( "dropship destroyed and cleaned" )
        }
    )
    
    float time = Time() + 3

    while( true )
    {
        if( time > Time() )
            break
        if( !IsValid( model ) )
            break
        vector thing = model.GetOrigin()
        if ( thing.x > flight_limit || thing.x < -flight_limit || thing.y > flight_limit || thing.y < -flight_limit || thing.z > flight_limit - 3000 || thing.z < -flight_limit + 3000 )
            model.Destroy()
        
        WaitFrame()
    }

    if ( IsValid( model ) )
    {
        int fxID = GetParticleSystemIndex( GOBLIN_DEATH_FX_S2S )

        if( IsValid( dropship.dropship.mover ) )
        {
            if ( dropship.dropship.mover.GetTeam() == TEAM_MILITIA )
                fxID = GetParticleSystemIndex( CROW_DEATH_FX_S2S )  
            origin = dropship.dropship.mover.GetOrigin()
            dropship.dropship.mover.Destroy()
        }

        EmitSoundAtPosition( TEAM_ANY, origin, "s2s_goblin_blow_up" )

        StartParticleEffectInWorld( fxID, origin, CONVOYDIR )
    }
}

void function PlayerFlyOut( entity player )
{
    player.EndSignal( "OnDeath" )
    player.EndSignal( "OnDestroy" )

    while( !player.IsOnGround() && IsValid( player ) && IsAlive( player ) )
    {
        vector thing = player.GetOrigin()
        if ( thing.x > flight_limit || thing.x < -flight_limit || thing.y > flight_limit || thing.y < -flight_limit || thing.z > flight_limit - 3000 || thing.z < -flight_limit + 3000 )
            player.Die()
        
        WaitFrame()
    }
}

void function HandlePlayerDeathInDropship( DropShiptruct dropship, entity model )
{
    print( "apprently the owner died" )

    DestroyDropShipCamera( dropship )
    // model.GetOwner().ClearParent()

    vector angles = dropship.dropship.mover.GetAngles()
    angles.x = 0
    // dropship.dropship.mover.NonPhysicsRotateTo( angles, 2, 0.1, 0.1 )
    dropship.dropship.mover.SetAngles( angles )
    dropship.dropship.model.SetAngles( angles )
    if ( IsValid( dropship.crosshair ) )
        dropship.crosshair.kv.VisibilityFlags = 0
    if( IsValid( dropship.laser ) )
        dropship.laser.Destroy()

    thread DropShipWaitForDriver( dropship )

    thread SelfDriveThink( dropship )

    print( "cleaned up the owner" )
}

void function HandleExitRequest( DropShiptruct dropship, entity player )
{
    print( "handling exit request" )

    DestroyDropShipCamera( dropship )
    player.MakeVisible()
    player.SetOrigin( dropship.dropship.model.GetOrigin() + <0,0,150> )
    player.ClearParent()
    player.ClearInvulnerable()
    thread PlayerFlyOut( player )
    ScreenFade( player, 0, 0, 0, 255, 0.3, 0.3, (FFADE_IN | FFADE_PURGE) )

    // dropship.camera.Destroy()

    vector angles = dropship.dropship.mover.GetAngles()
    angles.x = 0
    dropship.dropship.mover.SetAngles( angles )
    dropship.dropship.model.SetAngles( angles )
    if ( IsValid( dropship.crosshair ) )
        dropship.crosshair.kv.VisibilityFlags = 0
    if( IsValid( dropship.laser ) )
        dropship.laser.Destroy()

    thread DropShipWaitForDriver( dropship )

    thread SelfDriveThink( dropship )

    print( "cleaned up the owner for exit" )
}

void function SelfDriveThink( DropShiptruct dropship )
{
    ShipStruct ship = dropship.dropship
    entity mover = ship.mover
    entity model = ship.model

    model.EndSignal( "OverDamaged" )
    EndSignal( ship, "engineFailure_Complete" )
    model.EndSignal( "OnDeath" )
    model.EndSignal( "OnDestroy" )

    vector angles = mover.GetAngles()
    //RotateDropShip( dropship, <angles.x,angles.y,0> )

    while( !IsValid( model.GetOwner() ) )
    {
        if ( ship.behavior == eBehavior.DEATH_ANIM )
            return

        if ( !HasEnoughSpeed( dropship ) )
            return
        
        if ( DidColide( dropship ) )
        {
            thread DropShipDied( dropship, model )
            model.TakeDamage( model.GetHealth() - 1, null, null, { damageSourceId=damagedef_suicide } )
        }

        if ( GetAcceleration( dropship ) < 0.0 )
        {
            IncreaseAcceleration( dropship )
        }
        else if ( GetAcceleration( dropship ) > 0.0 )
        {
            DecreaseAcceleration( dropship )
        }

        MoveDropShip( dropship, mover.GetForwardVector() )

        WaitFrame()
    }
}

/*
██╗   ██╗████████╗██╗██╗     ██╗████████╗██╗███████╗███████╗
██║   ██║╚══██╔══╝██║██║     ██║╚══██╔══╝██║██╔════╝██╔════╝
██║   ██║   ██║   ██║██║     ██║   ██║   ██║█████╗  ███████╗
██║   ██║   ██║   ██║██║     ██║   ██║   ██║██╔══╝  ╚════██║
╚██████╔╝   ██║   ██║███████╗██║   ██║   ██║███████╗███████║
 ╚═════╝    ╚═╝   ╚═╝╚══════╝╚═╝   ╚═╝   ╚═╝╚══════╝╚══════╝                                                                                              
*/

bool function DidColide( DropShiptruct dropship )
{
    TraceResults traceResult
    vector Ray
    foreach( float angle in [10.0,0.0,-10.0] )
    {
        Ray = AnglesToForward( dropship.dropship.mover.GetAngles() + <0,angle,0>, <0,0,0> ) * 80
        traceResult = TraceLine( dropship.dropship.mover.GetOrigin(), dropship.dropship.mover.GetOrigin() + Ray, [ dropship.dropship.mover, dropship.dropship.model ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )

        // print( "b" + traceResult.hitEnt )
        
        if ( traceResult.hitEnt != null )
        {

            if ( traceResult.hitEnt.IsPlayer() || traceResult.hitEnt.IsNPC() )
            {
                KillEntity( traceResult.hitEnt, dropship.dropship.mover )
                continue
            }
            
            print( "DropShip Collided with " + traceResult.hitEnt.GetClassName() + ", " + traceResult.hitEnt.GetScriptName() )
            return true
        }
    }

    return false
}

void function KillEntity( entity guy, entity mover )
{
    if ( !IsValid( guy ) || !IsAlive( guy ) || guy.GetTeam() == mover.GetTeam() )
        return
    
    guy.TakeDamage( guy.GetMaxHealth() * 2, mover.GetOwner(), null, { damageSourceId=eDamageSourceId.crushed } )
}

void function MoveDropShip( DropShiptruct dropship, vector offset )
{
    dropship.dropship.mover.NonPhysicsMoveTo( dropship.dropship.mover.GetOrigin() + ( offset  * ( drop_ship_base_speed * dropship.acceleration ) ), 0.3, 0.05, 0.05 )
}

void function RotateDropShip( DropShiptruct dropship, vector angles )
{
    angles = dropship.dropship.mover.GetAngles() + angles
    dropship.dropship.mover.NonPhysicsRotateTo( angles, 0.3, 0.05, 0.05 )
}

bool function HasEnoughSpeed( DropShiptruct dropship )
{
    if ( dropship.acceleration > 0.25 || dropship.acceleration < -0.25 )
        return true
    
    return false
}

float function GetAcceleration( DropShiptruct dropship )
{
    return dropship.acceleration
}

void function IncreaseAcceleration( DropShiptruct dropship )
{
    if ( dropship.acceleration < 1.0 )
    {
        dropship.acceleration += 0.02
    }
    else
    {
        dropship.acceleration = 1.0
    }
}
void function DecreaseAcceleration( DropShiptruct dropship )
{
    if ( dropship.acceleration > 0.0 )
    {
        dropship.acceleration -= 0.02
    }
    else
    {
        dropship.acceleration = 0.0
    }
}

void function SpawnDropshipCamera( entity player, DropShiptruct dropship )
{
    entity model = dropship.dropship.model

    player.SnapEyeAngles( model.GetAngles() )

    entity mover = CreateExpensiveScriptMover()
    mover.SetOrigin( model.GetOrigin() )
	mover.SetAngles( model.GetAngles() )

    player.SnapEyeAngles( model.GetAngles() )

    dropship.mover = mover
    
    player.SetAngles( model.GetAngles() )
    HolsterAndDisableWeapons( player )
    player.PlayerCone_SetLerpTime( 0.5 )
    player.PlayerCone_FromAnim()
	player.PlayerCone_SetMinYaw( -30 )
	player.PlayerCone_SetMaxYaw( 30 )
	player.PlayerCone_SetMinPitch( -30 )
	player.PlayerCone_SetMaxPitch( 30 )
}

void function DestroyDropShipCamera( DropShiptruct dropship )
{
    entity player = dropship.dropship.model.GetOwner()
    if ( IsValid( player ) )
    {
        player.ClearParent()
        DeployAndEnableWeapons( player )
        ViewConeFree( player )
    }

    dropship.mover.Destroy()
}

void function UpdatedCameraPosition( DropShiptruct dropship )
{
    entity mover = dropship.dropship.mover
    entity player = dropship.dropship.model.GetOwner()
    vector offset = mover.GetForwardVector() * -500
    offset += mover.GetUpVector() * 200

    if ( dropship.cam_state == 0 )
    {
        dropship.mover.NonPhysicsMoveTo( offset + mover.GetOrigin(), 0.3, 0.05, 0.05 )
        dropship.mover.NonPhysicsRotateTo( mover.GetAngles(), 0.3, 0.05, 0.05 )
    }
    if ( dropship.cam_state == 1 )
    {
        player.PlayerCone_SetLerpTime( 0 )
        player.PlayerCone_FromAnim()
        player.PlayerCone_SetMinYaw( -30 )
        player.PlayerCone_SetMaxYaw( 30 )
        player.PlayerCone_SetMinPitch( -30 )
        player.PlayerCone_SetMaxPitch( 30 )

        offset = mover.GetForwardVector() * 360
        offset += mover.GetUpVector() * -100
        dropship.mover.NonPhysicsMoveTo( offset + mover.GetOrigin(), 0.1, 0, 0 )
        dropship.mover.SetParent( mover, "", false, 0.0 ) // whar
        ScreenFade( player, 0, 0, 0, 255, 0.3, 0.3, (FFADE_IN | FFADE_PURGE) )
        player.SnapEyeAngles( mover.GetAngles() )
        dropship.cam_state = 2
    }
    if ( dropship.cam_state == 3 )
    {
        dropship.mover.ClearParent()
        ScreenFade( player, 0, 0, 0, 255, 0.3, 0.3, (FFADE_IN | FFADE_PURGE) )
        player.SnapEyeAngles( mover.GetAngles() )
        dropship.cam_state = 0
    }
}

void function SwitchWepon( DropShiptruct dropship )
{
    entity player = dropship.dropship.model.GetOwner()
    string shipType = dropship.shipType
    if ( dropship.time_gun_switch < Time() )
    {
        if( shipType == "gunship" )
        {
            if ( dropship.gun_type == 1 )
            {
                if( IsValid( player ))
                    SendHudMessage(player, "Switching to Gunship Launcher" , -1, -0.35, 255, 255, 0, 255, 0, 2, 0)
                dropship.gun_type = 0
            }
            else
            {
                if( IsValid( player ))
                    SendHudMessage(player, "Switching to Laser Rifle" , -1, -0.35, 255, 255, 0, 255, 0, 2, 0)
                dropship.gun_type = 1
            }
        }
        if( shipType == "dropship" )
        {
            if ( dropship.gun_type == 1 )
            {
                if( IsValid( player ))
                    SendHudMessage(player, "Switching to Nulclear Missile" , -1, -0.35, 255, 255, 0, 255, 0, 2, 0)
                dropship.gun_type = 0
            }
            else
            {
                if( IsValid( player ))
                    SendHudMessage(player, "Switching to Rapid Missile" , -1, -0.35, 255, 255, 0, 255, 0, 2, 0)
                dropship.gun_type = 1
            }
        }
        
        EmitSoundOnEntityOnlyToPlayer( dropship.dropship.model.GetOwner(), dropship.dropship.model.GetOwner(), "UI_Networks_Invitation_Accepted" )

        dropship.time_gun_switch = Time() + 1.0
    }
}

void function DisplayHealthToDriver( DropShiptruct dropship )
{
    entity player = dropship.dropship.model.GetOwner()
    int health = dropship.dropship.model.GetHealth()
    SendHudMessage( player, "Health Left: " + string( health ) , -1, -0.35, 100, 200, 50, 255, 0.0, 0.2, 0.0 )
}

void function SpawnDropShipCrosshair( DropShiptruct dropship )
{
    string attachment // anti crash? for unknown models
    if( dropship.shipType == "gunship" )
        attachment = "Spotlight"
    entity laser
    if( attachment != "" )
        laser = PlayLoopFXOnEntity( $"P_wpn_lasercannon_aim", dropship.dropship.model, attachment, null, null, ENTITY_VISIBLE_TO_FRIENDLY )
    entity env_sprite = CreateEntity( "env_sprite" )
	env_sprite.kv.rendermode = 5
	env_sprite.kv.origin = <0,0,0>
	env_sprite.kv.angles = <0,0,0>
	env_sprite.kv.rendercolor = < 255, 0, 0 >
	env_sprite.kv.renderamt = 255
	env_sprite.kv.framerate = "10.0"
	env_sprite.SetValueForModelKey( $"sprites/glow_05.vmt" )
	env_sprite.kv.scale = 5
	env_sprite.kv.spawnflags = 1
	env_sprite.kv.GlowProxySize = 16.0
	env_sprite.kv.HDRColorScale = 1.0
	DispatchSpawn( env_sprite )
    entity player = dropship.dropship.model.GetOwner()
    env_sprite.SetOwner( player )
    dropship.crosshair = env_sprite
    if( IsValid( laser ) )
        dropship.laser = laser
}

void function DestroyDropShipCrosshair( DropShiptruct dropship )
{
    dropship.crosshair.Destroy()
}

void function UpdateDropshipCrosshair( DropShiptruct dropship )
{
    entity mover = dropship.dropship.mover

    WeaponPrimaryAttackParams attackParams
    attackParams.pos = mover.GetOrigin() + ( mover.GetForwardVector() * 400 ) + ( mover.GetUpVector() * -100 )
    attackParams.dir = mover.GetForwardVector() * 1000

	vector attackDir = attackParams.dir
	vector attackPos = attackParams.pos
	attackDir = Normalize( attackDir )

    vector traceEnd = attackPos + attackDir * 56756 //max length
    TraceResults result = TraceLine( attackPos, traceEnd, [], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )
    
    dropship.crosshair.SetOrigin( result.endPos )
}

void function DEV_SpawnDrivableDropShip()
{
    entity player = GetPlayerArray()[0]
    SpawnDrivableDropShip( player.GetOrigin(), CONVOYDIR, player.GetTeam() )
}