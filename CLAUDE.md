# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

go-libvirt is a pure Go interface for libvirt that communicates directly with libvirt's RPC interface without C bindings. The codebase is heavily code-generation based, with most API methods generated from libvirt protocol definitions.

## Development Commands

### Building and Testing
```bash
# Build the project
go build ./...

# Run unit tests
go test ./...

# Run integration tests (requires libvirt daemon)
go test -tags=integration ./...

# Run tests with race detection
go test -race ./...

# Run specific test
go test ./libvirt_test.go -run TestSpecificFunction

# Check module dependencies
go mod tidy
go mod verify
```

### Code Generation
Code generation requires manual setup and is not run automatically:

```bash
# Set required environment variable pointing to configured libvirt source
export LIBVIRT_SOURCE=/path/to/libvirt/source

# Run code generation (generates *.gen.go files)
go generate ./...

# Individual generation steps:
scripts/gen-consts.sh  # Generates const.gen.go via c-for-go
# Internal lvgen tool processes RPC protocol definitions
```

**Note**: Generated files (`*.gen.go`) contain ~20K lines of libvirt API bindings. These should not be edited directly.

## Code Architecture

### Core Components

**Main Client Layer** (`libvirt.go`):
- Hand-written convenience methods and connection management
- Wraps generated protocol methods with idiomatic Go interfaces

**RPC Layer** (`rpc.go`):
- Core communication with libvirt daemon via XDR protocol
- Handles request/response lifecycle and connection management

**Transport Layer** (`socket/`):
- Pluggable connection methods: Unix sockets, TCP, TLS, SSH
- URI-based connection configuration similar to libvirt native tools

**Generated Protocol Layer** (`*.gen.go`):
- `remote_protocol.gen.go`: Main libvirt RPC methods (~17K lines)  
- `qemu_protocol.gen.go`: QEMU-specific extensions
- `const.gen.go`: Constants and enums from C headers

**Event System** (`internal/event/`):
- Asynchronous event streaming with Go channels
- Context-based cancellation and callback management

### Key Patterns

**Code Generation Workflow**:
1. `c-for-go` extracts constants from libvirt C headers
2. Custom `lvgen` parser processes RPC protocol definitions  
3. Go templates generate type-safe API methods

**Connection Management**:
- URI schemes determine transport method (unix://, tcp://, ssh://, etc.)
- Automatic dialer selection and connection pooling per client instance
- Graceful disconnection handling with resource cleanup

**Protocol Handling**:
- Custom XDR encoding/decoding for libvirt's wire protocol
- Type-safe marshaling of complex nested structures
- Error extraction from both libvirt and QEMU JSON responses

## Testing Infrastructure

**Mock Framework**: `libvirttest/` provides mock libvirt server for unit tests
**Test Data**: `testdata/` contains XML definitions for domains, pools, networks
**Integration Setup**: Tests create actual VMs and storage resources when run with `-tags=integration`

## Development Notes

- Generated code is tied to specific libvirt version - regenerate when updating libvirt sources
- Hand-written methods in `libvirt.go` are often deprecated in favor of generated equivalents
- Connection interruption is detected and handled gracefully with proper cleanup
- Event streaming uses efficient channel-based delivery with context cancellation
- Missing libvirt functions return "unimplemented" errors on older daemon versions