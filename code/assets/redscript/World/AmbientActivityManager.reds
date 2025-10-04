// Ambient Activity Manager - Manages all ambient world activities and interactions
// Street vendors, musicians, conversations, random events, police patrols, etc.

module CyberpunkMP.World

import Codeware.UI.*
import Codeware.Localization.*

// Ambient Activity Manager - creates the living world atmosphere
public class AmbientActivityManager extends IScriptable {
    private let m_isHost: Bool = false;
    private let m_isInitialized: Bool = false;

    // Activity tracking
    private let m_activeActivities: array<ref<AmbientActivity>> = [];
    private let m_streetVendors: array<ref<StreetVendor>> = [];
    private let m_streetMusicians: array<ref<StreetMusician>> = [];
    private let m_conversations: array<ref<AmbientConversation>> = [];
    private let m_policePatrols: array<ref<PolicePatrol>> = [];
    private let m_randomEvents: array<ref<RandomEvent>> = [];

    // Activity zones
    private let m_activityZones: array<ref<ActivityZone>> = [];

    // Spawn timers and intervals
    private let m_activityUpdateTimer: Float = 0.0;
    private let m_vendorSpawnTimer: Float = 0.0;
    private let m_musicianSpawnTimer: Float = 0.0;
    private let m_conversationTimer: Float = 0.0;
    private let m_patrolTimer: Float = 0.0;
    private let m_randomEventTimer: Float = 0.0;

    private let ACTIVITY_UPDATE_INTERVAL: Float = 2.0; // 2 seconds
    private let VENDOR_SPAWN_INTERVAL: Float = 30.0; // 30 seconds
    private let MUSICIAN_SPAWN_INTERVAL: Float = 45.0; // 45 seconds
    private let CONVERSATION_INTERVAL: Float = 15.0; // 15 seconds
    private let PATROL_INTERVAL: Float = 60.0; // 1 minute
    private let RANDOM_EVENT_INTERVAL: Float = 120.0; // 2 minutes

    // Activity density settings
    private let m_activityDensity: Float = 1.0;
    private let m_maxActivitiesPerZone: Int32 = 10;
    private let m_activitySpawnRadius: Float = 100.0;

    public func Initialize(isHost: Bool) -> Void {
        this.m_isHost = isHost;

        LogChannel(n"Ambient","[Ambient] Initializing Ambient Activity Manager...");

        // Initialize activity zones
        this.InitializeActivityZones();

        // Start activity systems
        this.StartActivitySystems();

        // Configure ambient settings
        this.ConfigureAmbientSettings();

        this.m_isInitialized = true;
        LogChannel(n"Ambient","[Ambient] Ambient Activity Manager initialized");
    }

    private func InitializeActivityZones() -> Void {
        // Create activity zones for different types of ambient life
        this.CreateStreetVendorZones();
        this.CreateMusicianZones();
        this.CreateConversationZones();
        this.CreatePatrolZones();
        this.CreateEventZones();

        LogChannel(n"Ambient",s"[Ambient] Created " + ArraySize(this.m_activityZones) + " activity zones");
    }

    private func CreateStreetVendorZones() -> Void {
        // Food vendors in busy areas
        let marketVendorZone = new ActivityZone();
        marketVendorZone.Initialize(new Vector4(-200.0, 100.0, 0.0, 1.0), 150.0, EActivityType.StreetVendor);
        marketVendorZone.SetMaxActivities(5);
        marketVendorZone.SetActivityDensity(1.2);
        ArrayPush(this.m_activityZones, marketVendorZone);

        // Tech vendors in Watson
        let techVendorZone = new ActivityZone();
        techVendorZone.Initialize(new Vector4(-500.0, 200.0, 0.0, 1.0), 200.0, EActivityType.StreetVendor);
        techVendorZone.SetMaxActivities(3);
        techVendorZone.SetActivityDensity(0.8);
        ArrayPush(this.m_activityZones, techVendorZone);

        // Food trucks near residential
        let foodTruckZone = new ActivityZone();
        foodTruckZone.Initialize(new Vector4(-700.0, -400.0, 0.0, 1.0), 250.0, EActivityType.StreetVendor);
        foodTruckZone.SetMaxActivities(2);
        foodTruckZone.SetActivityDensity(0.6);
        ArrayPush(this.m_activityZones, foodTruckZone);
    }

    private func CreateMusicianZones() -> Void {
        // Street musicians in entertainment district
        let entertainmentMusicZone = new ActivityZone();
        entertainmentMusicZone.Initialize(new Vector4(300.0, -400.0, 0.0, 1.0), 300.0, EActivityType.StreetMusician);
        entertainmentMusicZone.SetMaxActivities(4);
        entertainmentMusicZone.SetActivityDensity(1.5);
        ArrayPush(this.m_activityZones, entertainmentMusicZone);

        // Subway musicians
        let subwayMusicZone = new ActivityZone();
        subwayMusicZone.Initialize(new Vector4(0.0, -100.0, -10.0, 1.0), 100.0, EActivityType.StreetMusician);
        subwayMusicZone.SetMaxActivities(2);
        subwayMusicZone.SetActivityDensity(1.0);
        ArrayPush(this.m_activityZones, subwayMusicZone);

        // Plaza musicians
        let plazaMusicZone = new ActivityZone();
        plazaMusicZone.Initialize(new Vector4(100.0, 200.0, 0.0, 1.0), 80.0, EActivityType.StreetMusician);
        plazaMusicZone.SetMaxActivities(1);
        plazaMusicZone.SetActivityDensity(0.7);
        ArrayPush(this.m_activityZones, plazaMusicZone);
    }

