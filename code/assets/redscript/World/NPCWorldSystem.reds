// NPC World System for CyberpunkMP
// Comprehensive NPC spawning and synchronization to make the world look exactly like singleplayer
// Automatically detects and synchronizes all NPCs, crowds, vendors, police, enemies, and quest characters

module CyberpunkMP.World

import Codeware.UI.*
import Codeware.Localization.*

// Main NPC World System - coordinates all NPC activity in multiplayer
public class NPCWorldSystem extends IScriptable {
    private static let s_instance: ref<NPCWorldSystem>;
    private let m_isInitialized: Bool = false;
    private let m_trackedNPCs: array<ref<NPCStateManager>> = [];
    private let m_questNPCs: array<ref<QuestNPCManager>> = [];
    private let m_policeManager: ref<PoliceResponseManager>;
    private let m_crowdManager: ref<CrowdPopulationManager>;
    private let m_vendorManager: ref<VendorNetworkManager>;
    private let m_trafficManager: ref<TrafficSystemManager>;
    private let m_ambientManager: ref<AmbientActivityManager>;

    // Sync timers for different NPC types
    private let m_npcSyncTimer: Float = 0.0;
    private let m_questSyncTimer: Float = 0.0;
    private let m_crowdSyncTimer: Float = 0.0;
    private let m_policeSyncTimer: Float = 0.0;

    // Sync intervals (in seconds)
    private let QUEST_NPC_SYNC_INTERVAL: Float = 0.05;   // 20 FPS - highest priority
    private let POLICE_SYNC_INTERVAL: Float = 0.05;     // 20 FPS - high priority
    private let REGULAR_NPC_SYNC_INTERVAL: Float = 0.1;  // 10 FPS - normal priority
    private let CROWD_SYNC_INTERVAL: Float = 0.2;       // 5 FPS - lower priority

    private let m_localPlayer: wref<PlayerPuppet>;
    private let m_isHost: Bool = false;

    public static func GetInstance() -> ref<NPCWorldSystem> {
        if !IsDefined(NPCWorldSystem.s_instance) {
            NPCWorldSystem.s_instance = new NPCWorldSystem();
        }
        return NPCWorldSystem.s_instance;
    }

    protected func OnAttach() -> Void {
        this.Initialize();
    }

    public func Initialize() -> Void {
        if this.m_isInitialized {
            return;
        }

        LogChannel(n"NPCWorld", "[NPCWorld] Initializing NPC World System...");

        this.m_localPlayer = GetPlayer(GetGameInstance());
        this.m_isHost = this.DetermineIfHost();

        // Initialize all subsystems
        this.InitializeSubsystems();

        // Start automatic NPC detection and synchronization
        this.StartNPCDiscovery();

        // Hook into game systems for automatic integration
        this.RegisterGameSystemHooks();

        this.m_isInitialized = true;
        LogChannel(n"NPCWorld", "[NPCWorld] NPC World System fully initialized");
    }

    private func InitializeSubsystems() -> Void {
        // Police and wanted system
        this.m_policeManager = new PoliceResponseManager();
        this.m_policeManager.Initialize(this.m_isHost);

        // Crowd and civilian population
        this.m_crowdManager = new CrowdPopulationManager();
        this.m_crowdManager.Initialize(this.m_isHost);

        // Vendors and merchants
        this.m_vendorManager = new VendorNetworkManager();
        this.m_vendorManager.Initialize(this.m_isHost);

        // Vehicle traffic
        this.m_trafficManager = new TrafficSystemManager();
        this.m_trafficManager.Initialize(this.m_isHost);

        // Ambient activities
        this.m_ambientManager = new AmbientActivityManager();
        this.m_ambientManager.Initialize(this.m_isHost);

        LogChannel(n"NPCWorld", "[NPCWorld] All subsystems initialized");
    }

    private func StartNPCDiscovery() -> Void {
        // Automatically scan for existing NPCs in the world
        this.ScanForExistingNPCs();
        this.ScanForQuestNPCs();
        this.ScanForPoliceNPCs();
        this.ScanForVendorNPCs();

        // Start crowd population detection
        this.m_crowdManager.StartPopulationDetection();

        // Start traffic system monitoring
        this.m_trafficManager.StartTrafficMonitoring();

        LogChannel(n"NPCWorld", "[NPCWorld] NPC discovery completed - tracking " + ArraySize(this.m_trackedNPCs) + " NPCs");
    }

