// NPC State Manager - Individual NPC behavior synchronization
// Handles position, animation, AI state, and behavior synchronization for each NPC

module CyberpunkMP.World

import Codeware.UI.*
import Codeware.Localization.*

// Individual NPC State Manager - tracks and synchronizes a single NPC
public class NPCStateManager extends IScriptable {
    private let m_npc: wref<NPCPuppet>;
    private let m_npcId: Uint64;
    private let m_npcType: ENPCType;
    private let m_isLocallyOwned: Bool;

    // State tracking
    private let m_lastPosition: Vector3;
    private let m_lastRotation: Quaternion;
    private let m_lastVelocity: Vector3;
    private let m_lastAnimState: CName;
    private let m_lastBehaviorState: gamedataNPCBehaviorState;
    private let m_lastHealth: Float;
    private let m_lastCombatState: ENPCCombatState;
    private let m_lastDialogueState: ENPCDialogueState;
    private let m_lastInteractionState: Bool;

    // Change detection
    private let m_hasStateChanged: Bool = false;
    private let m_lastSyncTime: Float = 0.0;
    private let m_positionThreshold: Float = 0.3;  // 30cm movement threshold
    private let m_rotationThreshold: Float = 0.05; // 3 degree rotation threshold
    private let m_healthThreshold: Float = 5.0;    // 5 HP change threshold

    // Interpolation for smooth remote updates
    private let m_targetPosition: Vector3;
    private let m_targetRotation: Quaternion;
    private let m_interpolationSpeed: Float = 10.0;
    private let m_isInterpolating: Bool = false;

    // AI State preservation
    private let m_originalAIComponent: wref<AIComponent>;
    private let m_behaviorStack: array<CName> = [];
    private let m_preserveAI: Bool = true;

    public func Initialize(npc: ref<NPCPuppet>, npcType: ENPCType) -> Void {
        this.m_npc = npc;
        this.m_npcId = Cast<Uint64>(npc.GetEntityID());
        this.m_npcType = npcType;
        this.m_isLocallyOwned = true; // This client spawned/owns this NPC

        // Get AI component for behavior preservation (updated for red4ext 1.29.1+)
        this.m_originalAIComponent = npc.GetAIComponent();

        // Initialize state tracking
        this.UpdateCurrentState();
        this.CaptureAIBehaviorStack();

        // Configure NPC for multiplayer
        this.ConfigureNPCForMultiplayer();

        LogChannel(n"NPCState", s"[NPCState] Initialized NPC manager for: " + this.m_npcId + " Type: " + ToString(EnumInt(npcType)));
    }

    public func Update(deltaTime: Float) -> Void {
        if !IsDefined(this.m_npc) {
            return;
        }

        // Update interpolation for remote NPCs
        if this.m_isInterpolating && !this.m_isLocallyOwned {
            this.UpdateInterpolation(deltaTime);
        }

        // Update state tracking for local NPCs
        if this.m_isLocallyOwned {
            this.UpdateCurrentState();
            this.DetectStateChanges();
        }

        // Preserve AI behavior
        if this.m_preserveAI {
            this.MaintainAIBehavior();
        }
    }

    private func UpdateCurrentState() -> Void {
        let currentPosition = this.m_npc.GetWorldPosition();
        let currentRotation = this.m_npc.GetWorldOrientation();
        let currentVelocity = this.GetNPCVelocity();
        let currentAnimState = this.GetCurrentAnimation();
        let currentBehaviorState = this.GetBehaviorState();
        let currentHealth = this.GetNPCHealth();
        let currentCombatState = this.GetCombatState();
        let currentDialogueState = this.GetDialogueState();
        let currentInteractionState = this.GetInteractionAvailable();

        // Store current state
        this.m_lastPosition = currentPosition;
        this.m_lastRotation = currentRotation;
        this.m_lastVelocity = currentVelocity;
        this.m_lastAnimState = currentAnimState;
        this.m_lastBehaviorState = currentBehaviorState;
        this.m_lastHealth = currentHealth;
        this.m_lastCombatState = currentCombatState;
        this.m_lastDialogueState = currentDialogueState;
        this.m_lastInteractionState = currentInteractionState;
    }

