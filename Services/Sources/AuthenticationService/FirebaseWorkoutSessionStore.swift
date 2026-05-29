#if canImport(Core)
import Core
#endif
import FirebaseAuth
import FirebaseFirestore
import Foundation

/// Stores workout sessions in Firestore under the signed-in user's document.
/// Falls back silently to local-only when the user is not signed in.
public actor FirebaseWorkoutSessionStore: WorkoutSessionStoring {
    private let db = Firestore.firestore()

    public init() {}

    public func save(_ session: WorkoutSessionSummary) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = db.collection("users").document(uid).collection("sessions").document(session.id.uuidString)
        try await ref.setData(session.firestoreData)
    }

    public func fetchRecent(limit: Int) async throws -> [WorkoutSessionSummary] {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
        let snapshot = try await db
            .collection("users").document(uid).collection("sessions")
            .order(by: "date", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { WorkoutSessionSummary(firestoreData: $0.data()) }
    }
}

private extension WorkoutSessionSummary {
    var firestoreData: [String: Any] {
        [
            "id": id.uuidString,
            "date": Timestamp(date: date),
            "title": title,
            "estimatedCalories": estimatedCalories,
            "durationMinutes": durationMinutes
        ]
    }

    init?(firestoreData data: [String: Any]) {
        guard
            let idString = data["id"] as? String,
            let id = UUID(uuidString: idString),
            let timestamp = data["date"] as? Timestamp,
            let title = data["title"] as? String,
            let calories = data["estimatedCalories"] as? Double,
            let duration = data["durationMinutes"] as? Int
        else { return nil }

        self.init(
            id: id,
            date: timestamp.dateValue(),
            title: title,
            estimatedCalories: calories,
            durationMinutes: duration
        )
    }
}
