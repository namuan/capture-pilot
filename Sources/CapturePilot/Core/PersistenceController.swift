import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // Create the model programmatically or load from file.
        // Since we don't have a .xcdatamodeld file compiler in swift build easily without creating one,
        // we can construct the model code-first or try to load a model if we could compile it.
        // For simplicity in a Package-based setup without Xcode's automatic resource handling, 
        // constructing the model programmatically is often easier or we can just use a simple name and expect the file.
        // However, `NSPersistentContainer` expects a model.
        
        let model = NSManagedObjectModel()
        
        // Define Session Entity
        let sessionEntity = NSEntityDescription()
        sessionEntity.name = "CaptureSession"
        sessionEntity.managedObjectClassName = "CaptureSession"
        
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .UUIDAttributeType
        idAttr.isOptional = false
        
        let dateAttr = NSAttributeDescription()
        dateAttr.name = "date"
        dateAttr.attributeType = .dateAttributeType
        dateAttr.isOptional = true
        
        let pathAttr = NSAttributeDescription()
        pathAttr.name = "path"
        pathAttr.attributeType = .stringAttributeType
        pathAttr.isOptional = false
        
        sessionEntity.properties = [idAttr, dateAttr, pathAttr]
        
        model.entities = [sessionEntity]
        
        container = NSPersistentContainer(name: "CapturePilot", managedObjectModel: model)
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

// We need to subclass NSManagedObject for the entity to work properly with code-gen or manual definition
@objc(CaptureSession)
public class CaptureSession: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var date: Date?
    @NSManaged public var path: String
    
    // Ensures the date property always returns a valid Date
    public var safeDate: Date {
        return date ?? Date()
    }
}

// Extension to provide a safe initializer
extension CaptureSession {
    convenience init(context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "CaptureSession", in: context)!
        self.init(entity: entity, insertInto: context)
        self.id = UUID()
        self.date = Date() // Ensure date is always initialized
    }
}
