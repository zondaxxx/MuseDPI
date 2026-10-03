//
//  Constants.swift
//  SwByeDPI
//
//  Created by developer on 26.02.2026.
//

import Foundation

final class Constants {
    
    static let PSEUDO_BUNDLE_ID = Bundle.main.bundleIdentifier ?? "org.app.unknown"
    static let VPN_PROVIDER_BUNDLE_ID = PSEUDO_BUNDLE_ID + ".tun"
    static let PSEUDO_BUNDLE_VERSION = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    static let PSEUDO_BUNDLE_BUILD_NUMBER = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    static let sourceCodeLink = "https://github.com/zondaxxx/MuseDPI"
    static let acknowledgementsLink = sourceCodeLink + "/blob/main/ACKNOWLEDGEMENTS.md"
    static let strategyCatalogURL = URL(
        string: "https://raw.githubusercontent.com/zondaxxx/MuseDPI/main/strategy-catalog.json"
    )!
    static let strategyCatalogSignatureURL = URL(
        string: "https://raw.githubusercontent.com/zondaxxx/MuseDPI/main/strategy-catalog.json.sig"
    )!
    static let strategyCatalogPublicKeyBase64 = "18bFOLUFcXXG6/56v8NnWS/SO6SxTxFIhdD5Vmz43jg="
    
    static let buttonMinHeight = 40.0
    
    static var APP_GROUP_ID: String {
        get {
            if let configured = Bundle.main.object(forInfoDictionaryKey: "PalkaAppGroupIdentifier") as? String,
               !configured.isEmpty,
               !configured.contains("$(") {
                return configured
            }
            var splitted = PSEUDO_BUNDLE_ID.split(separator: ".")
            _ = splitted.removeLast()
            let group_id = "group." + splitted.joined(separator: ".")
            return group_id
        }
    }
    
    fileprivate init() {}
    
}
