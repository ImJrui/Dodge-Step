local PLENV = env
GLOBAL.setfenv(1, GLOBAL)

-- Import hooks from postinit/ with PLENV.modimport when features are added.
