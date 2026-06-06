# Checkskill System Showcase

This repository contains a Roblox Luau client/server skill-check system from my game **Nuke a Brainrot**.

## What this system does

This system handles a custom proximity-prompt-driven skill check used in the game’s farming/progression loop.

It includes:

- Custom proximity prompt UI
- Prompt filtering for different interaction types
- Randomized skill check placement
- Stage-based difficulty scaling
- Real-time input validation
- Client-side feedback with server result reporting
- Server-side cooldown and request validation
- Farm ownership and distance checks
- Server-owned buff/reward logic
- UI focus mode while the minigame is active

## Files

- `CheckSkillClient.client.lua`  
  Handles the local UI, custom prompt display, skill-check stages, input detection, and result reporting.

- `CheckSkillService.server.lua`  
  Validates skill-check requests, checks farm ownership/distance, manages cooldowns, starts active sessions, clamps results, and applies the server-side buff.

- `SkillCheckConfig.lua`  
  Stores server-owned tuning values such as cooldown, active window, max distance, stage boosts, and difficulty modifiers.

## Demo game

Full game link:  
https://www.roblox.com/games/85015843649922/Nuke-a-Brainrot

## How to test

1. Join the game.
2. Pick up bombs and use them on brainrots until you have enough coins to buy a farm.
3. Buy a farm.
4. Walk up to the farm interaction point.
5. Use the proximity prompt.
6. The skill check UI should appear.
7. Press `E` or click at the correct timing to clear stages.
8. The result is sent back to the server, where the reward/buff logic is validated and applied.

## Ownership / Studio Proof

These screenshots show that the system is from my Roblox Studio project and that I have access to the live experience, Studio project, scripts, and creator dashboard.

![Creator Dashboard ownership proof](PASTE_DIRECT_IMAGE_LINK_HERE)

![Roblox Studio project view](PASTE_DIRECT_IMAGE_LINK_HERE)

![Skill check running in Studio](PASTE_DIRECT_IMAGE_LINK_HERE)

## Notes for reviewers

This example is meant to show:

- Roblox API usage across UI, prompts, remotes, input, sound, and camera-space positioning
- Clean client/server separation
- Server-side validation instead of trusting the client
- Cooldown and anti-spam handling
- Gameplay state management
- A practical client/server gameplay interaction used in a live Roblox game