    private func CreateConversationZones() -> Void {
        // Business district conversations
        let businessTalkZone = new ActivityZone();
        businessTalkZone.Initialize(new Vector4(0.0, 0.0, 0.0, 1.0), 400.0, EActivityType.Conversation);
        businessTalkZone.SetMaxActivities(8);
        businessTalkZone.SetActivityDensity(1.3);
        ArrayPush(this.m_activityZones, businessTalkZone);

        // Residential area chats
        let neighborhoodTalkZone = new ActivityZone();
        neighborhoodTalkZone.Initialize(new Vector4(-700.0, -500.0, 0.0, 1.0), 500.0, EActivityType.Conversation);
        neighborhoodTalkZone.SetMaxActivities(6);
        neighborhoodTalkZone.SetActivityDensity(0.9);
        ArrayPush(this.m_activityZones, neighborhoodTalkZone);
    }

    private func CreatePatrolZones() -> Void {
        // City center police patrols
        let centerPatrolZone = new ActivityZone();
        centerPatrolZone.Initialize(new Vector4(0.0, 0.0, 0.0, 1.0), 600.0, EActivityType.PolicePatrol);
        centerPatrolZone.SetMaxActivities(3);
        centerPatrolZone.SetActivityDensity(1.0);
        ArrayPush(this.m_activityZones, centerPatrolZone);

        // Entertainment district security
        let entertainmentPatrolZone = new ActivityZone();
        entertainmentPatrolZone.Initialize(new Vector4(300.0, -400.0, 0.0, 1.0), 400.0, EActivityType.PolicePatrol);
        entertainmentPatrolZone.SetMaxActivities(2);
        entertainmentPatrolZone.SetActivityDensity(1.2);
        ArrayPush(this.m_activityZones, entertainmentPatrolZone);
    }

    private func CreateEventZones() -> Void {
        // Random events can happen anywhere, but some areas are more likely
        let cityEventZone = new ActivityZone();
        cityEventZone.Initialize(new Vector4(0.0, 0.0, 0.0, 1.0), 1000.0, EActivityType.RandomEvent);
        cityEventZone.SetMaxActivities(2);
        cityEventZone.SetActivityDensity(0.5);
        ArrayPush(this.m_activityZones, cityEventZone);
    }

    private func StartActivitySystems() -> Void {
        // Start all ambient activity systems
        this.StartVendorSystem();
        this.StartMusicianSystem();
        this.StartConversationSystem();
        this.StartPatrolSystem();
        this.StartRandomEventSystem();

        LogChannel(n"Ambient","[Ambient] All activity systems started");
    }

    private func ConfigureAmbientSettings() -> Void {
        // Configure settings to match singleplayer ambient density
        this.SetActivityDensity(1.0);

        LogChannel(n"Ambient","[Ambient] Ambient settings configured");
    }

    public func Update(deltaTime: Float) -> Void {
        if !this.m_isInitialized {
            return;
        }

        // Update all timers
        this.m_activityUpdateTimer += deltaTime;
        this.m_vendorSpawnTimer += deltaTime;
        this.m_musicianSpawnTimer += deltaTime;
        this.m_conversationTimer += deltaTime;
        this.m_patrolTimer += deltaTime;
        this.m_randomEventTimer += deltaTime;

        // Update existing activities
        if this.m_activityUpdateTimer >= this.ACTIVITY_UPDATE_INTERVAL {
            this.UpdateAllActivities(deltaTime);
            this.m_activityUpdateTimer = 0.0;
        }

        // Spawn new activities based on intervals
        this.CheckVendorSpawning();
        this.CheckMusicianSpawning();
        this.CheckConversationSpawning();
        this.CheckPatrolSpawning();
        this.CheckRandomEventSpawning();

        // Clean up finished activities
        this.CleanupFinishedActivities();
    }

    // === Activity Spawning Systems ===

    private func CheckVendorSpawning() -> Void {
        if this.m_vendorSpawnTimer >= this.VENDOR_SPAWN_INTERVAL {
            this.SpawnStreetVendors();
            this.m_vendorSpawnTimer = 0.0;
        }
    }

    private func CheckMusicianSpawning() -> Void {
        if this.m_musicianSpawnTimer >= this.MUSICIAN_SPAWN_INTERVAL {
            this.SpawnStreetMusicians();
            this.m_musicianSpawnTimer = 0.0;
        }
    }

