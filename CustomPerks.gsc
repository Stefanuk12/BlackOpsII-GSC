/*
This is just a minor project for me to learn GSC.

Note: This code is untested and likely does not work but provides a way to efficiently and effectively make custom perks via "classes"

Credits: Sorex Project - Perk Ideas
*/

// Initialise
init()
{
    preloadAssets();
	level thread onPlayerConnect();
    thread PerkClass::startAllMachines();
}

// Preload some assets
preloadAssets()
{
    PrecacheModel("collision_geo_cylinder_32x128_standard");
	PrecacheModel("zombie_perk_bottle_whoswho");
}

// Initialises all of the data for the player
level.custom_perks = array();
InitialiseData()
{
    //
    player = self;

    // Create custom perk holder
    player.custom_perks = array();
}

//
onPlayerConnect()
{
    //
	level endon("end_game");
    self endon("disconnect");

    // Constant Loop
	while (true)
	{
        // Wait until a new player connects
		level waittill("connected", player);

        //
        player InitialiseData();
        player thread ConstantRedrawHUD();
	}
}

// Redraw HUD
RedrawHUD()
{
    //
    player = self;

    // Vars
    start = -300;
    offset = 25;

    // Loop through all custom perks
    for (i = 0; i < player.custom_perks.size; i++)
    {
        // Vars
        perk = player.custom_perks[i];

        // Remove if exists
        if (perk.hudobject)
        {
            perk.hudobject Destroy();
            perk.hudobject = undefined;
        }

        // Make sure is enabled
        if (!perk.enabled)
        {
            continue;
        }

        // Calculate where to show
        x = start + (offset * (i + 1));

        // Draw
        perk.hudobject = player drawshader(perk.icon, x, 320, 24, 25, perk.colour, 100, 0);
    }
}
ConstantRedrawHUD()
{
    //
    player = self;

    //
    while (true)
    {
        player RedrawHUD();
    }
}

// Create Perk Class. Example: player perk::give(perk);
PerkClass = spawnstruct();
{
    // Constructor
    constructor(name, humanname, cost, weaponmodel, icon, colour, vendingdata)
    {
        // Create Struct
        Perk = spawnstruct();

        // Set properties
        Perk.name = name;
        Perk.humanname = humanname || "unnamed";
        Perk.enabled = false;
        Perk.cost = cost || 0
        Perk.weaponmodel = weaponmodel || "zombie_perk_bottle_whoswho";
        Perk.hudobject = undefined;
        Perk.icon = icon || "specialty_juggernaut_zombies";
        Perk.colour = colour || (1, 1, 1);
        
        // Default vending data
        if (!vendingdata)
        {
            vendingdata = spawnstruct();
            vendingdata.model = "zombie_vending_sleight";
            vendingdata.origin = (1149, -215, -304);
            vendingdata.angles = (0, 180, 0);
        }
        Perk.vendingdata = vendingdata;

        // Add methods
        Perk.start = ::start;
        Perk.give = ::give;
        Perk.remove = ::remove;
        Perk.has = ::has;
        Perk.spawnMachine = ::spawnMachine;

        // Create Perk
        level.custom_perks[level.custom_perks.size] = Perk;

        // Return the perk
        return Perk;
    }
    PerkClass.new = ::constructor;

    // Returns whether player has perk
    has(_perk)
    {
        //
        player = self;
        self = _perk;

        // Loop through custom perks
        foreach(perk in player.custom_perks)
        {
            // Find perk
            if (perk.name == self.name)
            {
                // Return whether it is enabled or not
                return perk.enabled;
            }
        }
    }

    // The functionality for the perk
    start(_perk)
    {
        //
        player = self;
        self = _perk;
    }
    PerkClass.start = ::start;

    // Gives a perk to a player
    give(_perk)
    {
        //
        player = self;
        self = _perk;

        // Make sure they already don't have it
        if (self.enabled)
        {
            return;
        }

        // Remove
        player.score -= self.cost;

        // Do the animation
        player DisableOffhandWeapons();
        player DisableWeaponCycling();
        weaponA = player getCurrentWeapon();
        weaponB = self.weaponmodel;
        player GiveWeapon(weaponB);
        player SwitchToWeapon(weaponB);
        player waittill("weapon_change_complete");
        player EnableOffhandWeapons();
        player EnableWeaponCycling();
        player TakeWeapon(weaponB);
        player SwitchToWeapon(weaponA);

        // Give perk
        self.enabled = true;
        player thread self::start(self);

        // Finish animation
        self maps/mp/zombies/_zm_audio::playerexert("burp");
        self setblur(4, 0.1);
        wait(0.1);
        self setblur(0, 0.1);
    }

    // Removes the perk from the player
    remove(_perk)
    {
        //
        player = self;
        self = _perk;

        // Disable
        self.enabled = false;

        // Remove from HUD
        self.hudobject Destroy();
        self.hudobject = undefined;
    }

    // Spawns the perk machine
    spawnMachine(_perk)
    {
        //
        self = _perk;

        // Vars
        data = self.vendingdata[getDvar("mapname")];

        // Make sure there is data
        if (!data)
        {
            return;
        }

        //
        level endon("end_game");

        // Spawning the barrier, and setting angles
        barrier = spawn("script_model", data.origin);
        barrier setModle("collision_geo_cylinder_32x128_standard");
        barrier rotateTo(data.angles, 0.1);

        // Spawning the machine itself, and setting angles
        vending = spawn("script_model", data.origin);
        vending setModel(data.model);
        vending rotateTo(data.angles, 0.1);

        // Prompt
        level thread LowerMessage("Custom Perk", "Hold ^3F ^7for " + self.humanname + " [Cost: " + self.cost + "]");

        // Trigger
        Trigger = spawn("trigger_radius", data.origin, 1, 25, 25);
        Trigger SetCursorHint("HINT_NOICON");
        Trigger setLowerMessage(Trigger, "Custom Perk");

        // Infinite loop
        while (true)
        {
            // Wait until player walks close
            Trigger waittill("trigger", player);

            // Check if they have the perk already, show/hide trigger
            if (player self::has(self))
            {
                level.Trigger hide();
            } 
            else 
            {
                level.Trigger show();
            }

            // See if they can afford it and if they pressed down the use button
            if (!(player.score >= self.cost && player useButtonPressed()))
            {
                continue;
            }

            // Small delay
            wait(0.25);

            // Check if they still are holding down the purchase button
            if (!player useButtonPressed())
            {
                continue;
            }

            // Cha Ching!
            player playsound("zmb_cha_ching");

            // Give perk
            level.Trigger hide();
            player self::give(self);
            wait(2);
            level.Trigger show();
        }
    }

    // Spawns all the perk machines (static method)
    startAllMachines()
    {
        foreach(self in level.custom_perks)
        {
            self::spawnMachine(self);
        }
    }
    PerkClass.startAllMachines = ::startAllMachines;
}

