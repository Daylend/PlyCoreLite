# PlayerCore - Minimal Edition

A stripped-down version of PlayerCore, an extension for Expression 2 that provides basic player manipulation functions. Access control is implemented through a customizable system.

## Workshop Installation

The PlayerCore is available on the Steam Workshop! Go to the [PlayerCore Workshop Page][PlayerCore Workshop Page] and press `Subscribe`. For can go to the [Expression 2 Core Collection][Expression 2 Core Collection] for more extensions.

## Manual Installation

Clone this repository into your `steamapps\common\GarrysMod\garrysmod\addons` folder using this command if you are using git:

    git clone https://github.com/sirpapate/playercore.git

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

### Access Control

All functions include access control through the `PlyCoreCommand` hook and a customizable `hasAccess` function. Server administrators can implement their own access control logic by modifying the `hasAccess` function in the code.

[PlayerCore Workshop Page]: <https://steamcommunity.com/sharedfiles/filedetails/?id=216044582>
[Expression 2 Core Collection]: <https://steamcommunity.com/workshop/filedetails/?id=726399057>
[GitHub Page]: <https://github.com/sirpapate/playercore>