    private func CheckConversationSpawning() -> Void {
        if this.m_conversationTimer >= this.CONVERSATION_INTERVAL {
            this.SpawnConversations();
            this.m_conversationTimer = 0.0;
        }
    }

    private func CheckPatrolSpawning() -> Void {
        if this.m_patrolTimer >= this.PATROL_INTERVAL {
            this.SpawnPolicePatrols();
            this.m_patrolTimer = 0.0;
        }
    }

    private func CheckRandomEventSpawning() -> Void {
        if this.m_randomEventTimer >= this.RANDOM_EVENT_INTERVAL {
            this.SpawnRandomEvents();
            this.m_randomEventTimer = 0.0;
        }
    }

    private func SpawnStreetVendors() -> Void {
        let playerPositions = this.GetAllPlayerPositions();

        for playerPos in playerPositions {
            let vendorZones = this.GetZonesNearPosition(playerPos, EActivityType.StreetVendor);

            for zone in vendorZones {
                if zone.CanSpawnMoreActivities() {
                    this.CreateStreetVendor(zone);
                }
            }
        }
    }

    private func CreateStreetVendor(zone: ref<ActivityZone>) -> Void {
        // Find suitable position within zone
        let vendorPosition = this.FindVendorSpawnPosition(zone);
        if Vector4.IsZero(vendorPosition) {
            return;
        }

        // Create vendor NPC
        let vendorNPC = this.SpawnVendorNPC(vendorPosition);
        if !IsDefined(vendorNPC) {
            return;
        }

        // Create vendor activity
        let vendor = new StreetVendor();
        vendor.InitializeVendor(zone.GetZoneCenter(), this.SelectVendorType(zone));
        ArrayPush(this.m_streetVendors, vendor);

        // Register as general activity - use concrete StreetVendor instead of abstract AmbientActivity
        ArrayPush(this.m_activeActivities, vendor);

        zone.AddActivity();

        LogChannel(n"Ambient",s"[Ambient] Created street vendor at: " + ToString(vendorPosition.X) + ", " + ToString(vendorPosition.Y));
    }

    private func SpawnStreetMusicians() -> Void {
        let playerPositions = this.GetAllPlayerPositions();

        for playerPos in playerPositions {
            let musicZones = this.GetZonesNearPosition(playerPos, EActivityType.StreetMusician);

            for zone in musicZones {
                if zone.CanSpawnMoreActivities() && RandRangeF(0.0, 1.0) < 0.3 {
                    this.CreateStreetMusician(zone);
                }
            }
        }
    }

    private func CreateStreetMusician(zone: ref<ActivityZone>) -> Void {
        let musicianPosition = this.FindMusicianSpawnPosition(zone);
        if Vector4.IsZero(musicianPosition) {
            return;
        }

        let musicianNPC = this.SpawnMusicianNPC(musicianPosition);
        if !IsDefined(musicianNPC) {
            return;
        }

        let musician = new StreetMusician();
        musician.Initialize(musicianNPC, this.SelectInstrumentType(), this.SelectMusicGenre());
        ArrayPush(this.m_streetMusicians, musician);

        let activitySM = new StreetMusician();`r`nactivitySM.Initialize(musicianPosition);`r`nArrayPush(this.m_activeActivities, activitySM);

        zone.AddActivity();

        LogChannel(n"Ambient",s"[Ambient] Created street musician at: " + ToString(musicianPosition.X) + ", " + ToString(musicianPosition.Y));
    }

    private func SpawnConversations() -> Void {
        let playerPositions = this.GetAllPlayerPositions();

        for playerPos in playerPositions {
            let conversationZones = this.GetZonesNearPosition(playerPos, EActivityType.Conversation);

            for zone in conversationZones {
                if zone.CanSpawnMoreActivities() && RandRangeF(0.0, 1.0) < 0.4 {
                    this.CreateConversation(zone);
                }
            }
        }
    }

    private func CreateConversation(zone: ref<ActivityZone>) -> Void {
        let conversationPosition = this.FindConversationSpawnPosition(zone);
        if Vector4.IsZero(conversationPosition) {
            return;
        }

        // Spawn 2-3 NPCs for conversation
        let participantCount = RandRange(2, 4);
        let participants: array<ref<NPCPuppet>>;

        for i in Range(0, Cast<Int32>(participantCount)) {
            let participantPos = this.GenerateNearbyPosition(conversationPosition, 2.0);
            let participant = this.SpawnConversationNPC(participantPos);
            if IsDefined(participant) {
                ArrayPush(participants, participant);
            }
        }

        if ArraySize(participants) >= 2 {
            let conversation = new AmbientConversation();
            conversation.InitializeConversation(conversationPosition, this.SelectConversationTopic(zone));
            conversation.SetParticipants(participants);
            ArrayPush(this.m_conversations, conversation);

            // Use the concrete conversation instead of abstract AmbientActivity
            ArrayPush(this.m_activeActivities, conversation);

            zone.AddActivity();

            LogChannel(n"Ambient",s"[Ambient] Created conversation with " + ArraySize(participants) + " participants");
        }
    }

