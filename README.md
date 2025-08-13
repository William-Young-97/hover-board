# How to setup a scene

# Respawn Manager

- Drop in the respawn manager node (just a plain node 3D) and attach controllers/respawn/respawn_manager.gd
- Add a respawn point on the map as a child
- Add death zones under here as a child too
(Note: These should belong to their apporpiate global groups for finding each other)

# Lap Manager

- Add Lap MAnager Node and attach its controller script.
- Child startline and checkpoints to it.

# ai
- Drop in waypoint scene objects. these belong to the correct global group.
