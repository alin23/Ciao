//
//  CiaoBrowser.swift
//  Ciao
//
//  Created by Alexandre Tavares on 11/10/17.
//  Copyright © 2017 Tavares. All rights reserved.
//

import Foundation

public class CiaoBrowser {
    var netServiceBrowser: NetServiceBrowser
    var delegate: CiaoBrowserDelegate

    public var services = Set<NetService>()

    // Handlers
    public var serviceFoundHandler: ((NetService) -> Void)?
    public var serviceRemovedHandler: ((NetService) -> Void)?
    public var serviceResolvedHandler: ((Result<NetService, ErrorDictionary>) -> Void)?
    public var serviceUpdatedTXTHandler: ((NetService) -> Void)?


    public var isSearching = false {
        didSet {
            Logger.info(isSearching)
        }
    }

    public init() {
        netServiceBrowser = NetServiceBrowser()
        delegate = CiaoBrowserDelegate()
        netServiceBrowser.delegate = delegate
        delegate.browser = self
    }

    public func browse(type: ServiceType, domain: String = "") {
        browse(type: type.description, domain: domain)
    }

    public func browse(type: String, domain: String = "") {
        netServiceBrowser.searchForServices(ofType: type, inDomain: domain)
    }

    fileprivate func serviceFound(_ service: NetService) {
        service.startMonitoring()
        services.update(with: service)
        serviceFoundHandler?(service)

        // resolve services if handler is registered
        guard let serviceResolvedHandler = serviceResolvedHandler else { return }
        var resolver: CiaoResolver? = CiaoResolver(service: service)
        resolver?.resolve(withTimeout: 0) { result in
            serviceResolvedHandler(result)
            // retain resolver until resolution
            resolver = nil
        }
    }

    fileprivate func serviceRemoved(_ service: NetService) {
        services.remove(service)
        serviceRemovedHandler?(service)
    }

    fileprivate func serviceUpdatedTXT(_ service: NetService, _ txtRecord: Data) {
        service.setTXTRecord(txtRecord)
        serviceUpdatedTXTHandler?(service)
    }

    public func reset() {
        stop()
        services.removeAll()
        netServiceBrowser.delegate = nil
        netServiceBrowser = NetServiceBrowser()
        netServiceBrowser.delegate = delegate
    }

    public func stop() {
        for service in services {
            service.stopMonitoring()
        }

        netServiceBrowser.stop()
    }

    deinit {
        stop()

        services.removeAll()
        netServiceBrowser.delegate = nil
    }
}

public class CiaoBrowserDelegate: NSObject, NetServiceBrowserDelegate {
    weak var browser: CiaoBrowser?
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        Logger.info("Service found", service)
        self.browser?.serviceFound(service)
    }

    public func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        Logger.info("Browser will search")
        self.browser?.isSearching = true
    }

    public func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        Logger.info("Browser stopped search")
        self.browser?.isSearching = false
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        Logger.debug("Browser didn't search", errorDict)
        self.browser?.isSearching = false
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        Logger.info("Service removed", service)
        self.browser?.serviceRemoved(service)
    }

    public func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
        Logger.info("Service updated txt records", sender)
        self.browser?.serviceUpdatedTXT(sender, data)
    }
}