    private func SpawnPolicePatrols() -> Void {
        let playerPositions = this.GetAllPlayerPositions();

        for playerPos in playerPositions {
            let patrolZones = this.GetZonesNearPosition(playerPos, EActivityType.PolicePatrol);

            for zone in patrolZones {
                if zone.CanSpawnMoreActivities() && RandRangeF(0.0, 1.0) < 0.2 {
                    this.CreatePolicePatrol(zone);
                }
            }
        }
    }

    private func CreatePolicePatrol(zone: ref<ActivityZone>) -> Void {
        let patrolStartPosition = this.FindPatrolStartPosition(zone);
        if Vector4.IsZero(patrolStartPosition) {
            return;
        }

        // Spawn 1-2 police officers
        let officerCount = RandRange(1, 3);
        let officers: array<ref<NPCPuppet>>;

        for i in Range(0, Cast<Int32>(officerCount)) {
            let officerPos = this.GenerateNearbyPosition(patrolStartPosition, 3.0);
            let officer = this.SpawnPoliceNPC(officerPos);
            if IsDefined(officer) {
                ArrayPush(officers, officer);
            }
        }

        if ArraySize(officers) > 0 {
            let patrol = new PolicePatrol();
            patrol.InitializePatrol(patrolStartPosition, this.GeneratePatrolRoute(zone));
            patrol.SetOfficers(officers);
            ArrayPush(this.m_policePatrols, patrol);

            // Use the concrete patrol instead of abstract AmbientActivity
            ArrayPush(this.m_activeActivities, patrol);

            zone.AddActivity();

            LogChannel(n"Ambient",s"[Ambient] Created police patrol with " + ArraySize(officers) + " officers");
        }
    }

    private func SpawnRandomEvents() -> Void {
        let playerPositions = this.GetAllPlayerPositions();

        for playerPos in playerPositions {
            if RandRangeF(0.0, 1.0) < 0.1 { // 10% chance per check
                this.CreateRandomEvent(playerPos);
            }
        }
    }

    private func CreateRandomEvent(nearPosition: Vector4) -> Void {
        let eventTypes: array<ERandomEventType>;
        ArrayPush(eventTypes, ERandomEventType.StreetArgument);
        ArrayPush(eventTypes, ERandomEventType.AccidentScene);
        ArrayPush(eventTypes, ERandomEventType.StreetPerformance);
        ArrayPush(eventTypes, ERandomEventType.VendorCrowd);
        ArrayPush(eventTypes, ERandomEventType.PoliceActivity);

        let selectedEventType = eventTypes[RandRange(0, ArraySize(eventTypes))];
        let eventPosition = this.FindEventSpawnPosition(nearPosition);

        if !Vector4.IsZero(eventPosition) {
            let randomEvent = new RandomEvent();
            randomEvent.Initialize(selectedEventType, eventPosition, this.GetEventDuration(selectedEventType));
            ArrayPush(this.m_randomEvents, randomEvent);

            ArrayPush(this.m_activeActivities, randomEvent);

            LogChannel(n"Ambient",s"[Ambient] Created random event: " + ToString(EnumInt(selectedEventType)));
        }
    }

    // === Activity Management ===

    private func UpdateAllActivities(deltaTime: Float) -> Void {
        // Update street vendors
        for vendor in this.m_streetVendors {
            vendor.Update(deltaTime);
        }

        // Update musicians
        for musician in this.m_streetMusicians {
            musician.Update(deltaTime);
        }

        // Update conversations
        for conversation in this.m_conversations {
            conversation.Update(deltaTime);
        }

        // Update patrols
        for patrol in this.m_policePatrols {
            patrol.Update(deltaTime);
        }

        // Update random events
        for event in this.m_randomEvents {
            event.Update(deltaTime);
        }

        // Update zones
        for zone in this.m_activityZones {
            zone.Update(deltaTime);
        }
    }

    private func CleanupFinishedActivities() -> Void {
        // Remove expired activities
        let activitiesToRemove: array<Int32>;

        for i in Range(0, Cast<Int32>(ArraySize(this.m_activeActivities))) {
            if this.m_activeActivities[i].IsExpired() {
                ArrayPush(activitiesToRemove, i);
            }
        }

        // Remove in reverse order to maintain indices
        for i in Range(0, Cast<Int32>(ArraySize(activitiesToRemove))) {
            let index = activitiesToRemove[ArraySize(activitiesToRemove) - 1 - i];
            let activity = this.m_activeActivities[index];
            this.CleanupActivity(activity);
            ArrayRemove(this.m_activeActivities, activity);
        }

        // Cleanup specific activity types
        this.CleanupExpiredVendors();
        this.CleanupExpiredMusicians();
        this.CleanupExpiredConversations();
        this.CleanupExpiredPatrols();
        this.CleanupExpiredEvents();
    }

