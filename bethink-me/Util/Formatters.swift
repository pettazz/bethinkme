import SwiftUI


struct Formatters {
    static let dateFormatter: DateFormatter = {
        let it = DateFormatter()
        it.timeStyle = .short
        it.dateStyle = .medium
        it.doesRelativeDateFormatting = true

        return it
    }()

    static let allDayFormatter: DateFormatter = {
        let it = DateFormatter()
        it.timeStyle = .none
        it.dateStyle = .medium
        it.doesRelativeDateFormatting = true

        return it
    }()

    static let intervalFormatter: DateComponentsFormatter = {
        let it = DateComponentsFormatter()
        it.allowedUnits = [.year, .month, .day, .hour, .minute]
        it.allowsFractionalUnits = false
        it.zeroFormattingBehavior = .dropAll
        it.unitsStyle = .short

        return it
    }()
}
