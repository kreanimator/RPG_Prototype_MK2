# Torso Split System Setup

## Overview
The torso split system has been successfully migrated from RPG_Prototype to rpg-prototype-mk2 and adapted for point-and-click gameplay.

## Scene Structure

### PlayerModel Scene (`scenes/player/player_model.tscn`)
```
PlayerModel (Node)
├── Resources (PlayerResources)
├── AreaAwareness (AreaAwareness)
├── Combat (HumanoidCombat)
├── Torso (TorsoMachine)
│   ├── Idle (TorsoBehaviour)
│   ├── Walk (TorsoBehaviour)
│   └── Run (TorsoBehaviour)
├── Legs (LegsMachine)
│   ├── Behaviours (LegsBehavioursContainer)
│   │   ├── Idle (LegsBehaviour)
│   │   ├── Walk (LegsBehaviour)
│   │   └── Run (LegsBehaviour)
│   └── Actions (LegsActionsContainer)
│       ├── Idle (LegsAction)
│       ├── Walk (LegsAction)
│       └── Run (LegsAction)
├── TorsoAnimationSettings (AnimationPlayer)
├── LegsAnimationSettings (AnimationPlayer)
├── SkeletonAnimator (AnimationPlayer)
└── GeneralSkeleton (Skeleton3D)
    ├── TorsoSimple (AnimatorModifier)
    ├── LegsSimple (AnimatorModifier)
    └── LegsLoco (Locomotion)
```

## Key Features

### 🎯 **Point-and-Click Integration**
- Automatic state transitions based on movement velocity
- Simplified input mapping for navigation-based gameplay
- Behavior mapping: `idle` → `walk` → `run`

### 🔄 **Dual State Machine**
- **Torso Machine**: Manages upper body behaviors
- **Legs Machine**: Manages lower body locomotion
- Independent animation systems with smooth blending

### 🎨 **Animation System**
- **Simple Animator**: Basic animation playback with blending
- **Locomotion Animator**: Advanced directional animation blending
- **Split Body**: Apply different animations to torso and legs simultaneously

### ⚡ **Resource Management**
- Stamina system with regeneration
- Behavior cost validation
- Fatigue status effects

## Current Implementation

### ✅ **Completed**
- Core state machine architecture
- Basic behaviors (Idle, Walk, Run)
- Animation system integration
- Point-and-click movement integration
- Resource management system
- Scene structure setup

### 🔧 **Still Needed**
1. **Character Model**: Import and configure your 3D character model
2. **Animations**: Add animation resources to SkeletonAnimator
3. **Skeleton Masks**: Create torso/legs separation masks
4. **Bone Track Maps**: Generate bone mapping resources
5. **Testing**: Test with actual character animations

## Setup Instructions

### 1. Import Character Model
- Import your 3D character model with animations
- Ensure the skeleton is named "GeneralSkeleton"
- Add the model as a child of the GeneralSkeleton node

### 2. Configure Animations
- Add animations to the SkeletonAnimator AnimationPlayer
- Required animations: "idle", "walk_n", "run_n"
- Optional: Directional animations (walk_e, walk_w, walk_s, etc.)

### 3. Create Resources
- Generate skeleton masks for torso/legs separation
- Create bone track maps using BoneTrackMap.bake()
- Assign resources to the appropriate skeleton modifiers

### 4. Test
- Open `scenes/test_torso_split.tscn`
- Run the scene to test the system
- Click to move and observe state transitions

## Behavior Mapping

The system automatically maps movement states to behaviors:

| Movement State | Torso Behavior | Legs Behavior | Animation |
|---------------|----------------|---------------|-----------|
| Stationary    | Idle           | Idle          | idle      |
| Slow Movement | Walk           | Walk          | walk_n    |
| Fast Movement | Run            | Run           | run_n     |

## Extending the System

### Adding New Behaviors
1. Create new behavior script extending TorsoBehaviour or LegsBehaviour
2. Add behavior node to appropriate machine in the scene
3. Configure behavior_name and priority
4. Update behavior_map in TorsoBehaviour if needed

### Adding Combat/Interaction
1. Extend the Combat system (placeholder currently exists)
2. Add new torso behaviors for combat actions
3. Configure behavior priorities and transitions
4. Add required animations

The system is designed to be extensible and can easily accommodate additional gameplay mechanics while maintaining the core torso/legs separation architecture.