    private func CleanupActivity(activity: ref<AmbientActivity>) -> Void {
        // Find and reduce zone activity count
        let zone = this.GetZoneForPosition(activity.GetPosition());
        if IsDefined(zone) {
            zone.RemoveActivity();
        }

        LogChannel(n"Ambient", s"[Ambient] Cleaned up expired activity: " + ToString(EnumInt(activity.GetActivityType())));
    }

    private func CleanupExpiredVendors() -> Void {
        let vendorsToRemove: array<ref<StreetVendor>>;

        for vendor in this.m_streetVendors {
            if vendor.IsExpired() {
                vendor.Cleanup();
                ArrayPush(vendorsToRemove, vendor);
            }
        }

        for vendor in vendorsToRemove {
            ArrayRemove(this.m_streetVendors, vendor);
        }
    }

    private func CleanupExpiredMusicians() -> Void {
        let musiciansToRemove: array<ref<StreetMusician>>;

        for musician in this.m_streetMusicians {
            if musician.IsExpired() {
                musician.Cleanup();
                ArrayPush(musiciansToRemove, musician);
            }
        }

        for musician in musiciansToRemove {
            ArrayRemove(this.m_streetMusicians, musician);
        }
    }

    private func CleanupExpiredConversations() -> Void {
        let conversationsToRemove: array<ref<AmbientConversation>>;

        for conversation in this.m_conversations {
            if conversation.IsFinished() {
                conversation.Cleanup();
                ArrayPush(conversationsToRemove, conversation);
            }
        }

        for conversation in conversationsToRemove {
            ArrayRemove(this.m_conversations, conversation);
        }
    }

    private func CleanupExpiredPatrols() -> Void {
        let patrolsToRemove: array<ref<PolicePatrol>>;

        for patrol in this.m_policePatrols {
            if patrol.IsExpired() {
                patrol.Cleanup();
                ArrayPush(patrolsToRemove, patrol);
            }
        }

        for patrol in patrolsToRemove {
            ArrayRemove(this.m_policePatrols, patrol);
        }
    }

    private func CleanupExpiredEvents() -> Void {
        let eventsToRemove: array<ref<RandomEvent>>;

        for event in this.m_randomEvents {
            if event.IsExpired() {
                event.Cleanup();
                ArrayPush(eventsToRemove, event);
            }
        }

        for event in eventsToRemove {
            ArrayRemove(this.m_randomEvents, event);
        }
    }

    // === Helper Functions ===

    private func GetAllPlayerPositions() -> array<Vector4> {
        let positions: array<Vector4>;
        // Get all connected players - placeholder for CyberpunkMP integration
        ArrayPush(positions, GetPlayer(GetGameInstance()).GetWorldPosition());
        return positions;
    }

    private func GetZonesNearPosition(position: Vector4, activityType: EActivityType) -> array<ref<ActivityZone>> {
        let nearbyZones: array<ref<ActivityZone>>;

        for zone in this.m_activityZones {
            if Equals(zone.GetActivityType(), activityType) {
                let distance = Vector4.Distance(position, zone.GetZoneCenter());
                if distance <= zone.GetZoneRadius() + this.m_activitySpawnRadius {
                    ArrayPush(nearbyZones, zone);
                }
            }
        }

        return nearbyZones;
    }

    private func GetZoneForPosition(position: Vector4) -> ref<ActivityZone> {
        for zone in this.m_activityZones {
            if zone.ContainsPosition(position) {
                return zone;
            }
        }
        return null;
    }

    private func FindVendorSpawnPosition(zone: ref<ActivityZone>) -> Vector4 {
        // Find valid position for street vendor (near walls, corners, etc.)
        return this.FindSpawnPositionNearWalls(zone.GetZoneCenter(), zone.GetZoneRadius());
    }

    private func FindMusicianSpawnPosition(zone: ref<ActivityZone>) -> Vector4 {
        // Find open areas for musicians (plazas, wide sidewalks)
        return this.FindSpawnPositionInOpenArea(zone.GetZoneCenter(), zone.GetZoneRadius());
    }

    private func FindConversationSpawnPosition(zone: ref<ActivityZone>) -> Vector4 {
        // Find areas suitable for conversations (not blocking traffic)
        return this.FindSpawnPositionOnSidewalk(zone.GetZoneCenter(), zone.GetZoneRadius());
    }

    private func FindPatrolStartPosition(zone: ref<ActivityZone>) -> Vector4 {
        // Find starting position for police patrol (near roads)
        return this.FindSpawnPositionNearRoad(zone.GetZoneCenter(), zone.GetZoneRadius());
    }

    private func FindEventSpawnPosition(nearPosition: Vector4) -> Vector4 {
        // Find position for random events
        return this.FindSpawnPositionInOpenArea(nearPosition, 50.0);
    }

    private func FindSpawnPositionNearWalls(center: Vector4, radius: Float) -> Vector4 {
        // Implementation would find positions near building walls
        return this.GenerateRandomPositionInRadius(center, radius);
    }

    private func FindSpawnPositionInOpenArea(center: Vector4, radius: Float) -> Vector4 {
        // Implementation would find open areas like plazas
        return this.GenerateRandomPositionInRadius(center, radius);
    }

