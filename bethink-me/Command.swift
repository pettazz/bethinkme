// a set of intermediate not-objects to use for holding all the fields
// we want to do something with at once, rather than passing them around individually
// yeah we could just edit the model directly but I don't like the idea of either
// decoupling it from the backing object commit to EventKit or doing that in a view

struct EditBethinkeryList {
    var title: String
    var hexColor: String
    
    static func fromBethinkeryList(bethinkeryList: BethinkeryList) -> EditBethinkeryList {
        return EditBethinkeryList(
            title: bethinkeryList.title,
            hexColor: bethinkeryList.hexColor)
    }
}

struct EditBethinkery {
    var title: String
    var isCompleted: Bool
    
    static func fromBethinkery(bethinkery: Bethinkery) -> EditBethinkery {
        return EditBethinkery(
            title: bethinkery.title,
            isCompleted: bethinkery.isCompleted)
    }
}