    private func DetectStateChanges() -> Void {
        let currentPosition = this.m_npc.GetWorldPosition();
        let currentRotation = this.m_npc.GetWorldOrientation();
        let currentHealth = this.GetNPCHealth();
        let currentAnimState = this.GetCurrentAnimation();
        let currentBehaviorState = this.GetBehaviorState();
        let currentCombatState = this.GetCombatState();
        let currentDialogueState = this.GetDialogueState();

        // Check for significant changes that require synchronization
        let positionChanged = Vector4.Distance(this.m_lastPosition, currentPosition) > this.m_positionThreshold;
        let rotationChanged = !this.QuaternionEquals(this.m_lastRotation, currentRotation, this.m_rotationThreshold);
        let healthChanged = AbsF(this.m_lastHealth - currentHealth) > this.m_healthThreshold;
        let animChanged = !Equals(this.m_lastAnimState, currentAnimState);
        let behaviorChanged = !Equals(this.m_lastBehaviorState, currentBehaviorState);
        let combatChanged = !Equals(this.m_lastCombatState, currentCombatState);
        let dialogueChanged = !Equals(this.m_lastDialogueState, currentDialogueState);

        if positionChanged || rotationChanged || healthChanged || animChanged ||
           behaviorChanged || combatChanged || dialogueChanged {
            this.m_hasStateChanged = true;
        }
    }

    private func ConfigureNPCForMultiplayer() -> Void {
        // Configure NPC based on type while preserving singleplayer behavior
        switch this.m_npcType {
            case ENPCType.Police:
                this.ConfigurePoliceNPC();
                break;
            case ENPCType.Enemy:
                this.ConfigureEnemyNPC();
                break;
            case ENPCType.QuestNPC:
                this.ConfigureQuestNPC();
                break;
            case ENPCType.Vendor:
                this.ConfigureVendorNPC();
                break;
            case ENPCType.Civilian:
                this.ConfigureCivilianNPC();
                break;
            case ENPCType.Driver:
                this.ConfigureDriverNPC();
                break;
            case ENPCType.Gangster:
                this.ConfigureGangsterNPC();
                break;
            case ENPCType.Corporate:
                this.ConfigureCorporateNPC();
                break;
        }
    }

    private func ConfigurePoliceNPC() -> Void {
        if IsDefined(this.m_originalAIComponent) {
            // Maintain police AI behavior - response to wanted level, patrol routes
            this.m_originalAIComponent.SetBehaviorArgument(n"PoliceAI", ToVariant(true));
            this.m_originalAIComponent.SetBehaviorArgument(n"respondToWantedLevel", ToVariant(true));
            this.m_originalAIComponent.SetBehaviorArgument(n"maintainPatrol", ToVariant(true));
        }

        // Police NPCs need high sync priority
        this.m_positionThreshold = 0.2;
        this.m_rotationThreshold = 0.03;
    }

    private func ConfigureEnemyNPC() -> Void {
        if IsDefined(this.m_originalAIComponent) {
            // Maintain hostile AI behavior
            this.m_originalAIComponent.SetBehaviorArgument(n"HostileAI", ToVariant(true));
            this.m_originalAIComponent.SetBehaviorArgument(n"engageTargets", ToVariant(true));
            this.m_originalAIComponent.SetBehaviorArgument(n"groupCombat", ToVariant(true));
        }

        // Enemy NPCs need highest sync priority
        this.m_positionThreshold = 0.15;
        this.m_rotationThreshold = 0.02;
        this.m_healthThreshold = 1.0;
    }

    private func ConfigureQuestNPC() -> Void {
        if IsDefined(this.m_originalAIComponent) {
            // Maintain quest-specific behavior
            this.m_originalAIComponent.SetBehaviorArgument(n"QuestNPC", ToVariant(true));
            this.m_originalAIComponent.SetBehaviorArgument(n"followQuestLogic", ToVariant(true));
            this.m_originalAIComponent.SetBehaviorArgument(n"maintainDialogue", ToVariant(true));
        }

        // Quest NPCs need critical sync for interactions
        this.m_positionThreshold = 0.1;
        this.m_rotationThreshold = 0.02;
    }

    private func ConfigureVendorNPC() -> Void {
        // Vendors are usually stationary - maintain store behavior
        if IsDefined(this.m_originalAIComponent) {
            this.m_originalAIComponent.SetBehaviorArgument(n"VendorAI", ToVariant(true));
            this.m_originalAIComponent.SetBehaviorArgument(n"maintainStore", ToVariant(true));
        }

        // Vendors have lower position sync needs but high interaction sync
        this.m_positionThreshold = 1.0;
        this.m_rotationThreshold = 0.1;
    }

    private func ConfigureCivilianNPC() -> Void {
        if IsDefined(this.m_originalAIComponent) {
            // Maintain civilian behavior - reactions, crowds, daily routines
            this.m_originalAIComponent.SetBehaviorArgument(n"CivilianAI", ToVariant(true));
            this.m_originalAIComponent.SetBehaviorArgument(n"reactToViolence", ToVariant(true));
            this.m_originalAIComponent.SetBehaviorArgument(n"crowdBehavior", ToVariant(true));
            this.m_originalAIComponent.SetBehaviorArgument(n"dailyRoutine", ToVariant(true));
        }

        // Civilians can have lower sync priority
        this.m_positionThreshold = 0.5;
        this.m_rotationThreshold = 0.1;
    }