    private func FindSpawnPositionOnSidewalk(center: Vector4, radius: Float) -> Vector4 {
        // Implementation would find sidewalk positions
        return this.GenerateRandomPositionInRadius(center, radius);
    }

    private func FindSpawnPositionNearRoad(center: Vector4, radius: Float) -> Vector4 {
        // Implementation would find positions near roads
        return this.GenerateRandomPositionInRadius(center, radius);
    }

    private func GenerateRandomPositionInRadius(center: Vector4, radius: Float) -> Vector4 {
        let angle = RandRangeF(0.0, 360.0) * 3.14159 / 180.0;
        let distance = RandRangeF(radius * 0.3, radius);
        let x = center.X + CosF(angle) * distance;
        let y = center.Y + SinF(angle) * distance;
        return new Vector4(x, y, center.Z, 1.0);
    }

    private func GenerateNearbyPosition(center: Vector4, maxDistance: Float) -> Vector4 {
        return this.GenerateRandomPositionInRadius(center, maxDistance);
    }

    // === NPC Spawning ===

    private func SpawnVendorNPC(position: Vector4) -> ref<NPCPuppet> {
        return this.SpawnNPCAtPosition(t"Character.StreetVendor", position);
    }

    private func SpawnMusicianNPC(position: Vector4) -> ref<NPCPuppet> {
        return this.SpawnNPCAtPosition(t"Character.StreetMusician", position);
    }

    private func SpawnConversationNPC(position: Vector4) -> ref<NPCPuppet> {
        return this.SpawnNPCAtPosition(t"Character.Civilian_Generic", position);
    }

    private func SpawnPoliceNPC(position: Vector4) -> ref<NPCPuppet> {
        return this.SpawnNPCAtPosition(t"Character.Police_Officer", position);
    }

    private func SpawnNPCAtPosition(npcRecord: TweakDBID, position: Vector4) -> ref<NPCPuppet> {
        let entitySystem = GameInstance.GetDynamicEntitySystem();
        if !IsDefined(entitySystem) {
            LogChannel(n"Ambient", "[Ambient] DynamicEntitySystem not available");
            return null;
        }

        // Create entity spec for NPC spawning
        let npcSpec = new DynamicEntitySpec();
        npcSpec.recordID = npcRecord;
        npcSpec.appearanceName = n""; // Use default appearance
        npcSpec.position = position;
        npcSpec.orientation = EulerAngles.ToQuat(new EulerAngles(0.0, 0.0, RandRangeF(0.0, 360.0)));
        npcSpec.persistState = false; // Don't persist ambient NPCs
        npcSpec.persistSpawn = false; // Don't persist across saves
        npcSpec.alwaysSpawned = false; // Only spawn when player is around
        npcSpec.spawnInView = false; // Can spawn in view for ambient activities
        npcSpec.active = true; // Spawn immediately
        npcSpec.tags = [n"CyberpunkMP", n"Ambient"];

        let entityID = entitySystem.CreateEntity(npcSpec);
        if !EntityID.IsDefined(entityID) {
            LogChannel(n"Ambient", "[Ambient] Failed to create NPC entity");
            return null;
        }

        // Get the spawned entity as NPCPuppet
        let entity = entitySystem.GetEntity(entityID);
        let npcPuppet = entity as NPCPuppet;

        if IsDefined(npcPuppet) {
            LogChannel(n"Ambient", s"[Ambient] Successfully spawned NPC: " + TDBID.ToStringDEBUG(npcRecord));
        } else {
            LogChannel(n"Ambient", "[Ambient] Entity created but not an NPCPuppet");
        }

        return npcPuppet;
    }

    // === Activity Type Selectors ===

    private func SelectVendorType(zone: ref<ActivityZone>) -> EVendorType {
        // Select vendor type based on zone location
        let zoneCenter = zone.GetZoneCenter();

        if zoneCenter.Y > 0.0 {
            return EVendorType.TechVendor;
        } else {
            return EVendorType.FoodVendor;
        }
    }

    private func SelectInstrumentType() -> EInstrumentType {
        let instruments: array<EInstrumentType>;
        ArrayPush(instruments, EInstrumentType.Guitar);
        ArrayPush(instruments, EInstrumentType.Violin);
        ArrayPush(instruments, EInstrumentType.Saxophone);
        ArrayPush(instruments, EInstrumentType.Drums);

        return instruments[RandRange(0, ArraySize(instruments))];
    }

    private func SelectMusicGenre() -> EMusicGenre {
        let genres: array<EMusicGenre>;
        ArrayPush(genres, EMusicGenre.Jazz);
        ArrayPush(genres, EMusicGenre.Rock);
        ArrayPush(genres, EMusicGenre.Electronic);
        ArrayPush(genres, EMusicGenre.Classical);

        return genres[RandRange(0, ArraySize(genres))];
    }

    private func SelectConversationTopic(zone: ref<ActivityZone>) -> EConversationTopic {
        // Select topic based on zone type and time of day
        return EConversationTopic.General;
    }

