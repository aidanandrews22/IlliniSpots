import Foundation

struct RoomAvailability: Identifiable {
    let id: Int64 // Room ID
    let roomNumber: String
    let isAvailable: Bool
    let currentStatus: Status
    let nextChange: Date?
    let event: Event?
    
    enum Status {
        case available(until: Date?)
        case occupied(until: Date)
        case closed
        
        var description: String {
            switch self {
            case .available(let until):
                if let until = until {
                    return "Available until \(until.formatted(date: .omitted, time: .shortened))"
                } else {
                    return "Available for the rest of the day"
                }
            case .occupied(let until):
                return "Occupied until \(until.formatted(date: .omitted, time: .shortened))"
            case .closed:
                return "Closed"
            }
        }
    }
} 