    private func ScanForExistingNPCs() -> Void {
        // Use game systems to find all existing NPCs
        let world = GetGameInstance();
        let allEntities = GameInstance.GetEntitySystem(world).GetAllEntities();

        for entity in allEntities {
            let npc = entity as NPCPuppet;
            if IsDefined(npc) && npc.IsNPC() {
                this.RegisterNPC(npc);
            }
        }
    }

    private func ScanForQuestNPCs() -> Void {
        let questSystem = GameInstance.GetQuestSystem(GetGameInstance());
        let questNPCs = questSystem.GetAllQuestRelatedNPCs();

        for questNPC in questNPCs {
            this.RegisterQuestNPC(questNPC);
        }

        LogChannel(n"NPCWorld", "[NPCWorld] Found " + ArraySize(this.m_questNPCs) + " quest-related NPCs");
    }

    private func ScanForPoliceNPCs() -> Void {
        this.m_policeManager.ScanForExistingPolice();
    }

    private func ScanForVendorNPCs() -> Void {
        this.m_vendorManager.ScanForExistingVendors();
    }

    protected func OnUpdate(deltaTime: Float) -> Void {
        if !this.m_isInitialized {
            return;
        }

        // Update all timers
        this.m_npcSyncTimer += deltaTime;
        this.m_questSyncTimer += deltaTime;
        this.m_crowdSyncTimer += deltaTime;
        this.m_policeSyncTimer += deltaTime;

        // Update subsystems at different frequencies
        this.UpdateQuestNPCs(deltaTime);
        this.UpdatePoliceSystem(deltaTime);
        this.UpdateRegularNPCs(deltaTime);
        this.UpdateCrowdSystem(deltaTime);

        // Update managers
        this.m_vendorManager.Update(deltaTime);
        this.m_trafficManager.Update(deltaTime);
        this.m_ambientManager.Update(deltaTime);
    }

    private func UpdateQuestNPCs(deltaTime: Float) -> Void {
        if this.m_questSyncTimer >= this.QUEST_NPC_SYNC_INTERVAL {
            for questNPC in this.m_questNPCs {
                questNPC.Update(deltaTime);
                if questNPC.HasCriticalStateChange() {
                    this.SyncQuestNPC(questNPC);
                }
            }
            this.m_questSyncTimer = 0.0;
        }
    }

    private func UpdatePoliceSystem(deltaTime: Float) -> Void {
        if this.m_policeSyncTimer >= this.POLICE_SYNC_INTERVAL {
            this.m_policeManager.Update(deltaTime);
            this.m_policeSyncTimer = 0.0;
        }
    }

    private func UpdateRegularNPCs(deltaTime: Float) -> Void {
        if this.m_npcSyncTimer >= this.REGULAR_NPC_SYNC_INTERVAL {
            for npcManager in this.m_trackedNPCs {
                npcManager.Update(deltaTime);
                if npcManager.RequiresSync() {
                    this.SyncNPC(npcManager);
                }
            }
            this.m_npcSyncTimer = 0.0;
        }
    }

    private func UpdateCrowdSystem(deltaTime: Float) -> Void {
        if this.m_crowdSyncTimer >= this.CROWD_SYNC_INTERVAL {
            this.m_crowdManager.Update(deltaTime);
            this.m_crowdSyncTimer = 0.0;
        }
    }

    // === NPC Registration System ===

    public func RegisterNPC(npc: ref<NPCPuppet>) -> Void {
        if !this.IsNPCTracked(npc) {
            let npcManager = new NPCStateManager();
            npcManager.Initialize(npc, this.DetermineNPCType(npc));
            ArrayPush(this.m_trackedNPCs, npcManager);

            // Route to specialized systems
            this.RouteNPCToSpecializedSystem(npc, npcManager.GetNPCType());

            // Broadcast spawn to other clients
            if this.m_isHost {
                this.BroadcastNPCSpawn(npc, npcManager.GetNPCType());
            }

            LogChannel(n"NPCWorld", "[NPCWorld] Registered NPC: " + npcManager.GetNPCId() + " Type: " + ToString(EnumInt(npcManager.GetNPCType())));
        }
    }

