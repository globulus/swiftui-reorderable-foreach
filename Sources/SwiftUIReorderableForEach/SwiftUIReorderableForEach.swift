import SwiftUI
import UniformTypeIdentifiers

public struct ReorderableForEach<Data, Content>: View
where Data : Hashable, Content : View {
    @Binding var data: [Data]
    @Binding var allowReordering: Bool
    
    let context: NSManagedObjectContext? // optional, passing context enables CoreData support, requires an attribute 'sortIndex' in  CD model
    
    private let content: (Data, Bool) -> Content
    
    @State private var draggedItem: Data?
    @State private var hasChangedLocation: Bool = false
    
    public init (_ data: Binding<[Data]>, allowReordering: Binding<Bool>, context: NSManagedObjectContext? = nil, @ViewBuilder content: @escaping (Data, Bool) -> Content) {
        _data = data
        _allowReordering = allowReordering
        
        self.context = context
        self.content = content
    }
    
    public var body: some View {
        ForEach(data, id: \.self) { item in
            if allowReordering {
                content(item, hasChangedLocation && draggedItem == item)
                    .onDrag {
                        draggedItem = item
                        return NSItemProvider(object: "\(item.hashValue)" as NSString)
                    }
                    .onDrop(of: [UTType.plainText], delegate: DragRelocateDelegate(
                        item: item,
                        context: context,
                        data: $data,
                        draggedItem: $draggedItem,
                        hasChangedLocation: $hasChangedLocation))
            } else {
                content(item, false)
            }
        }
    }
    
    struct DragRelocateDelegate<Data>: DropDelegate
    where Data : Equatable {
        let item: Data
        let context: NSManagedObjectContext?

        @Binding var data: [Data]
        @Binding var draggedItem: Data?
        @Binding var hasChangedLocation: Bool
        
        func dropEntered(info: DropInfo) {
            guard item != draggedItem,
                  let current = draggedItem,
                  let from = data.firstIndex(of: current),
                  let to = data.firstIndex(of: item)
            else {
                return
            }
            
            hasChangedLocation = true
            
            if data[to] != current {
                // handle UI indices
                withAnimation {
                    data.move(fromOffsets: IndexSet(integer: from),
                              toOffset: (to > from) ? to + 1 : to)
                }
                
                // support for CoreData
                if let context = context, let draggedItem = draggedItem as? NSManagedObject, let item = item as? NSManagedObject {
                    
                    // TODO: fast movements can cause CD indices to get mixed up, use UI indices instead
                    
                    // handle CD indices
                    let draggedItemIndex = draggedItem.value(forKey: "sortIndex")
                    let itemIndex = item.value(forKey: "sortIndex")

                    draggedItem.setValue(itemIndex, forKey: "sortIndex")
                    item.setValue(draggedItemIndex, forKey: "sortIndex")
   
                    // save context
                    if context.hasChanges {
                        do { try context.save() }
                        catch { }
                    }
                }
            }
        }
        
        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: .move)
        }
        
        func performDrop(info: DropInfo) -> Bool {
            hasChangedLocation = false
            draggedItem = nil
            return true
        }
    }
}

// MARK: tests

struct ReorderingVStackTest: View {
    @State private var data = ["Apple", "Orange", "Banana", "Lemon", "Tangerine"]
    @State private var allowReordering = false
    
    var body: some View {
        VStack {
            Toggle("Allow reordering", isOn: $allowReordering)
                .frame(width: 200)
                .padding(.bottom, 30)
            VStack {
                ReorderableForEach($data, allowReordering: $allowReordering) { item, isDragged in
                    Text(item)
                        .font(.title)
                        .padding()
                        .frame(minWidth: 200, minHeight: 50)
                        .border(Color.blue)
                        .background(Color.red.opacity(0.9))
                        .overlay(isDragged ? Color.white.opacity(0.6) : Color.clear)
                }
            }
        }
    }
}

struct ReorderingVGridTest: View {
    @State private var data = ["Apple", "Orange", "Banana", "Lemon", "Tangerine"]
    @State private var allowReordering = false
    
    var body: some View {
        VStack {
            Toggle("Allow reordering", isOn: $allowReordering)
                .frame(width: 200)
                .padding(.bottom, 30)
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ]) {
                ReorderableForEach($data, allowReordering: $allowReordering) { item, isDragged in
                    Text(item)
                        .font(.title)
                        .padding()
                        .frame(minWidth: 150, minHeight: 50)
                        .border(Color.blue)
                        .background(Color.red.opacity(0.9))
                        .overlay(isDragged ? Color.white.opacity(0.6) : Color.clear)
                }
            }
        }
        .padding()
    }
}

struct ReorderingVStackTest_Previews: PreviewProvider {
    static var previews: some View {
        ReorderingVStackTest()
    }
}

struct ReorderingGridTest_Previews: PreviewProvider {
    static var previews: some View {
        ReorderingVGridTest()
    }
}
