public enum LoadState: Sendable, Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}