    public func RegisterQuestNPC(npc: ref<NPCPuppet>) -> Void {
        let questManager = new QuestNPCManager();
        questManager.Initialize(npc);
        ArrayPush(this.m_questNPCs, questManager);

        // Also register as regular NPC for basic tracking
        this.RegisterNPC(npc);

        LogChannel(n"NPCWorld", "[NPCWorld] Registered Quest NPC: " + questManager.GetNPCId());
    }

    public func UnregisterNPC(npcId: Uint64) -> Void {
        // Remove from regular tracking
        let index = this.FindNPCManagerIndex(npcId);
        if index >= 0 {
            let npcManager = this.m_trackedNPCs[index];
            this.RemoveFromSpecializedSystem(npcManager.GetNPC(), npcManager.GetNPCType());
            ArrayRemove(this.m_trackedNPCs, npcManager);
        }

        // Remove from quest tracking
        let questIndex = this.FindQuestNPCIndex(npcId);
        if questIndex >= 0 {
            ArrayRemove(this.m_questNPCs, this.m_questNPCs[questIndex]);
        }

        // Broadcast despawn
        if this.m_isHost {
            this.BroadcastNPCDespawn(npcId);
        }

        LogChannel(n"NPCWorld", "[NPCWorld] Unregistered NPC: " + npcId);
    }

    private func RouteNPCToSpecializedSystem(npc: ref<NPCPuppet>, npcType: ENPCType) -> Void {
        switch npcType {
            case ENPCType.Police:
                this.m_policeManager.RegisterPoliceNPC(npc);
                break;
            case ENPCType.Vendor:
                this.m_vendorManager.RegisterVendor(npc);
                break;
            case ENPCType.Civilian:
                this.m_crowdManager.RegisterCivilian(npc);
                break;
            case ENPCType.Driver:
                this.m_trafficManager.RegisterDriver(npc);
                break;
        }
    }

    private func RemoveFromSpecializedSystem(npc: ref<NPCPuppet>, npcType: ENPCType) -> Void {
        let npcId = Cast<Uint64>(npc.GetEntityID());

        switch npcType {
            case ENPCType.Police:
                this.m_policeManager.UnregisterPoliceNPC(npcId);
                break;
            case ENPCType.Vendor:
                this.m_vendorManager.UnregisterVendor(npcId);
                break;
            case ENPCType.Civilian:
                this.m_crowdManager.UnregisterCivilian(npcId);
                break;
            case ENPCType.Driver:
                this.m_trafficManager.UnregisterDriver(npcId);
                break;
        }
    }

    // === NPC Type Classification ===

    private func DetermineNPCType(npc: ref<NPCPuppet>) -> ENPCType {
        // Automatically classify NPCs based on their properties
        if this.IsPoliceNPC(npc) {
            return ENPCType.Police;
        } else if this.IsVendorNPC(npc) {
            return ENPCType.Vendor;
        } else if this.IsQuestNPC(npc) {
            return ENPCType.QuestNPC;
        } else if this.IsDriverNPC(npc) {
            return ENPCType.Driver;
        } else if this.IsEnemyNPC(npc) {
            return ENPCType.Enemy;
        } else if this.IsCorpoNPC(npc) {
            return ENPCType.Corporate;
        } else if this.IsGangNPC(npc) {
            return ENPCType.Gangster;
        }

        return ENPCType.Civilian; // Default
    }

    private func IsPoliceNPC(npc: ref<NPCPuppet>) -> Bool {
        let npcRecord = npc.GetRecord();
        return npcRecord.Affiliation().Type() == gamedataAffiliation.NCPD;
    }

    private func IsVendorNPC(npc: ref<NPCPuppet>) -> Bool {
        let vendorComponent = npc.GetComponent(n"VendorComponent");
        return IsDefined(vendorComponent);
    }

    private func IsQuestNPC(npc: ref<NPCPuppet>) -> Bool {
        let questSystem = GameInstance.GetQuestSystem(npc.GetGame());
        return questSystem.IsNPCInvolvedInQuest(npc.GetEntityID());
    }

    private func IsDriverNPC(npc: ref<NPCPuppet>) -> Bool {
        let vehicleComponent = npc.GetComponent(n"VehicleComponent");
        return IsDefined(vehicleComponent);
    }

