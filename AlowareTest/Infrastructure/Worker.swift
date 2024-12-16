//
//  Worker.swift
//  AlowareTest
//
//  Created by Matheus Weber on 15/12/24.
//

protocol Worker {
    func start()
}

final class AnyWorker: Worker {
    private let _start: () -> Void
    
    init<T: Worker>(_ worker: T) {
        self._start = worker.start
    }
    
    func start() {
        _start()
    }
}