    private func GeneratePatrolRoute(zone: ref<ActivityZone>) -> array<Vector4> {
        let route: array<Vector4>;
        let center = zone.GetZoneCenter();
        let radius = zone.GetZoneRadius();

        // Generate 3-5 waypoints for patrol route
        let waypointCount = RandRange(3, 6);
        for i in Range(0, Cast<Int32>(waypointCount)) {
            let waypoint = this.GenerateRandomPositionInRadius(center, radius);
            ArrayPush(route, waypoint);
        }

        return route;
    }

    private func GetEventDuration(eventType: ERandomEventType) -> Float {
        switch eventType {
            case ERandomEventType.StreetArgument:
                return 120.0; // 2 minutes
            case ERandomEventType.AccidentScene:
                return 300.0; // 5 minutes
            case ERandomEventType.StreetPerformance:
                return 600.0; // 10 minutes
            case ERandomEventType.VendorCrowd:
                return 180.0; // 3 minutes
            case ERandomEventType.PoliceActivity:
                return 240.0; // 4 minutes
            default:
                return 180.0; // 3 minutes
        }
    }

    // === System Configuration ===

    private func StartVendorSystem() -> Void {
        LogChannel(n"Ambient", "[Ambient] Street vendor system started");
    }

    private func StartMusicianSystem() -> Void {
        LogChannel(n"Ambient", "[Ambient] Street musician system started");
    }

    private func StartConversationSystem() -> Void {
        LogChannel(n"Ambient", "[Ambient] Conversation system started");
    }

    private func StartPatrolSystem() -> Void {
        LogChannel(n"Ambient", "[Ambient] Police patrol system started");
    }

    private func StartRandomEventSystem() -> Void {
        LogChannel(n"Ambient", "[Ambient] Random event system started");
    }

    // === Public API ===

    public func GetActiveActivityCount() -> Int32 {
        return ArraySize(this.m_activeActivities);
    }

    public func GetVendorCount() -> Int32 {
        return ArraySize(this.m_streetVendors);
    }

    public func GetMusicianCount() -> Int32 {
        return ArraySize(this.m_streetMusicians);
    }

    public func GetConversationCount() -> Int32 {
        return ArraySize(this.m_conversations);
    }

    public func GetPatrolCount() -> Int32 {
        return ArraySize(this.m_policePatrols);
    }

    public func GetRandomEventCount() -> Int32 {
        return ArraySize(this.m_randomEvents);
    }

    public func SetActivityDensity(density: Float) -> Void {
        this.m_activityDensity = ClampF(density, 0.1, 2.0);
        LogChannel(n"Ambient", s"[Ambient] Activity density set to: " + this.m_activityDensity);
    }

    public func ForceCleanupAllActivities() -> Void {
        // Force cleanup of all activities
        this.CleanupFinishedActivities();
    }
}

// === Supporting Enums ===

public enum EActivityType {
    StreetVendor = 0,
    StreetMusician = 1,
    Conversation = 2,
    PolicePatrol = 3,
    RandomEvent = 4
}

public enum EVendorType {
    FoodVendor = 0,
    TechVendor = 1,
    ClothingVendor = 2,
    WeaponVendor = 3
}

public enum EInstrumentType {
    Guitar = 0,
    Violin = 1,
    Saxophone = 2,
    Drums = 3,
    Keyboard = 4
}

public enum EMusicGenre {
    Jazz = 0,
    Rock = 1,
    Electronic = 2,
    Classical = 3,
    Folk = 4
}

public enum EConversationTopic {
    General = 0,
    Business = 1,
    Politics = 2,
    Technology = 3,
    Entertainment = 4
}

public enum ERandomEventType {
    StreetArgument = 0,
    AccidentScene = 1,
    StreetPerformance = 2,
    VendorCrowd = 3,
    PoliceActivity = 4
}

// === Missing Class Definitions ===

// Activity Zone - defines areas for ambient activities
public class ActivityZone extends IScriptable {
    private let m_center: Vector4;
    private let m_radius: Float;
    private let m_activityType: EActivityType;
    private let m_activityDensity: Float = 1.0;
    private let m_maxActivities: Int32 = 5;

    public func Initialize(center: Vector4, radius: Float, activityType: EActivityType) -> Void {
        this.m_center = center;
        this.m_radius = radius;
        this.m_activityType = activityType;
    }

    public func ContainsPosition(position: Vector4) -> Bool {
        return Vector4.Distance(this.m_center, position) <= this.m_radius;
    }

    public func GetCenter() -> Vector4 {
        return this.m_center;
    }

    public func GetRadius() -> Float {
        return this.m_radius;
    }

    public func GetActivityType() -> EActivityType {
        return this.m_activityType;
    }

    public func SetActivityDensity(density: Float) -> Void {
        this.m_activityDensity = density;
    }

    public func GetActivityDensity() -> Float {
        return this.m_activityDensity;
    }