    private func ConfigureDriverNPC() -> Void {
        if IsDefined(this.m_originalAIComponent) {
            // Maintain driving AI behavior
            this.m_originalAIComponent.SetBehaviorArgument(n"DriverAI", ToVariant(true));
            this.m_originalAIComponent.SetBehaviorArgument(n"followTraffic", ToVariant(true));
            this.m_originalAIComponent.SetBehaviorArgument(n"avoidCollisions", ToVariant(true));
        }

        // Drivers need moderate sync for traffic flow
        this.m_positionThreshold = 0.4;
        this.m_rotationThreshold = 0.05;
    }

    private func ConfigureGangsterNPC() -> Void {
        if IsDefined(this.m_originalAIComponent) {
            // Maintain gang behavior
            this.m_originalAIComponent.SetBehaviorArgument(n"GangAI", ToVariant(true));
            this.m_originalAIComponent.SetBehaviorArgument(n"territorialBehavior", ToVariant(true));
            this.m_originalAIComponent.SetBehaviorArgument(n"groupLoyalty", ToVariant(true));
        }

        // Gangsters need good sync for territory control
        this.m_positionThreshold = 0.25;
        this.m_rotationThreshold = 0.04;
    }

    private func ConfigureCorporateNPC() -> Void {
        if IsDefined(this.m_originalAIComponent) {
            // Maintain corporate behavior
            this.m_originalAIComponent.SetBehaviorArgument(n"CorporateAI", ToVariant(true));
            this.m_originalAIComponent.SetBehaviorArgument(n"professionalBehavior", ToVariant(true));
            this.m_originalAIComponent.SetBehaviorArgument(n"securityProtocols", ToVariant(true));
        }

        // Corporate NPCs moderate sync
        this.m_positionThreshold = 0.3;
        this.m_rotationThreshold = 0.06;
    }

    // === AI Behavior Preservation ===

    private func CaptureAIBehaviorStack() -> Void {
        if IsDefined(this.m_originalAIComponent) {
            // Capture current behavior stack to preserve AI state
            this.m_behaviorStack = this.m_originalAIComponent.GetBehaviorStack();
        }
    }

    private func MaintainAIBehavior() -> Void {
        if !IsDefined(this.m_originalAIComponent) || !this.m_isLocallyOwned {
            return;
        }

        // Ensure AI behavior is maintained in multiplayer
        // This prevents NPCs from losing their AI when synchronized
        let currentStack = this.m_originalAIComponent.GetBehaviorStack();

        if ArraySize(currentStack) == 0 && ArraySize(this.m_behaviorStack) > 0 {
            // AI behavior was lost, restore it
            for behavior in this.m_behaviorStack {
                this.m_originalAIComponent.PushBehavior(behavior);
            }

            LogChannel(n"NPCState", s"[NPCState] Restored AI behavior for NPC: " + this.m_npcId);
        }
    }

    // === Remote State Application ===

    public func ApplyRemoteUpdate(syncData: NPCSyncData) -> Void {
        if !IsDefined(this.m_npc) || this.m_isLocallyOwned {
            return; // Don't apply remote updates to locally owned NPCs
        }

        // Set target state for interpolation
        this.m_targetPosition = syncData.position;
        this.m_targetRotation = syncData.rotation;
        this.m_isInterpolating = true;

        // Apply immediate state changes
        this.ApplyAnimation(syncData.animationState);
        this.ApplyBehaviorState(syncData.behaviorState);
        this.ApplyHealth(syncData.health);
        this.ApplyCombatState(syncData.combatState);
        this.ApplyDialogueState(syncData.dialogueState);

        LogChannel(n"NPCState", s"[NPCState] Applied remote update for NPC: " + this.m_npcId);
    }

