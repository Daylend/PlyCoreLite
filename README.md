# PlayerCore - Minimal Edition

A stripped-down version of PlayerCore, an extension for Expression 2 that provides basic player manipulation functions. Access control explained below.

## Manual Installation

Clone this repository into your `steamapps\common\GarrysMod\garrysmod\addons` folder using this command if you are using git:

    git clone git@github.com:Daylend/PlyCoreLite.git

## Functions

### Basic Getters
| Function                          | Return | Description                                                                                    |
|-----------------------------------|:------:|------------------------------------------------------------------------------------------------|
| E:plyGetJumpPower()               | N      | Returns the jump power of the player.                                                          |
| E:plyGetGravity()                 | N      | Returns the gravity of the player.                                                             |
| E:plyGetSpeed()                   | N      | Returns the walk speed of the player.                                                          |
| E:plyIsFrozen()                   | N      | Returns 1 if the player is frozen, 0 otherwise.                                                |

### Basic Setters
| Function                          | Return | Description                                                                                    |
|-----------------------------------|:------:|------------------------------------------------------------------------------------------------|
| E:plySetPos(vector pos)           |        | Sets the position of the player.                                                               |
| E:plySetAng(angle ang)            |        | Sets the angle of the player's camera.                                                         |
| E:plySetHealth(N)                 |        | Sets the health of the player.                                                                 |
| E:plySetArmor(N)                  |        | Sets the armor of the player.                                                                  |
| E:plySetJumpPower(N)              |        | Sets the jump power, eg. the velocity the player will applied to when he jumps. default 200    |
| E:plySetGravity(N)                |        | Sets the gravity of the player. default 600                                                    |
| E:plySetSpeed(N)                  |        | Sets the walk and run speed of the player. (run speed is double of the walk speed) default 200 |
| E:plySetWalkSpeed(N)              |        | Sets the walk speed of the player. default 200                                                 |
| E:plySetRunSpeed(N)               |        | Sets the run speed of the player. default 400                                                  |

### Actions
| Function                          | Return | Description                                                                                    |
|-----------------------------------|:------:|------------------------------------------------------------------------------------------------|
| E:plyApplyForce(vector force)     |        | Sets the velocity of the player.                                                               |
| E:plyFreeze(N)                    |        | Freezes the player.                                                                            |
| E:plyResetSettings()              |        | Resets the settings of the player.                                                             |

### Utility Functions
| Function                          | Return | Description                                                                                    |
|-----------------------------------|:------:|------------------------------------------------------------------------------------------------|
| E:plyInBounds()                   | N      | Returns 1 if the player is within allowed boundaries, 0 otherwise. Always returns 1 on non-MBRP maps. |
| E:plyIsAdminMode()                | N      | Returns 1 if the player is in admin mode, 0 otherwise.       

### Access Control

All functions include comprehensive access control through the `PlyCoreCommand` hook and a customizable `hasAccess` function. The system is designed to be flexible for different server environments while preventing abuse.                                 |

#### Access Control Logic

The addon uses a tiered permission system that adapts to different server configurations:

**MBRP Servers (with Event Mode support):**
- **Event Team Access**: Members with "Event Team" user group who are in event mode have full access
- **Boundary Restrictions**: On `rp_exhib_border*` maps, most commands are restricted to a specific area:
  - Allowed area: X: 6000 to -10000, Y: 6000 to -10000, Z: 3000 to 11000 (grass area)
  - Commands outside boundaries are blocked to prevent disruption
- **Protected Players**: Commands cannot target players in admin mode
- **Special Exceptions**: Three commands work everywhere for safety and convenience:
  - `plyResetSettings()` - Allows resetting players who leave the event area
  - `plyInBounds()` - Prevents chip crashes from position checks
  - `plyIsAdminMode()` - Prevents chip crashes from admin status checks
- **Fallback Access**: Non-event team members must be server admins to use any functions

**Standard Servers:**
- **Admin-Only Access**: All functions require admin privileges
- **No Restrictions**: No boundary limitations or special maps handling

[PlayerCore Workshop Page]: <https://steamcommunity.com/sharedfiles/filedetails/?id=216044582>
[Expression 2 Core Collection]: <https://steamcommunity.com/workshop/filedetails/?id=726399057>
[GitHub Page]: <https://github.com/sirpapate/playercore>