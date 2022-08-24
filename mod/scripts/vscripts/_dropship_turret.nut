global function InitDropshipTurret
global function SetupDropshipTurret
global function DropshipPanelActivateThread

void function InitDropshipTurret()
{
    PrecacheModel( $"models/props/global_access_panel_button/global_access_panel_button_console.mdl" )
}

void function SetupDropshipTurret( DropShiptruct dropship )
{
    entity mover = dropship.dropship.mover

    vector origin = mover.GetOrigin()
    origin += mover.GetForwardVector() * 40
    origin += mover.GetUpVector() * -60
    vector angles = mover.GetAngles() * -1

    // entity panel = CreateControlPanelEnt( origin, angles, null, $"models/communication/terminal_usable_imc_01.mdl" )
	// panel.s.remoteTurretStartFunc = DropshipPanelActivateThread
	// panel.s.remoteTurret = mover
	// panel.SetScriptPropFlags( SPF_CUSTOM_SCRIPT_1 )
	// panel.kv.CollisionGroup = TRACE_COLLISION_GROUP_NONE
	// panel.kv.solid = SOLID_VPHYSICS
	// panel.Solid()
	// panel.SetOwner( null )
    // panel.SetParent( mover )

    // entity panel = CreateEntity( "prop_control_panel" )
	// panel.SetValueForModelKey( $"models/communication/terminal_usable_imc_01.mdl" )
	// panel.SetOrigin( origin )
	// panel.SetAngles( angles )
	// panel.kv.solid = SOLID_VPHYSICS
	// DispatchSpawn( panel )
	
	// panel.SetModel( $"models/communication/terminal_usable_imc_01.mdl" )
	// panel.s.scriptedPanel <- true
    // panel.SetParent( mover )
	
	// HACK: need to use a custom useFunction here as control panel exposes no way to get the player's position before hacking it, or a way to run code before the hacking animation actually starts
	// panel.s.startOrigin <- < 0, 0, 0 >
	// panel.useFunction = FastballControlPanelCanUse

    entity panel = CreateEntity( "prop_dynamic" )

    panel.SetValueForModelKey( $"models/props/global_access_panel_button/global_access_panel_button_console.mdl" )
	panel.kv.fadedist = 10000
	panel.kv.renderamt = 255
	panel.kv.rendercolor = "81 130 151"
	panel.kv.solid = SOLID_VPHYSICS

	SetTeam( panel, TEAM_BOTH )
	panel.SetOrigin( origin )
	panel.SetAngles( angles )
	DispatchSpawn( panel )

    panel.SetUsable()
    panel.SetUsableByGroup( "pilot" )
    panel.SetUsePrompts( "Hold %use% to use turret", "Press %use% to use turret" )
    panel.SetParent( mover )
	
	thread PanelThink( mover, panel )
	
	Highlight_SetNeutralHighlight( panel, "sp_enemy_pilot" )

    dropship.panel = panel

    thread DestroyPanelOnDropshipDeath( dropship, panel )    
}

void function PanelThink( entity mover, entity panel )
{
    EndSignal( panel, "OnDestroy" )
    
    for(;;)
    {
        panel.SetUsable()
        panel.SetSkin( 0 )

        entity player = expect entity( panel.WaitSignal( "OnPlayerUse" ).player )
        thread DropshipPanelActivateThread( mover, panel, player )

        panel.UnsetUsable()
        EmitSoundOnEntity( panel, "Switch_Activate" )
        panel.SetSkin( 1 )

        WaitSignal( panel, "ScriptAnimStop" )
    }
}

void function DestroyPanelOnDropshipDeath( DropShiptruct dropship, entity panel )
{
    dropship.dropship.mover.EndSignal( "OverDamaged" )
    EndSignal( dropship.dropship, "engineFailure_Complete" )
    dropship.dropship.mover.EndSignal( "OnDeath" )
    dropship.dropship.mover.EndSignal( "OnDestroy" )
    panel.EndSignal( "OnDestroy" )
    panel.EndSignal( "OnDeath" )

    OnThreadEnd(
	function() : ( dropship, panel )
		{
            if ( IsValid( panel.GetOwner() ) && IsAlive( panel.GetOwner() ) )
                panel.GetOwner().Die()
            if ( IsValid( panel ) )
                panel.Destroy()
        }
    )

    WaitSignal( panel, "OnDestroy" )
}

void function DropshipPanelActivateThread( entity mover, entity panel, entity player )
{
    bool playerExiting = false

    if ( player.IsTitan() )
        return

    panel.UnsetUsable()
    panel.SetOwner( player )
    
    player.EndSignal( "OnDeath" )
    player.EndSignal( "OnDestroy" )
    mover.EndSignal( "OverDamaged" )
    mover.EndSignal( "OnDeath" )
    mover.EndSignal( "OnDestroy" )

    OnThreadEnd(
	function() : ( panel, player, mover, playerExiting )
		{
            print( "ending turret run" )
            if ( playerExiting )
                thread HandlePlayerExit( panel, player )
            else if ( !IsValid( player ) || !IsAlive( player ) )
                thread HandlePlayerDeath( panel, player )
            else 
                thread HandlePlayerExit( panel, player )
        }
    )
    
    WaitFrame()

    ScreenFade( player, 0, 0, 0, 255, 0.3, 0.3, (FFADE_IN | FFADE_PURGE) )

    vector offset = mover.GetForwardVector() * 250
    offset += mover.GetUpVector() * -150
    player.SetOrigin( offset + mover.GetOrigin() )

    StorePilotWeapons( player )
    player.GiveWeapon( "mp_weapon_lmg" )
    player.MakeInvisible()
    player.SetInvulnerable()
    player.SetParent( mover, "", false, 0.0 )

    player.SetOrigin( offset + mover.GetOrigin() )

    for(;;)
    {
        if ( mover.GetHealth() < 10 )
            return
        
        array<bool> keys = GetPlayerKeysList( player )
        
        if ( keys[KD] || keys[KJ] || player.GetParent() != mover )
        {
            playerExiting = true
            return
        }

        WaitFrame()
    }
}

void function HandlePlayerExit( entity panel, entity player )
{
    player.ClearParent()
    player.MakeVisible()
    player.ClearInvulnerable()
    RetrievePilotWeapons( player )
    ScreenFade( player, 0, 0, 0, 255, 0.3, 0.3, (FFADE_IN | FFADE_PURGE) )

    vector origin = panel.GetForwardVector() * 25 + panel.GetOrigin()
    player.SetOrigin( origin )

    panel.SetOwner( null )
    panel.SetUsable()

    panel.Signal( "ScriptAnimStop" )
}

void function HandlePlayerDeath( entity panel, entity player )
{
    if ( IsAlive( player ) )
    {
        player.ClearParent()
        player.MakeVisible()
        player.ClearInvulnerable()
        RetrievePilotWeapons( player )
        ScreenFade( player, 0, 0, 0, 255, 0.3, 0.3, (FFADE_IN | FFADE_PURGE) )

        vector origin = panel.GetForwardVector() * 25 + panel.GetOrigin()
        player.SetOrigin( origin )
    }
    
    if ( IsValid( panel ) )
    {
        panel.SetOwner( null )
        panel.SetUsable()

        panel.Signal( "ScriptAnimStop" )
    }
}