import Foundation


struct DuplicateGroup {

    struct DuplicateRow: Identifiable {
        let id: String
        let title: String
        let count: Int
    }

    struct DuplicateList: Identifiable {
        let id: String
        let title: String
        let bethinkeries: [Bethinkery]

        var groupedRows: [DuplicateRow] {
            Dictionary(grouping: bethinkeries, by: \.title)
                .map { title, items in
                    DuplicateRow(
                        id: title,
                        title: title,
                        count: items.count
                    )
                }
        }
    }

    let lists: [DuplicateList]

    var isEmpty: Bool {
        lists.isEmpty
    }

    var allBethinkeries: [Bethinkery] {
        lists.flatMap(\.bethinkeries)
    }
}
