module CyberpunkMP.World

import Codeware.UI.*
import Codeware.Localization.*
import CyberpunkMP.*

public native class ChatSystem extends IScriptable {
    public native func Send(message: String);
    public native func GetUsername() -> String;

    public func HandleChatMessage(author: String, message: String) -> Void {
        let evt: ref<ChatMessageUIEvent>;
        evt.author = author;
        evt.message = message;

        LogChannel(n"DEBUG", s"[ChatSystem] HandleChatMessage: " + message);
        let uiSystem = GameInstance.GetUISystem(GetGameInstance());        
        uiSystem.QueueEvent(evt);
    }
    // private final func OnConnectToServer(request: ref<ConnectToServerRequest>) -> Void {
        // this.m_Blackboard.SetBool(GetAllBlackboardDefs().UI_ComDevice.ContactsActive, open, true);
    // }
}

// Chat message event for UI system
public class ChatMessageUIEvent extends Event {
    public let author: String;
    public let message: String;
}
