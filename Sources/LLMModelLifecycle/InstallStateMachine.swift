import LLMCore

public actor InstallStateMachine {
    private var states: [ModelID: InstallState]

    public init(states: [ModelID: InstallState] = [:]) {
        self.states = states
    }

    public func state(for id: ModelID) -> InstallState {
        states[id] ?? .notInstalled
    }

    public func transition(modelID: ModelID, to state: InstallState) {
        states[modelID] = state
    }
}