// Unlimited Stamina Stuff
UnlimitedStamina = PerkClass.new("unlimited_stamina", "Unlimited Stamina", 2000);
{
    //
    Perk.perk = "specialty_unlimitedsprint";

    // The functionality for the perk
    start(_perk)
    {
        //
        player = self;
        self = _perk;

        // Give unlimited stamina
        player setperk(Perk.perk);
    }
    UnlimitedStamina.start = ::start;

    // Removes the perk from the player
    remove(_perk)
    {
        //
        player = self;
        self = _perk;

        // Disable
        self.enabled = false;
        player unsetperk(Perk.perk);

        // Remove from HUD
        self.hudobject Destroy();
        self.hudobject = undefined;
    }
    UnlimitedStamina.remove = ::remove
}

// Second Life Stuff
SecondLife = PerkClass.new("second_life", "Second Life", 4000);
{
    // The functionality for the perk
    start(_perk)
    {
        //
        player = self;
        self = _perk;

        // Makes sure has perk
        if (self.enabled)
        {
            return;
        }

        // Wait for down
        player waittill("entering_last_stand")

        // Revive
        player maps/mp/zombies/_zm_laststand::auto_revive(player)

        // Remove
        player self.remove(self);
    }
    SecondLife.start = ::start;
}

// Ammo Regen Stuff
AmmoRegen = PerkClass.new("ammo_regen", "Ammo Regen", 2500);
{
    // Vars
    Perk.requiredkills = 15;

    // Manages whenever you kill a zomie
    zombieKill(_perk)
    {
        //
        player = self;
        self = _perk;
        
        // Constant loop
        while (self.enabled)
        {
            // Wait for a zombie to be killed
            player waittill("zom_kill");
            
            // Vars
            CurrentWeapon = player getCurrentWeapon();

            // Makes sure has 15 kills
            player[CurrentWeapons].kills += 1;
            if (player[CurrentWeapons].kills < Perk.requiredkills)
            {
                return;
            }

            // Reset counter
            CurrentWeapon.kills = 0;

            // Replenish ammo
            player GiveMaxAmmo(CurrentWeapon);
        }
    }

    // Manages weapon stuff
    weaponSwitch(_perk)
    {
        //
        player = self;
        self = _perk;

        // Constant loop
        while (self.enabled)
        {
            // Wait for weapon switch
            player waittill("weapon_change_complete");

            // Make sure has container
            if (!self[Weapon])
            {
                self[Weapon] = spawnstruct();
                self[Weapon].kills = 0;
            }
        }
    }

    // The functionality for the perk
    start(_perk)
    {
        //
        player = self;
        self = _perk;

        //
        player thread zombieKill(self);
        player thread weaponSwitch(self);
    }
    AmmoRegen.start = ::start;
}

// Earn Money Stuff
EarnMoney = PerkClass.new("earn_money", "Earn Money", 3000);
{
    // Vars
    EarnMoney.Amount = 100;
    EarnMoney.WaitTime = 15;

    // The functionality for the perk
    start(_perk)
    {
        //
        player = self;
        self = _perk;
    
        // Constant loop
        while (self.enabled)
        {
            // Wait 15 seconds
            wait(EarnMoney.WaitTime);

            // Give the money
            player.score += EarnMoney.Amount;
        }
    }
    EarnMoney.start = ::start;
}

// Life Save Stuff - im not sure whether i did this right or not lol
LifeSave = PerkClass.new("life_save", "Life Save", 2000);
{
    // Vars
    LifeSave.Protections = array("MOD_GRENADE_SPLASH", "MOD_IMPACT", "MOD_GAS", "MOD_EXPLOSIVE");
    LifeSave.Reduction = 0.75; // (1 - Reduction) * 100 = Percentage of Reduction

    // The functionality for the perk
    start(_perk)
    {
        //
        player = self;
        self = _perk;

        // Constant loop
        while (self.enabled)
        {
            // Wait until damage is taken
            player waittill("damage", amount, attacker, direction, point, dmg_type)

            // Check if cause is protected against
            if (!isinarray(LifeSave.Protections, dmg_type))
            {
                return Damage;
            }

            // Get health before took damage
            BaseHealth = player.health + amount

            // Work out how much to redact
            Redaction = amount * LifeSave.Reduction;

            // Redact and set
            player.health = (BaseHealth - Redaction);
        }
    }
    LifeSave.start = ::start;
}
