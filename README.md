# Checkskill System Showcase

This repository contains a Roblox Luau client script from my game **Nuke a Brainrot**.

## What this script does

This script handles a custom proximity-prompt-driven skill check system used in the game’s farming/progression loop.

It includes:
- Custom proximity prompt UI
- Prompt filtering for different interaction types
- Randomized skill check placement
- Stage-based difficulty scaling
- Real-time input validation
- Client-side feedback with server result reporting
- UI focus mode while the minigame is active

## Demo game

Full game link:  
https://www.roblox.com/games/85015843649922/Nuke-a-Brainrot

## How to test

This game link is the full live version of the project.

To test this script:
1. Join the game.
2. pick up 2 bombs and use them on brainrott since you need 100 coins to buy farm
3. Buy a farm.
4. Walk up to the farm interaction point.
5. Use the proximity prompt.
6. The skill check UI should appear.
7. Press `E` or click at the correct timing to clear stages.
8. The result is sent back to the server and used by the game’s progression flow.

## Notes for reviewers

This example is meant to show:
- Roblox API usage across UI, prompts, remotes, input, tweening, sound, and camera-space positioning
- Clean function-based organization
- Gameplay state management
- A practical client/server gameplay interaction used in a live Roblox game
