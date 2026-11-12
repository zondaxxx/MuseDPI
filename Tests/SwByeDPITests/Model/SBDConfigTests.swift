//
//  SBDConfigTests.swift
//  SwByeDPI
//
//  Created by developer on 02.03.2026.
//

import XCTest
@testable import SwByeDPI

final class SBDConfigTests: XCTestCase {
    func testGenerationSevenTLSProfilesRemainIntact() {
        let variants = [["-s1+s"], ["-s1", "-s0+sm"], ["-r0+sm", "-s1"], ["-r0+se", "-s1+s"]]
        for variant in variants {
            let arguments = ["-Kt", "-H:discord.com youtube.com"] + variant + ["-An", "-Kh", "-H:discord.com youtube.com", "-Mh,d,r", "-s1+h", "-An"]
            XCTAssertEqual(SBDConfig(commandArgs: arguments).validatedCmdArgs, arguments)
        }
    }
    
    func testArgsValidator() {
        let expectedArgs: [String] = ["-i", "127.0.0.1", "-p", "1080", "-b", "1024", "-c", "512", "-s", "1"]
        var config = SBDConfig(listenIP: "127.0.0.1", listenPort: 1080, bufSize: 1024, commandArgs: ["-s", "1"])
        XCTAssertEqual(config.args, expectedArgs, "Invalid byedpi cmd args validator")
        
        config = SBDConfig(listenIP: "127.0.0.1", listenPort: 1080, bufSize: 1024, commandArgs: ["-s", "1", "--ip", "0.0.0.0", "-i", "1.2.3.4", "-p", "100", "--port", "101"])
        XCTAssertEqual(config.args, expectedArgs, "Invalid byedpi cmd args validator")
    }
    
#if targetEnvironment(simulator) || targetEnvironment(macCatalyst) || os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
    func testAppleArgsValidator() {
        let expectedArgs: [String] = ["-i", "127.0.0.1", "-p", "1080", "-b", "1024", "-c", "512", "-s", "1", "-s", "2+1", "-o", "3"]
        var config = SBDConfig(listenIP: "127.0.0.1", listenPort: 1080, bufSize: 1024, commandArgs: ["-s", "1", "-Y", "-f-30", "-s", "2+1", "-T", "5", "-n", "google.com", "-o", "3", "-Y", "--drop-sack"])
        XCTAssertEqual(config.args, expectedArgs, "Invalid byedpi Apple cmd args validator")
        
        config = SBDConfig(listenIP: "127.0.0.1", listenPort: 1080, bufSize: 1024, commandArgs: ["-s", "1", "-Y", "-f-30", "-s", "2+1", "-T", "5", "--ip", "0.0.0.0", "-n", "google.com", "-o", "3", "-Y", "--port", "1", "--drop-sack"])
        XCTAssertEqual(config.args, expectedArgs, "Invalid byedpi Apple cmd args validator")
    }
#endif
}
