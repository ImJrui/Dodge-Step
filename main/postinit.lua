local PLENV = env
GLOBAL.setfenv(1, GLOBAL)

PLENV.modimport("postinit/prefabs/player.lua")
PLENV.modimport("postinit/prefabs/shrouden.lua")
