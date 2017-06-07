//
//  FRCCollectionController.swift
//  Created by Vadim Pavlov on 2/21/17.

import UIKit
import CoreData

public class FRCCollectionController<Object: NSFetchRequestResult>: CollectionController<Object>, NSFetchedResultsControllerDelegate {
    
    public init(collectionView: UICollectionView, frc: NSFetchedResultsController<Object>, cellDescriptor: @escaping (Object) -> CellDescriptor) {
        let dataSource = DataSource(frc: frc)
        super.init(collectionView: collectionView, dataSource: dataSource, cellDescriptor: cellDescriptor)
        frc.delegate = self
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    }
    
    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    }
    
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        
        let update =  BatchUpdate(sectionIndex: sectionIndex, for: type)
        self.performBatch(update)
    }
    
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        BatchUpdate.perform(at: indexPath, for: type, newIndexPath: newIndexPath) {
            self.performBatch($0)
        }
        
    }
}

public class SimpleFRCCollectionController<Object: NSFetchRequestResult, Cell: UICollectionViewCell>: FRCCollectionController<Object>  {
    public init(collectionView: UICollectionView, frc: NSFetchedResultsController<Object>, identifier: String? = nil, register: CellDescriptor.Register? = nil, configure: @escaping (Cell, Object) -> Void) {
        super.init(collectionView: collectionView, frc: frc) { object in
            let descriptor = CellDescriptor(identifier: identifier, register: register, configure: { cell in
                configure(cell, object)
            })
            return descriptor
        }
    }
}