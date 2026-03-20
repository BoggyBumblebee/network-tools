import Foundation

struct DisplayRow: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let value: String
}