    public func SetMaxActivities(maxActivities: Int32) -> Void {
        this.m_maxActivities = maxActivities;
    }

    public func GetMaxActivities() -> Int32 {
        return this.m_maxActivities;
    }

    public func CanSpawnMoreActivities() -> Bool {
        // Simple logic - can always spawn more for now
        // In a full implementation, this would check current activity count vs max
        return true;
    }

    public func GetZoneCenter() -> Vector4 {
        return this.m_center;
    }

    public func GetZoneRadius() -> Float {
        return this.m_radius;
    }

    public func AddActivity() -> Void {
        // Track that an activity was added to this zone
        // In a full implementation, this would increment a counter
    }

    public func RemoveActivity() -> Void {
        // Track that an activity was removed from this zone
        // In a full implementation, this would decrement a counter
    }

    public func Update(deltaTime: Float) -> Void {
        // Zone update logic
    }
}

// Ambient Activity base class
public abstract class AmbientActivity extends IScriptable {
    protected let m_activityId: Uint64;
    protected let m_position: Vector4;
    protected let m_isActive: Bool = false;
    protected let m_startTime: Float;
    protected let m_activityType: EActivityType;

    public func Initialize(position: Vector4) -> Void {
        this.m_position = position;
        this.m_startTime = EngineTime.ToFloat(GameInstance.GetSimTime(GetGameInstance()));
    }

    public func Start() -> Void {
        this.m_isActive = true;
    }

    public func Stop() -> Void {
        this.m_isActive = false;
    }

    public func IsActive() -> Bool {
        return this.m_isActive;
    }

    public func GetPosition() -> Vector4 {
        return this.m_position;
    }

    public func Update(deltaTime: Float) -> Void {
        // Base update logic
    }

    public func GetActivityType() -> EActivityType {
        return this.m_activityType;
    }

    protected func SetActivityType(activityType: EActivityType) -> Void {
        this.m_activityType = activityType;
    }

    public func IsExpired() -> Bool {
        // Simple expiration logic - activities expire after 10 minutes
        let currentTime = EngineTime.ToFloat(GameInstance.GetSimTime(GetGameInstance()));
        return (currentTime - this.m_startTime) > 600.0;
    }
}

// Street Vendor activity
public class StreetVendor extends AmbientActivity {
    private let m_vendorType: EVendorType;
    private let m_npc: wref<NPCPuppet>;

    public func InitializeVendor(position: Vector4, vendorType: EVendorType) -> Void {
        this.Initialize(position);
        this.m_vendorType = vendorType;
        this.SetActivityType(EActivityType.StreetVendor);
    }
}

// Street Musician activity
public class StreetMusician extends AmbientActivity {
    private let m_instrumentType: EInstrumentType;
    private let m_musicGenre: EMusicGenre;
    private let m_npc: wref<NPCPuppet>;

    public func InitializeMusician(position: Vector4, instrument: EInstrumentType, genre: EMusicGenre) -> Void {
        this.Initialize(position);
        this.m_instrumentType = instrument;
        this.m_musicGenre = genre;
        this.SetActivityType(EActivityType.StreetMusician);
    }
}

// Ambient Conversation activity
public class AmbientConversation extends AmbientActivity {
    private let m_participants: array<wref<NPCPuppet>> = [];
    private let m_conversationTopic: EConversationTopic;

    public func InitializeConversation(position: Vector4, topic: EConversationTopic) -> Void {
        this.Initialize(position);
        this.m_conversationTopic = topic;
        this.SetActivityType(EActivityType.Conversation);
    }

    public func SetParticipants(participants: array<ref<NPCPuppet>>) -> Void {
        ArrayClear(this.m_participants);
        for participant in participants {
            ArrayPush(this.m_participants, participant);
        }
    }

    public func IsFinished() -> Bool {
        // Conversations finish after 3 minutes or when participants leave
        let currentTime = EngineTime.ToFloat(GameInstance.GetSimTime(GetGameInstance()));
        return (currentTime - this.m_startTime) > 180.0;
    }
}

// Police Patrol activity
public class PolicePatrol extends AmbientActivity {
    private let m_officers: array<wref<NPCPuppet>> = [];
    private let m_patrolRoute: array<Vector4> = [];

    public func InitializePatrol(startPosition: Vector4, route: array<Vector4>) -> Void {
        this.Initialize(startPosition);
        this.m_patrolRoute = route;
        this.SetActivityType(EActivityType.PolicePatrol);
    }

    public func SetOfficers(officers: array<ref<NPCPuppet>>) -> Void {
        ArrayClear(this.m_officers);
        for officer in officers {
            ArrayPush(this.m_officers, officer);
        }
    }
}

// Random Event activity
public class RandomEvent extends AmbientActivity {
    private let m_eventType: ERandomEventType;
    private let m_participants: array<wref<NPCPuppet>> = [];

    public func InitializeEvent(position: Vector4, eventType: ERandomEventType) -> Void {
        this.Initialize(position);
        this.m_eventType = eventType;
        this.SetActivityType(EActivityType.RandomEvent);
    }
}




