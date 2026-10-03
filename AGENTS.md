# AGENTS.md - Guidelines for AI Agents working with SwByeDPI

## Project Overview

**SwByeDPI** is a Swift wrapper for [byedpi](https://github.com/hufrea/byedpi) - a DPI (Deep Packet Inspection) evasion tool. The project provides Swift/CocoaPods packages that enable iOS/macOS applications to run local SOCKS proxies with DPI bypass capabilities.

**Primary Use Case**: Enable users in censored networks to access blocked content by running a local SOCKS proxy that modifies network traffic to circumvent DPI systems.

**Main Platforms**: iOS 10.0+, macOS 10.12+, tvOS 10.0+, watchOS 3.0+, visionOS 1.0+, Linux (experimental)

## Repository Structure

```
SwByeDPI/
├── Sources/                    # Source code
│   ├── ByeDPIC/               # Low-level C module (native byedpi)
│   ├── ByeDPIKit/             # Minimal wrapper for ByeDPIC
│   └── SwByeDPI/              # Extended Swift wrapper with high-level APIs
├── Example/                    # Example iOS application
│   └── ByeByeDPI/             # SwiftUI app (iOS 14+)
├── Assets/                     # Built-in domain lists and strategies
├── assets_codegen.sh           # Code generation for Assets/*.domains|*.strategies
├── patches/byedpi/             # MuseDPI patches re-applied by update_byedpi.sh
├── Tests/                      # Unit tests
├── Experimental/               # Experimental features
├── Package.swift               # Swift Package Manager manifest
├── *.podspec                   # CocoaPods specifications
└── update_byedpi.sh            # Script to update byedpi source code
```

## Key Modules

### 1. ByeDPIC (Sources/ByeDPIC)
- **Purpose**: Native C implementation of byedpi
- **Content**: C source files from upstream byedpi repository
- **Usage**: Low-level module, not recommended for direct use
- **Platform**: Cross-platform (iOS, macOS, Linux, etc.)

### 2. ByeDPIKit (Sources/ByeDPIKit)
- **Purpose**: Minimal Swift wrapper over ByeDPIC
- **Key API**: `ByeDPI.start(args:)` and `ByeDPI.stop()` / `ByeDPI.forceStop()`
- **Usage**: Direct command-line argument control of byedpi SOCKS proxy
- **Platform Checks**: None - accepts any byedpi arguments

### 3. SwByeDPI (Sources/SwByeDPI)
- **Purpose**: High-level Swift API with configuration abstractions
- **Key Features**:
  - Strategy testing and analysis
  - Domain list management
  - Composite strategy generation
  - URLSession SOCKS proxy configuration
  - Built-in domain lists and strategies (from `Assets/`)
- **Key Utilities**:
  - `SBDTestResultAnalyticsUtil.swift` - Strategy analysis logic
  - Strategy tester - Domain request testing with configurable parameters

## Development Guidelines

### Build Commands

```bash
# Build the package
swift build

# Run tests
swift test

# Generate Xcode project
swift package generate-xcodeproj

# Update byedpi sources
./update_byedpi.sh
```

### Code Generation

Built-in domains and strategies are generated from text files in `Assets/`:

```bash
# Regenerate Swift files from Assets
./assets_codegen.sh
```

**File Formats**:
- `*.domains` - One domain per line
- `*.strategies` - One strategy (command-line arguments) per line

### Testing

- Tests are located in `Tests/`
- Use `swift test` to run all tests
- Strategy testing involves network requests to real domains
- Test configuration parameters:
  - Delay between requests (recommended: 1 second)
  - Request count per domain (recommended: 2)
  - Worker threads (recommended: CPU cores × 2)
  - Response timeout (recommended: 5 seconds)

### Code Style

- **Language**: Swift 5.3+ (multiple versions supported via Package@swift-*.swift)
- **Naming**: Follow Swift API Design Guidelines
- **Architecture**: Layered (ByeDPIC → ByeDPIKit → SwByeDPI)
- **Documentation**: Russian and English README files available

## Important Considerations

### Platform Limitations

1. **iOS Network Extension**: 
   - Memory limit: 15 MB (iOS < 14), 50 MB (iOS 15+)
   - Cannot manage per-app tunneling (use byedpi --hosts for domain-level control)
   - Requires paid Apple Developer account for VPN client distribution

2. **Local Address Binding**:
   - iOS < 18.0: Don't use 127.0.0.1, use other local addresses (e.g., 192.168.20.3)
   - Can't bind to 0.0.0.0 for VPN tunnel - must specify actual device IP
   - DEBUG mode with Wi-Fi: Network Extension auto-detects local IP

3. **Memory Management**:
   - Avoid logging stdout/stderr in production (causes memory leaks)
   - Comment out logging level commands for byedpi/Tun2SOCKS

### Security

- **Never expose**: Proxy configuration details, user network traffic logs
- **SOCKS proxy**: Runs locally on device - no external servers involved
- **VPN Extension**: Only needed for background operation and system-wide traffic routing

### Strategy Development

- A "successful" request: HTTP 200-299 OR response with Content-Length header
- Strategy selection criterion: More successful domain requests = better strategy
- Composite strategies include:
  - DNS bypass (port 53) - for tunnel mode
  - Domain blacklist (byedpi bypass)
  - Domain whitelist (specific strategies for specific domains)
  - Universal strategy (best overall performance)
- Use `-An` mapping for consistency between blacklist/whitelist/strategy blocks

## Common Tasks

### Adding New Domains/Strategies

1. Edit or create files in `Assets/` with `.domains` or `.strategies` extension
2. Run `./CodeGen/generate.sh`
3. Generated Swift files will be included in the module automatically

### Modifying ByeDPI Behavior

- **Low-level**: Modify C sources in `Sources/ByeDPIC/` (upstream byedpi)
- **Swift API**: Modify wrappers in `Sources/ByeDPIKit/` or `Sources/SwByeDPI/`
- **Command-line arguments**: Follow [byedpi documentation](https://github.com/hufrea/byedpi)

### Debugging Network Issues

1. Check Console.app logs for UDP session errors
2. Verify binding address (not 127.0.0.1 on iOS < 18.0)
3. Ensure strategy parameters are supported by device/OS
4. Monitor memory usage (watch for SIGKILL from OS)

## Dependencies

- **Upstream**: [byedpi](https://github.com/hufrea/byedpi) - Core DPI evasion logic
- **Example App**: Tun2SocksKit - VPN tunnel management
- **Build Tools**: Swift Package Manager, CocoaPods

## Useful Links

- [byedpi documentation](https://github.com/hufrea/byedpi)
- [Example app README](./Example/ByeByeDPI)
- [Strategy analyzer documentation](./README.md#swbyedpi-testing-results-analyzing-and-optimal-strategy-define)
- [ByeByeDPI-Manual community guide](https://github.com/BDManual/ByeByeDPI-Manual)

## AI Agent Notes

When working with this codebase:

1. **Understand the layered architecture**: ByeDPIC (C) → ByeDPIKit (minimal Swift) → SwByeDPI (high-level Swift)
2. **Network code requires careful testing**: Strategy testing involves real network requests - be aware of rate limits
3. **Platform-specific behavior**: iOS has unique constraints (memory limits, binding addresses, Network Extension API)
4. **Code generation**: Assets are text-based and auto-generated - always run `assets_codegen.sh` after modifying `Assets/`
6. **Core patches**: `Sources/ByeDPIC/byedpi/` is a verbatim upstream clone plus `patches/byedpi/*.patch`; edit the core only through those patches (see `patches/byedpi/README.md`)
5. **Security-sensitive**: This tool circumvents censorship - handle with care, don't expose user data or network patterns
