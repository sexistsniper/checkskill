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
2. Buy a farm.
3. Walk up to the farm interaction point.
4. Use the proximity prompt.
5. The skill check UI should appear.
6. Press `E` or click at the correct timing to clear stages.
7. The result is sent back to the server and used by the game’s progression flow.

## Notes for reviewers

This example is meant to show:
- Roblox API usage across UI, prompts, remotes, input, tweening, sound, and camera-space positioning
- Clean function-based organization
- Gameplay state management
- A practical client/server gameplay interaction used in a live Roblox game
