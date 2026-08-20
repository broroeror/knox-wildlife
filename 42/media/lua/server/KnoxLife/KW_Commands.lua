--- Server side of the admin right-click actions.
---
--- Spawning cannot happen on a multiplayer client. The guard and its full
--- diagnosis live at KW_Reseed.lua:64 -- briefly, an animal created client-side
--- renders and walks but can never be hurt, because only the server allocates
--- the network id a hit packet needs, so every swing is dropped server-side with
--- "The packet PlayerHitAnimal is not consistent". That is silent in game and
--- looks exactly like an animal that will not take damage.
---
--- So the client asks (KW_AdminMenu.lua) and the server acts, here.

if not KW then KW = {} end

local JUVENILES = {
    { id = "kwc_foxkit",       label = "fox kit" },
    { id = "kwc_coyotepup",    label = "coyote pup" },
    { id = "kwc_bobcatkitten", label = "bobcat kitten" },
    { id = "kwc_squirrelkit",  label = "squirrel kit" },
}

--- Spawn one of each juvenile around (x, y). Returns placed, list-of-failures.
---
--- Exposed on KW rather than kept local so a singleplayer game and the offline
--- Lua tests can call the same code path the server command uses. There is no
--- second implementation of this to drift.
function KW.spawnJuvenilesAt(x, y)
    local placed, missed = 0, {}
    for i, j in ipairs(JUVENILES) do
        -- Two tiles apart, so all four are visible at once and can be compared
        -- against each other and against any adult that wanders in.
        local breed = KW.pickBreed and KW.pickBreed(j.id, nil) or nil
        if KW.spawnOne and KW.spawnOne(j.id, breed, x + (i * 2), y) then
            placed = placed + 1
        else
            missed[#missed + 1] = j.label
        end
    end
    return placed, missed
end

local function onClientCommand(module, command, player, args)
    if module ~= "KnoxLife" then return end
    if command ~= "spawnJuveniles" then return end

    -- Re-check server-side. The client menu is already admin-gated, but a
    -- client command is just a packet and anyone can send one; a spawn command
    -- that trusts the sender is a cheat vector in a public mod.
    if player and player.getAccessLevel then
        local lvl = player:getAccessLevel()
        if lvl ~= "Admin" and lvl ~= "Moderator" then
            print("[KnoxLife] refused spawnJuveniles from non-admin "
                  .. tostring(player:getUsername()))
            return
        end
    end
    if not (args and args.x and args.y) then return end

    local placed, missed = KW.spawnJuvenilesAt(args.x, args.y)
    print(string.format("[KnoxLife] spawnJuveniles by %s at %d,%d -- %d/%d placed%s",
        tostring(player and player:getUsername() or "?"),
        math.floor(args.x), math.floor(args.y), placed, #JUVENILES,
        #missed > 0 and (" -- failed: " .. table.concat(missed, ", ")) or ""))
end

Events.OnClientCommand.Add(onClientCommand)