    private func IsEnemyNPC(npc: ref<NPCPuppet>) -> Bool {
        let attitudeSystem = GameInstance.GetAttitudeSystem(npc.GetGame());
        let playerID = this.m_localPlayer.GetEntityID();
        let attitude = attitudeSystem.GetAttitudeTowards(npc.GetEntityID(), playerID);
        return Equals(attitude, EAIAttitude.AIA_Hostile);
    }

    private func IsCorpoNPC(npc: ref<NPCPuppet>) -> Bool {
        let npcRecord = npc.GetRecord();
        let affiliation = npcRecord.Affiliation().Type();
        return Equals(affiliation, gamedataAffiliation.Arasaka) ||
               Equals(affiliation, gamedataAffiliation.Militech) ||
               Equals(affiliation, gamedataAffiliation.KangTao);
    }

    private func IsGangNPC(npc: ref<NPCPuppet>) -> Bool {
        let npcRecord = npc.GetRecord();
        let affiliation = npcRecord.Affiliation().Type();
        return Equals(affiliation, gamedataAffiliation.Maelstrom) ||
               Equals(affiliation, gamedataAffiliation.Valentinos) ||
               Equals(affiliation, gamedataAffiliation.TygerClaws) ||
               Equals(affiliation, gamedataAffiliation.SixthStreet) ||
               Equals(affiliation, gamedataAffiliation.VoodooBoys) ||
               Equals(affiliation, gamedataAffiliation.AnimalsGang);
    }

    // === Network Synchronization ===

    private func SyncNPC(npcManager: ref<NPCStateManager>) -> Void {
        let syncData = npcManager.CreateSyncData();
        // Send to CyberpunkMP networking system
        this.SendNPCUpdate(syncData);
        npcManager.MarkAsSynced();
    }

    private func SyncQuestNPC(questNPC: ref<QuestNPCManager>) -> Void {
        let questData = questNPC.CreateQuestSyncData();
        this.SendQuestNPCUpdate(questData);
        questNPC.MarkAsSynced();
    }

    private func BroadcastNPCSpawn(npc: ref<NPCPuppet>, npcType: ENPCType) -> Void {
        let spawnData: NPCSpawnData;
        spawnData.npcId = Cast<Uint64>(npc.GetEntityID());
        spawnData.npcRecord = npc.GetRecordID();
        spawnData.position = npc.GetWorldPosition();
        spawnData.rotation = npc.GetWorldOrientation();
        spawnData.npcType = npcType;
        spawnData.appearance = npc.GetCurrentAppearanceName();
        spawnData.timestamp = EngineTime.ToFloat(GameInstance.GetSimTime(GetGameInstance()));

        this.SendNPCSpawn(spawnData);
    }

    private func BroadcastNPCDespawn(npcId: Uint64) -> Void {
        let despawnData: NPCDespawnData;
        despawnData.npcId = npcId;
        despawnData.timestamp = EngineTime.ToFloat(GameInstance.GetSimTime(GetGameInstance()));

        this.SendNPCDespawn(despawnData);
    }

    // === Network Event Handlers ===

    public func OnRemoteNPCSpawn(spawnData: NPCSpawnData) -> Void {
        LogChannel(n"NPCWorld", "[NPCWorld] Remote NPC spawn: " + spawnData.npcId);
        this.SpawnNPCFromRemoteData(spawnData);
    }

    public func OnRemoteNPCDespawn(despawnData: NPCDespawnData) -> Void {
        LogChannel(n"NPCWorld", "[NPCWorld] Remote NPC despawn: " + despawnData.npcId);
        this.DespawnNPCFromRemoteData(despawnData.npcId);
    }

    public func OnRemoteNPCUpdate(syncData: NPCSyncData) -> Void {
        let npcManager = this.FindNPCManager(syncData.npcId);
        if IsDefined(npcManager) {
            npcManager.ApplyRemoteUpdate(syncData);
        }
    }

    public func OnRemoteQuestNPCUpdate(questData: QuestNPCSyncData) -> Void {
        let questNPC = this.FindQuestNPC(questData.npcId);
        if IsDefined(questNPC) {
            questNPC.ApplyRemoteUpdate(questData);
        }
    }