    private func UpdateInterpolation(deltaTime: Float) -> Void {
        if !this.m_isInterpolating {
            return;
        }

        let currentPosition = this.m_npc.GetWorldPosition();
        let currentRotation = this.m_npc.GetWorldOrientation();

        // Interpolate position
        let newPosition = Vector4.Interpolate(currentPosition, this.m_targetPosition,
                                            deltaTime * this.m_interpolationSpeed);

        // Interpolate rotation
        let newRotation = Quaternion.Slerp(currentRotation, this.m_targetRotation,
                                         deltaTime * this.m_interpolationSpeed);

        // Apply interpolated transform
        let distance = Vector4.Distance(currentPosition, this.m_targetPosition);
        if distance > 0.05 {
            // Smooth movement
            this.m_npc.TeleportToPosition(newPosition);
            this.m_npc.SetWorldOrientation(newRotation);
        } else {
            // Close enough, stop interpolating
            this.m_npc.TeleportToPosition(this.m_targetPosition);
            this.m_npc.SetWorldOrientation(this.m_targetRotation);
            this.m_isInterpolating = false;
        }
    }

    private func ApplyAnimation(animState: CName) -> Void {
        if !Equals(animState, n"") {
            let animComponent = this.m_npc.GetAnimationComponent();
            if IsDefined(animComponent) {
                animComponent.SetAnimationState(animState);
            }
        }
    }

    private func ApplyBehaviorState(behaviorState: gamedataNPCBehaviorState) -> Void {
        if IsDefined(this.m_originalAIComponent) {
            this.m_originalAIComponent.SetBehaviorArgument(n"behaviorState", ToVariant(EnumInt(behaviorState)));
        }
    }

    private func ApplyHealth(newHealth: Float) -> Void {
        if newHealth > 0.0 {
            let healthSystem = GameInstance.GetStatPoolsSystem(this.m_npc.GetGame());
            let npcID = Cast<StatsObjectID>(this.m_npc.GetEntityID());
            healthSystem.RequestSettingStatPoolValue(npcID, gamedataStatPoolType.Health, newHealth, null);
        }
    }

    private func ApplyCombatState(combatState: ENPCCombatState) -> Void {
        if IsDefined(this.m_originalAIComponent) {
            this.m_originalAIComponent.SetBehaviorArgument(n"combatState", ToVariant(EnumInt(combatState)));
        }
    }

    private func ApplyDialogueState(dialogueState: ENPCDialogueState) -> Void {
        // Apply dialogue availability state
        let dialogueComponent = this.m_npc.GetComponent(n"DialogueComponent");
        if IsDefined(dialogueComponent) {
            switch dialogueState {
                case ENPCDialogueState.Available:
                    dialogueComponent.EnableDialogue();
                    break;
                case ENPCDialogueState.Unavailable:
                    dialogueComponent.DisableDialogue();
                    break;
            }
        }
    }

    // === State Getters ===

    private func GetNPCVelocity() -> Vector3 {
        // Calculate velocity from position change
        let currentTime = EngineTime.ToFloat(GameInstance.GetSimTime(GetGameInstance()));
        let deltaTime = currentTime - this.m_lastSyncTime;

        if deltaTime > 0.0 {
            let deltaPosition = Vector4.DistanceVector(this.m_lastPosition, this.m_npc.GetWorldPosition());
            return Vector4.Vector4To3(Vector4.MultiplyByFloat(deltaPosition, 1.0 / deltaTime));
        }

        return Vector3.Zero();
    }

    private func GetCurrentAnimation() -> CName {
        let animComponent = this.m_npc.GetAnimationComponent();
        if IsDefined(animComponent) {
            return animComponent.GetCurrentAnimationState();
        }
        return n"";
    }

    private func GetBehaviorState() -> gamedataNPCBehaviorState {
        // Get current behavior state from AI
        if IsDefined(this.m_originalAIComponent) {
            let behaviorArg = this.m_originalAIComponent.GetBehaviorArgument(n"behaviorState");
            if IsDefined(behaviorArg) {
                return IntEnum(FromVariant<Int32>(behaviorArg));
            }
        }
        return gamedataNPCBehaviorState.Normal;
    }

    private func GetNPCHealth() -> Float {
        let healthSystem = GameInstance.GetStatPoolsSystem(this.m_npc.GetGame());
        let npcID = Cast<StatsObjectID>(this.m_npc.GetEntityID());
        let healthPool = healthSystem.GetStatPoolValue(npcID, gamedataStatPoolType.Health);
        return healthPool.current;
    }

    private func GetCombatState() -> ENPCCombatState {
        let psmSystem = GameInstance.GetPlayerStateMachineSystem(this.m_npc.GetGame());

        if !this.IsAlive() {
            return ENPCCombatState.Dead;
        } else if psmSystem.IsInCombat(this.m_npc.GetEntityID()) {
            return ENPCCombatState.InCombat;
        } else if this.IsNPCAlert() {
            return ENPCCombatState.Alert;
        } else if this.IsNPCSearching() {
            return ENPCCombatState.Searching;
        } else if this.IsNPCFleeing() {
            return ENPCCombatState.Fleeing;
        }

        return ENPCCombatState.Passive;
    }

