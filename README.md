# idris2-subcontract

**Subcontract framework for Idris2 - UCS patterns on idris2-yul**

Provides ERC-7546 UCS (Upgradeable Clone for Scalable contracts) implementation and standard functions for building modular smart contracts in Idris2.

## Overview

idris2-subcontract provides:

- **ERC-7546 Proxy**: DELEGATECALL-based proxy forwarding to dictionary
- **Dictionary Contract**: Function selector -> implementation mapping
- **Standard Functions**: FeatureToggle, Clone, Receive
- **Type-Safe API**: ABI signatures, decoders, and entry points
- **Storage Capability**: Controlled storage access via `StorageCap`

## Installation

### Using pack

Add to your `pack.toml`:

```toml
[custom.all.idris2-subcontract]
type = "local"
path = "/path/to/idris2-subcontract"
ipkg = "idris2-subcontract.ipkg"
```

Then build:

```bash
pack build idris2-subcontract
```

### Dependencies

- [idris2-yul](https://github.com/shogochiai/idris2-yul) - Idris2 to EVM/Yul compiler

## Module Structure

```
Subcontract/
├── Standards/
│   └── ERC7546/           # ERC-7546 implementation
│       ├── Slots.idr      # Constants (DICTIONARY_SLOT, etc.)
│       ├── Forward.idr    # Proxy forwarding logic
│       ├── Proxy.idr      # Proxy exports
│       └── Dictionary.idr # Dictionary contract
├── Core/
│   ├── Proxy.idr          # Re-exports Standards.ERC7546.Proxy
│   ├── Dictionary.idr     # Re-exports Standards.ERC7546.Dictionary
│   ├── Entry.idr          # Type-safe entry points
│   ├── StorageCap.idr     # Storage capability token
│   ├── ABI/
│   │   ├── Sig.idr        # Function signatures
│   │   └── Decoder.idr    # Calldata decoding
│   └── ...
└── Std/
    └── Functions/
        ├── FeatureToggle.idr  # Admin feature toggle
        ├── Clone.idr          # EIP-1167 proxy cloning
        └── Receive.idr        # ETH receive handling
```

## Quick Start

### Basic Proxy Contract

```idris
import Subcontract.Core.Proxy

main : IO ()
main = proxyMain
```

### Type-Safe Entry Points

```idris
import Subcontract.Core.Entry
import Subcontract.Core.ABI.Sig
import Subcontract.Core.ABI.Decoder

-- Define signature
addMemberSig : Sig
addMemberSig = MkSig "addMember(address,bytes32)"

addMemberSel : Sel addMemberSig
addMemberSel = MkSel 0x12345678

-- Create entry point
addMemberEntry : Entry addMemberSig
addMemberEntry = MkEntry addMemberSel $ do
  (addr, meta) <- runDecoder (decodeAddress <&> decodeBytes32)
  idx <- addMemberImpl (addrValue addr) (bytes32Value meta)
  returnUint idx

-- Dispatch
main : IO ()
main = dispatch [entry addMemberEntry]
```

### Storage Capability Pattern

```idris
import Subcontract.Core.StorageCap

-- Handler receives StorageCap from framework
myHandler : Handler Integer
myHandler cap = do
  val <- sloadCap cap SLOT_DATA
  sstoreCap cap SLOT_DATA (val + 1)
  pure val

-- Framework provides capability
main : IO ()
main = do
  result <- runHandler myHandler
  returnUint result
```

### Feature Toggle

```idris
import Subcontract.Std.Functions.FeatureToggle

myFunction : IO ()
myFunction = do
  shouldBeActive 0x12345678  -- Revert if disabled
  -- ... function logic
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        idris2-subcontract                           │
├─────────────────────────────────────────────────────────────────────┤
│  Subcontract.Std.Functions.*     Application-level functions       │
│  Subcontract.Core.*              Framework core (Entry, StorageCap)│
│  Subcontract.Standards.ERC7546.* ERC-7546 implementation           │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ imports
┌──────────────────────────────▼──────────────────────────────────────┐
│                          idris2-yul                                 │
├─────────────────────────────────────────────────────────────────────┤
│  EVM.Primitives              All EVM FFI definitions               │
│  EVM.Storage.Namespace       ERC-7201 slot calculations            │
│  EVM.ABI.*                   ABI encoding/decoding                 │
│  Compiler.EVM.*              Yul code generation                   │
└─────────────────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

| Layer | Package | Responsibility |
|-------|---------|----------------|
| FFI | idris2-yul | `%foreign "evm:*"` primitives |
| Storage | idris2-yul | ERC-7201 slot calculations |
| Standards | idris2-subcontract | ERC-7546 proxy/dictionary |
| Framework | idris2-subcontract | Entry points, capabilities |
| Application | your-project | Business logic |

## ERC-7546 UCS Pattern

The Upgradeable Clone for Scalable contracts pattern:

```
┌─────────────┐     DELEGATECALL     ┌────────────────┐
│    Proxy    │ ──────────────────► │   Dictionary   │
│  (ERC-7546) │                      │ selector→impl  │
└─────────────┘                      └───────┬────────┘
                                             │
                    ┌────────────────────────┼────────────────────────┐
                    │                        │                        │
              ┌─────▼─────┐           ┌──────▼──────┐          ┌──────▼──────┐
              │FeatureToggle│         │    Clone    │          │   Receive   │
              │  function  │          │  function   │          │  function   │
              └────────────┘          └─────────────┘          └─────────────┘
```

## Related Projects

- [idris2-yul](https://github.com/shogochiai/idris2-yul) - Idris2 to EVM/Yul compiler
- [idris2-textdao](https://github.com/ecdysisxyz/idris2-textdao) - Example application
- [EIP-7546](https://eips.ethereum.org/EIPS/eip-7546) - UCS Proxy Standard

## Documentation

- [API Reference](docs/API.md) - Module API documentation
- [Storage Guide](docs/STORAGE.md) - EVM storage layout guide
- [Architecture](docs/ARCHITECTURE.md) - Layer design and rationale

## License

MIT