    private func SpawnNPCFromRemoteData(spawnData: NPCSpawnData) -> Void {
        // Use game's NPC system to spawn with identical parameters
        let npcSystem = GameInstance.GetNPCSystem(GetGameInstance());

        let spawnTransform: WorldTransform;
        WorldTransform.SetPosition(spawnTransform, spawnData.position);
        WorldTransform.SetOrientation(spawnTransform, spawnData.rotation);

        // Spawn NPC with same record and appearance
        let spawnedNPC = npcSystem.SpawnNPC(spawnData.npcRecord, spawnTransform);

        if IsDefined(spawnedNPC) {
            // Set appearance to match
            spawnedNPC.ScheduleAppearanceChange(spawnData.appearance);

            // Register without broadcasting (already remote)
            this.RegisterNPCLocal(spawnedNPC, spawnData.npcType);

            LogChannel(n"NPCWorld", "[NPCWorld] Successfully spawned remote NPC: " + spawnData.npcId);
        }
    }

    private func RegisterNPCLocal(npc: ref<NPCPuppet>, npcType: ENPCType) -> Void {
        // Register NPC without broadcasting spawn (for remote NPCs)
        let npcManager = new NPCStateManager();
        npcManager.Initialize(npc, npcType);
        ArrayPush(this.m_trackedNPCs, npcManager);
        this.RouteNPCToSpecializedSystem(npc, npcType);
    }

    private func DespawnNPCFromRemoteData(npcId: Uint64) -> Void {
        let npcManager = this.FindNPCManager(npcId);
        if IsDefined(npcManager) {
            let npc = npcManager.GetNPC();
            if IsDefined(npc) {
                let npcSystem = GameInstance.GetNPCSystem(GetGameInstance());
                npcSystem.DespawnNPC(npc);
            }
            // UnregisterNPC will be called automatically by NPC system hooks
        }
    }

    // === Utility Functions ===

    private func IsNPCTracked(npc: ref<NPCPuppet>) -> Bool {
        let npcId = Cast<Uint64>(npc.GetEntityID());
        return this.FindNPCManager(npcId) != null;
    }

    private func FindNPCManager(npcId: Uint64) -> ref<NPCStateManager> {
        for manager in this.m_trackedNPCs {
            if manager.GetNPCId() == npcId {
                return manager;
            }
        }
        return null;
    }

    private func FindNPCManagerIndex(npcId: Uint64) -> Int32 {
        for i in Range(ArraySize(this.m_trackedNPCs)) {
            if this.m_trackedNPCs[i].GetNPCId() == npcId {
                return i;
            }
        }
        return -1;
    }

    private func FindQuestNPC(npcId: Uint64) -> ref<QuestNPCManager> {
        for questNPC in this.m_questNPCs {
            if questNPC.GetNPCId() == npcId {
                return questNPC;
            }
        }
        return null;
    }

    private func FindQuestNPCIndex(npcId: Uint64) -> Int32 {
        for i in Range(ArraySize(this.m_questNPCs)) {
            if this.m_questNPCs[i].GetNPCId() == npcId {
                return i;
            }
        }
        return -1;
    }

    private func DetermineIfHost() -> Bool {
        // Determine if this player is the session host
        // This would integrate with CyberpunkMP's host detection
        return false; // Placeholder
    }

    private func RegisterGameSystemHooks() -> Void {
        // Register hooks will be implemented via @wrapMethod decorators
        // See bottom of file
        LogChannel(n"NPCWorld", "[NPCWorld] Game system hooks registered");
    }

    // === Network Interface ===
    // These functions interface with CyberpunkMP's networking system

    private func SendNPCUpdate(syncData: NPCSyncData) -> Void {
        // Interface with CyberpunkMP networking
        // This would call into the C++ networking layer
    }

    private func SendQuestNPCUpdate(questData: QuestNPCSyncData) -> Void {
        // Interface with CyberpunkMP networking
    }

    private func SendNPCSpawn(spawnData: NPCSpawnData) -> Void {
        // Interface with CyberpunkMP networking
    }

    private func SendNPCDespawn(despawnData: NPCDespawnData) -> Void {
        // Interface with CyberpunkMP networking
    }

    // === Public API ===

    public func GetTrackedNPCCount() -> Int32 {
        return ArraySize(this.m_trackedNPCs);
    }

    public func GetQuestNPCCount() -> Int32 {
        return ArraySize(this.m_questNPCs);
    }