    private func GetDialogueState() -> ENPCDialogueState {
        let dialogueComponent = this.m_npc.GetComponent(n"DialogueComponent");
        if IsDefined(dialogueComponent) {
            if dialogueComponent.IsInDialogue() {
                return ENPCDialogueState.InProgress;
            } else if dialogueComponent.HasAvailableChoices() {
                return ENPCDialogueState.Available;
            } else if dialogueComponent.IsDialogueCompleted() {
                return ENPCDialogueState.Completed;
            } else if !dialogueComponent.IsDialogueEnabled() {
                return ENPCDialogueState.Unavailable;
            }
        }
        return ENPCDialogueState.None;
    }

    private func GetInteractionAvailable() -> Bool {
        let interactionComponent = this.m_npc.GetComponent(n"InteractionComponent");
        if IsDefined(interactionComponent) {
            return interactionComponent.IsInteractionAvailable();
        }
        return false;
    }

    // === Helper Functions ===

    private func IsAlive() -> Bool {
        return this.GetNPCHealth() > 0.0;
    }

    private func IsNPCAlert() -> Bool {
        // Check if NPC is in alert state
        if IsDefined(this.m_originalAIComponent) {
            let alertArg = this.m_originalAIComponent.GetBehaviorArgument(n"isAlert");
            if IsDefined(alertArg) {
                return FromVariant<Bool>(alertArg);
            }
        }
        return false;
    }

    private func IsNPCSearching() -> Bool {
        // Check if NPC is searching for targets
        if IsDefined(this.m_originalAIComponent) {
            let searchArg = this.m_originalAIComponent.GetBehaviorArgument(n"isSearching");
            if IsDefined(searchArg) {
                return FromVariant<Bool>(searchArg);
            }
        }
        return false;
    }

    private func IsNPCFleeing() -> Bool {
        // Check if NPC is fleeing
        if IsDefined(this.m_originalAIComponent) {
            let fleeArg = this.m_originalAIComponent.GetBehaviorArgument(n"isFleeing");
            if IsDefined(fleeArg) {
                return FromVariant<Bool>(fleeArg);
            }
        }
        return false;
    }

    private func QuaternionEquals(q1: Quaternion, q2: Quaternion, tolerance: Float) -> Bool {
        return AbsF(q1.i - q2.i) < tolerance &&
               AbsF(q1.j - q2.j) < tolerance &&
               AbsF(q1.k - q2.k) < tolerance &&
               AbsF(q1.r - q2.r) < tolerance;
    }

    // === Public Interface ===

    public func CreateSyncData() -> NPCSyncData {
        let syncData: NPCSyncData;
        syncData.npcId = this.m_npcId;
        syncData.position = this.m_lastPosition;
        syncData.rotation = this.m_lastRotation;
        syncData.animationState = this.m_lastAnimState;
        syncData.behaviorState = this.m_lastBehaviorState;
        syncData.health = this.m_lastHealth;
        syncData.combatState = this.m_lastCombatState;
        syncData.dialogueState = this.m_lastDialogueState;
        syncData.isAlive = this.IsAlive();
        syncData.timestamp = EngineTime.ToFloat(GameInstance.GetSimTime(GetGameInstance()));

        return syncData;
    }

    public func SetAsRemoteOwned() -> Void {
        this.m_isLocallyOwned = false;
        this.m_preserveAI = false; // Remote NPCs shouldn't run local AI
    }

    public func RequiresSync() -> Bool {
        return this.m_hasStateChanged && this.m_isLocallyOwned;
    }

    public func MarkAsSynced() -> Void {
        this.m_hasStateChanged = false;
        this.m_lastSyncTime = EngineTime.ToFloat(GameInstance.GetSimTime(GetGameInstance()));
    }

    public func ForceSync() -> Void {
        this.m_hasStateChanged = true;
    }

    // Getters
    public func GetNPCId() -> Uint64 { return this.m_npcId; }
    public func GetNPC() -> ref<NPCPuppet> { return this.m_npc; }
    public func GetNPCType() -> ENPCType { return this.m_npcType; }
    public func IsLocallyOwned() -> Bool { return this.m_isLocallyOwned; }
    public func GetPosition() -> Vector3 { return this.m_lastPosition; }
    public func GetRotation() -> Quaternion { return this.m_lastRotation; }
    public func GetHealth() -> Float { return this.m_lastHealth; }
    public func GetCombatStateEnum() -> ENPCCombatState { return this.m_lastCombatState; }
    public func GetDialogueStateEnum() -> ENPCDialogueState { return this.m_lastDialogueState; }
}