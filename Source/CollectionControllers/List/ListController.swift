//
//  ListController.swift
//  Created by Vadim Pavlov on 3/7/17.

import Foundation

public protocol ListControllerDataSource: class {
    func loadPage(_ page: ListPage) -> Future<[ListObject]>
}

open class ListController: StateController<ListViewState> {
    
    public let pageSize: Int
    public let firstPage: Int
    public var currentPage: Int
    public var lastID: String?

    public private(set) var objects: [ListObject]
    public weak var dataSource: ListControllerDataSource?
    
    private typealias ListUpdateAction = (BatchUpdate?) -> Void
    private var listUpdate: ListUpdateAction?
    
    open override func setView<View : ListViewType>(_ view: View) where View.State == ListViewState {
        super.setView(view)
        self.listUpdate = { [weak view, weak self] update in
            assert(Thread.isMainThread)
            let list = self?.objects as? [View.ListViewObject] ?? []
            view?.update(list: list, batch: update)
        }
    }

    public init(pageSize: Int, firstPage: Int, currentPage: Int? = nil, objects: [ListObject] = []) {
        self.pageSize = pageSize
        self.firstPage = firstPage
        self.currentPage = currentPage ?? firstPage
        self.objects = objects

        let state = ListViewState()
        super.init(state: state)
    }

    // MARK: - Loading
    public func clear() {
        self.lastID = nil
        self.state.canLoadMore = true
        self.currentPage = firstPage
        self.update(objects: [])

    }
    
    public func loadFirstPage() {
        self.clear()

        let page = ListPage(size: pageSize, number: firstPage,  lastID: nil)
        self.loadPage(page) { [weak self] objects in
            self?.appendNewPage(page, with: objects)
            
            let isEmpty = objects.isEmpty
            if self?.state.isEmpty != isEmpty {
                self?.state.isEmpty = isEmpty
            }
        }
    }
    
    public func loadNextPage() {
        guard state.canLoadMore else { return }
        let nextPage = ListPage(size: pageSize, number: currentPage + 1,  lastID: self.lastID)
        self.loadPage(nextPage) { [weak self] objects in
            self?.appendNewPage(nextPage, with: objects)
        }
    }
    
    // MARK: - Refreshing
    public enum RefreshGapStrategy {
        case dropLoaded
        case keepLoading
    }
    
    public func refresh(onGap: RefreshGapStrategy) {
        let page = ListPage(size: pageSize, number: firstPage,  lastID: nil)
        if let firstID = self.objects.first?.listID {
            self.refreshPage(page, firstID: firstID, onGap: onGap)
        } else {
            self.loadFirstPage()
        }
    }
    
    private func loadPage(_ page: ListPage, completion: @escaping ([ListObject]) -> Void) {
        
        guard !state.isLoading else { return }
        self.state.isLoading = true
        
        self.dataSource?.loadPage(page).start { [weak self] result in
            self?.state.isLoading = false
            switch result {
            case .success(let objects):
                completion(objects)
            case .error(let error):
                self?.showError(error)
                // ? depends from error?
                // self?.state.canLoadMore = false
            }
        }
    }
    
    private func refreshPage(_ page: ListPage, firstID: String, onGap: RefreshGapStrategy) {
        self.loadPage(page) { [weak self] objects in
            
            let newObjects = objects.prefix { object in
                object.listID != firstID
            }
            
            guard !newObjects.isEmpty else { return }
            
            if newObjects.count == page.size {
                // potential gap between new & loaded objects
                switch onGap {
                case .dropLoaded:
                    self?.clear()
                    self?.appendNewPage(page, with: Array(newObjects))
                case .keepLoading:
                    let nextPage = ListPage(size: page.size, number: page.number + 1,  lastID: nil)
                    self?.refreshPage(nextPage, firstID: firstID, onGap: onGap)
                }
            } else {
                self?.insertObjects(Array(newObjects))
            }
        }
    }
    
    open func appendNewPage(_ page: ListPage, with objects: [ListObject]) {
        self.currentPage = page.number
        self.lastID = objects.last?.listID

        if objects.count < page.size {
            self.state.canLoadMore = false
        }

        self.appendObjects(objects)

    }
    
}

// MARK: - Updating
public extension ListController {
    func updateList() {
        self.listUpdate?(nil)
    }

    func update(objects: [ListObject]) {
        self.objects = objects
        updateList()
    }
    
    func updateObject(_ object: ListObject) {
        let index = self.objects.index { $0.listID == object.listID }
        if let item = index {
            
            let ip = IndexPath(item: item, section: 0)
            let update = BatchUpdate(reloadRows: [ip])
            
            self.objects[item] = object
            self.listUpdate?(update)
        }
    }
    // MARK: Insert
    func appendObjects(_ newObjects: [ListObject]) {
        
        let lower = self.objects.count
        let upper = lower + newObjects.count
        let range = lower..<upper
        
        let inserted = range.map { IndexPath(row: $0, section: 0) }
        let update = BatchUpdate(insertRows: inserted)
        
        self.objects.append(contentsOf: newObjects)
        self.listUpdate?(update)
    }
    
    func insertObject(_ object: ListObject, at index: Int = 0) {
        let indexPath = IndexPath(row: index, section: 0)
        let update = BatchUpdate(insertRows: [indexPath])

        self.objects.insert(object, at: index)
        self.listUpdate?(update)
    }
    
    func insertObjects(_ newObjects: [ListObject], at index: Int = 0) {
        self.objects.insert(contentsOf: newObjects, at: index)
        
        let lower = index
        let upper = lower + newObjects.count
        let range = lower..<upper
        
        let inserted = range.map { IndexPath(row: $0, section: 0) }
        let update = BatchUpdate(insertRows: inserted)

        self.listUpdate?(update)
    }

    // MARK: - Remove
    func removeObject(at index: Int) {
        let indexPath = IndexPath(row: index, section: 0)
        let update = BatchUpdate(deleteRows: [indexPath])
        self.objects.remove(at: index)
        self.listUpdate?(update)
    }
    
    func removeObject(_ object: ListObject) {
        let index = self.objects.index { $0.listID == object.listID }
        if let index = index {
            self.removeObject(at: index)
        }
    }
    
    func removeObjects(_ objects: [ListObject]) {
        var indexPaths: [IndexPath] = []
        
        // reverse arrays, so we can remove current idx in loop
        let reversedObjects = objects.reversed()
        for (idx, object) in self.objects.enumerated().reversed() {
            let contains = reversedObjects.contains { $0.listID == object.listID }
            if contains {
                self.objects.remove(at: idx)
                let ip = IndexPath(row: idx, section: 0)
                indexPaths.insert(ip, at: 0)
            }
        }
        
        let update = BatchUpdate(deleteRows: indexPaths)
        self.listUpdate?(update)
    }

    // MARK: - MOVE
    func moveObject(_ object: ListObject, to index: Int) {
        guard let row = objects.index(where: { $0.listID == object.listID }) else { return }
        move(from: row, to: index)
    }

    func move(from: Int, to index: Int) {
        let at = IndexPath(row: from, section: 0)
        let to = IndexPath(row: index, section: 0)

        let move = Move<IndexPath>(at: at, to: to)
        let update = BatchUpdate(moveRows: [move])

        let object = self.objects.remove(at: from)
        self.objects.insert(object, at: index)
        self.listUpdate?(update)
    }
}