    public func GetNPCsByType(npcType: ENPCType) -> array<ref<NPCStateManager>> {
        let result: array<ref<NPCStateManager>>;

        for manager in this.m_trackedNPCs {
            if Equals(manager.GetNPCType(), npcType) {
                ArrayPush(result, manager);
            }
        }

        return result;
    }

    public func ForceNPCSync(npcId: Uint64) -> Bool {
        let manager = this.FindNPCManager(npcId);
        if IsDefined(manager) {
            this.SyncNPC(manager);
            return true;
        }
        return false;
    }

    public func GetSystemStatus() -> NPCSystemStatus {
        let status: NPCSystemStatus;
        status.totalNPCs = ArraySize(this.m_trackedNPCs);
        status.questNPCs = ArraySize(this.m_questNPCs);
        status.policeNPCs = this.m_policeManager.GetPoliceCount();
        status.crowdNPCs = this.m_crowdManager.GetCrowdCount();
        status.vendorNPCs = this.m_vendorManager.GetVendorCount();
        status.trafficNPCs = this.m_trafficManager.GetDriverCount();
        status.isInitialized = this.m_isInitialized;
        status.isHost = this.m_isHost;

        return status;
    }
}

// === Data Structures ===

public struct NPCSyncData {
    public let npcId: Uint64;
    public let position: Vector3;
    public let rotation: Quaternion;
    public let animationState: CName;
    public let behaviorState: gamedataNPCBehaviorState;
    public let health: Float;
    public let combatState: ENPCCombatState;
    public let dialogueState: ENPCDialogueState;
    public let isAlive: Bool;
    public let timestamp: Float;
}

public struct NPCSpawnData {
    public let npcId: Uint64;
    public let npcRecord: TweakDBID;
    public let position: Vector3;
    public let rotation: Quaternion;
    public let npcType: ENPCType;
    public let appearance: CName;
    public let timestamp: Float;
}

public struct NPCDespawnData {
    public let npcId: Uint64;
    public let timestamp: Float;
}

public struct QuestNPCSyncData {
    public let npcId: Uint64;
    public let questIds: array<String>;
    public let questPhase: String;
    public let dialogueState: ENPCDialogueState;
    public let interactionAvailable: Bool;
    public let timestamp: Float;
}

public struct NPCSystemStatus {
    public let totalNPCs: Int32;
    public let questNPCs: Int32;
    public let policeNPCs: Int32;
    public let crowdNPCs: Int32;
    public let vendorNPCs: Int32;
    public let trafficNPCs: Int32;
    public let isInitialized: Bool;
    public let isHost: Bool;
}

// === Enumerations ===

public enum ENPCType : Uint8 {
    Civilian = 0,
    Police = 1,
    Enemy = 2,
    Vendor = 3,
    QuestNPC = 4,
    SecurityGuard = 5,
    Gangster = 6,
    Corporate = 7,
    Driver = 8,
    Passenger = 9
}

public enum ENPCCombatState : Uint8 {
    Passive = 0,
    Alert = 1,
    InCombat = 2,
    Searching = 3,
    Fleeing = 4,
    Dead = 5
}

public enum ENPCDialogueState : Uint8 {
    None = 0,
    Available = 1,
    InProgress = 2,
    Completed = 3,
    Unavailable = 4
}

// === Game System Hooks ===
// Automatic integration with Cyberpunk 2077's NPC systems

@wrapMethod(NPCSystem)
protected func SpawnNPC(npcRecord: TweakDBID, transform: WorldTransform) -> ref<NPCPuppet> {
    let npc = wrappedMethod(npcRecord, transform);

    if IsDefined(npc) {
        // Automatically register with multiplayer system
        let npcWorldSystem = NPCWorldSystem.GetInstance();
        if IsDefined(npcWorldSystem) {
            npcWorldSystem.RegisterNPC(npc);
        }
    }

    return npc;
}

@wrapMethod(NPCSystem)
protected func DespawnNPC(npc: ref<NPCPuppet>) -> Void {
    let npcId = Cast<Uint64>(npc.GetEntityID());

    // Notify multiplayer system before despawn
    let npcWorldSystem = NPCWorldSystem.GetInstance();
    if IsDefined(npcWorldSystem) {
        npcWorldSystem.UnregisterNPC(npcId);
    }

    wrappedMethod(npc);
}

