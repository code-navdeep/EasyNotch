//
//  MediaRemoteAdapterValidator.swift
//  EasyNotch
//

import Foundation
import Security

/// Verifies that the bundled MediaRemoteAdapter.framework hasn't been tampered
/// with before it's handed to an unentitled `/usr/bin/perl` subprocess, which
/// isn't covered by this app's own hardened runtime / library validation.
///
/// The framework is embedded with "Code Sign On Copy", so it always carries the
/// same Team ID as the app that embedded it. The expected Team ID is therefore
/// read from this app's own signature at runtime rather than hardcoded: build
/// with your own signing team and the check follows it, with no code change.
enum MediaRemoteAdapterValidator {

    /// Team ID of the running app, read from its own code signature.
    /// `nil` for an unsigned or ad-hoc-signed build, which has no team.
    private static let hostTeamIdentifier: String? = {
        var selfCode: SecCode?
        guard SecCodeCopySelf([], &selfCode) == errSecSuccess,
              let selfCode = selfCode
        else {
            return nil
        }

        var staticSelf: SecStaticCode?
        guard SecCodeCopyStaticCode(selfCode, [], &staticSelf) == errSecSuccess,
              let staticSelf = staticSelf
        else {
            return nil
        }

        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
                  staticSelf,
                  SecCSFlags(rawValue: kSecCSSigningInformation),
                  &information
              ) == errSecSuccess,
              let details = information as? [String: Any]
        else {
            return nil
        }

        return details[kSecCodeInfoTeamIdentifier as String] as? String
    }()

    static func isFrameworkTrusted(at path: String) -> Bool {
        // Without a Team ID there is nothing to pin the framework against, so
        // the check cannot be satisfied.
        guard let teamIdentifier = hostTeamIdentifier else {
            return false
        }

        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &staticCode) == errSecSuccess,
              let code = staticCode
        else {
            return false
        }

        let requirementString = "anchor apple generic and certificate leaf[subject.OU] = \"\(teamIdentifier)\"" as CFString
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(requirementString, [], &requirement) == errSecSuccess,
              let requirement = requirement
        else {
            return false
        }

        return SecStaticCodeCheckValidity(code, [], requirement) == errSecSuccess
    }
}
