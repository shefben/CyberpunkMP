module CyberpunkMP.Plugins

import CyberpunkMP.*
import CyberpunkMP.World.*

// LogChannel native function declaration
native func LogChannel(channel: CName, const text: script_ref<String>)

// Base RPC classes for multiplayer communication
public native class ServerRpc extends IScriptable {
}

public native class ClientRpc extends IScriptable {
}

public class JobEntry {
    public let id: Uint32;
    public let name: String;
    public let description: String;
    public let reward: Uint32;
}

public struct JobInfo {
    public let id: Uint32;
    public let name: String;
    public let description: String;
    public let reward: Uint32;
}

public native class JobsServer extends ServerRpc {
    public static native func SelectJob(job: CName) -> Void;
    public static native func QuitJob() -> Void;
}

public class JobsClient extends ClientRpc {

    public func SetActiveJob(job: CName) -> Void {
        LogChannel(n"DEBUG", s"[JobsClient] SetActiveJob");

        // Set the current active job of the player
        if (Equals(job, n"Delivery Driver")) {
            // Enable the delivery UI
            DeliveryServer.LoadDeliveries();
        } else if (Equals(job, n"Taxi Driver")) {
            TaxiServer.LoadJobs();
        }
        // Handle "None" here
    }
}