@wrapMethod(CrowdSystem)
protected func SpawnCrowdNPC(spawnData: ref<CrowdSpawnData>) -> ref<NPCPuppet> {
    let npc = wrappedMethod(spawnData);

    if IsDefined(npc) {
        // Automatically register crowd NPCs
        let npcWorldSystem = NPCWorldSystem.GetInstance();
        if IsDefined(npcWorldSystem) {
            npcWorldSystem.RegisterNPC(npc);
        }
    }

    return npc;
}

@wrapMethod(CrowdSystem)
protected func DespawnCrowdNPC(npc: ref<NPCPuppet>) -> Void {
    let npcId = Cast<Uint64>(npc.GetEntityID());

    // Notify system before despawn
    let npcWorldSystem = NPCWorldSystem.GetInstance();
    if IsDefined(npcWorldSystem) {
        npcWorldSystem.UnregisterNPC(npcId);
    }

    wrappedMethod(npc);
}

// Hook into quest system for automatic quest NPC detection
@wrapMethod(QuestSystem)
protected func RegisterQuestNPC(npc: ref<NPCPuppet>, questId: String) -> Void {
    wrappedMethod(npc, questId);

    // Register as quest NPC in multiplayer system
    let npcWorldSystem = NPCWorldSystem.GetInstance();
    if IsDefined(npcWorldSystem) {
        npcWorldSystem.RegisterQuestNPC(npc);
    }
}

// Hook into police system for wanted level synchronization
@wrapMethod(WantedSystem)
protected func SetWantedLevel(level: Int32) -> Void {
    wrappedMethod(level);

    // Sync wanted level change across multiplayer
    let npcWorldSystem = NPCWorldSystem.GetInstance();
    if IsDefined(npcWorldSystem) {
        // This would trigger police response synchronization
    }
}

// Network event callbacks for CyberpunkMP integration
@addMethod(PlayerPuppet)
public func OnNPCSpawnReceived(spawnData: NPCSpawnData) -> Void {
    NPCWorldSystem.GetInstance().OnRemoteNPCSpawn(spawnData);
}

@addMethod(PlayerPuppet)
public func OnNPCDespawnReceived(despawnData: NPCDespawnData) -> Void {
    NPCWorldSystem.GetInstance().OnRemoteNPCDespawn(despawnData);
}

@addMethod(PlayerPuppet)
public func OnNPCUpdateReceived(syncData: NPCSyncData) -> Void {
    NPCWorldSystem.GetInstance().OnRemoteNPCUpdate(syncData);
}

@addMethod(PlayerPuppet)
public func OnQuestNPCUpdateReceived(questData: QuestNPCSyncData) -> Void {
    NPCWorldSystem.GetInstance().OnRemoteQuestNPCUpdate(questData);
}

// === Missing Class Definitions ===

// Police Response Manager - handles police and wanted system synchronization
public class PoliceResponseManager extends IScriptable {
    private let m_isHost: Bool = false;

    public func Initialize(isHost: Bool) -> Void {
        this.m_isHost = isHost;
        LogChannel(n"Police", "[Police] Police Response Manager initialized");
    }

    public func Update(deltaTime: Float) -> Void {
        // Police system update logic would go here
    }
}

// Vendor Network Manager - handles merchant and shop synchronization
public class VendorNetworkManager extends IScriptable {
    private let m_isHost: Bool = false;

    public func Initialize(isHost: Bool) -> Void {
        this.m_isHost = isHost;
        LogChannel(n"Vendor", "[Vendor] Vendor Network Manager initialized");
    }

    public func Update(deltaTime: Float) -> Void {
        // Vendor system update logic would go here
    }
}

// Quest NPC Manager - handles quest-specific NPC behavior
public class QuestNPCManager extends IScriptable {
    private let m_npc: wref<NPCPuppet>;
    private let m_questId: String = "";

    public func Initialize(npc: ref<NPCPuppet>, questId: String) -> Void {
        this.m_npc = npc;
        this.m_questId = questId;
        LogChannel(n"Quest", "[Quest] Quest NPC Manager initialized");
    }

    public func Update(deltaTime: Float) -> Void {
        // Quest NPC update logic would go here
    }

    public func GetNPC() -> wref<NPCPuppet> {
        return this.m_npc;
    }

    public func GetQuestId() -> String {
        return this.m_questId;
    }
}