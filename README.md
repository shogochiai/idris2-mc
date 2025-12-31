# idris2-subcontract

**Subcontract framework for Idris2 - UCS patterns on idris2-yul**

Provides ERC-7546 UCS (Upgradeable Clone for Scalable contracts) implementation and standard functions for building modular smart contracts in Idris2.

## Overview

idris2-subcontract provides:

- **ERC-7546 Proxy**: DELEGATECALL-based proxy forwarding to dictionary
- **Dictionary Contract**: Function selector → implementation mapping
- **Standard Functions**: FeatureToggle, Clone, Receive
- **Etherscan Verification**: Generate Solidity interfaces for ABI compatibility

## Installation

### Using pack

Add to your `pack.toml`:

```toml
[custom.all.idris2-subcontract]
type = "local"
path = "/path/to/idris2-subcontract"
ipkg = "idris2-subcontract.ipkg"
```

Then install:

```bash
pack install idris2-subcontract
```

### Dependencies

- [idris2-yul](https://github.com/shogochiai/idris2-yul) - Idris2 to EVM/Yul compiler

## Modules

### Core

| Module | Description |
|--------|-------------|
| `Subcontract.Core.Proxy` | ERC-7546 proxy with DELEGATECALL forwarding |
| `Subcontract.Core.Dictionary` | Selector → implementation mapping management |

### Standard Functions

| Module | Description |
|--------|-------------|
| `Subcontract.Std.Functions.FeatureToggle` | Admin-controlled function enable/disable |
| `Subcontract.Std.Functions.Clone` | EIP-1167 minimal proxy creation |
| `Subcontract.Std.Functions.Receive` | ETH receive with event emission |

## Quick Start

```idris
import Subcontract.Core.Proxy
import Subcontract.Core.Dictionary
import Subcontract.Std.Functions.FeatureToggle

-- Use proxy forwarding
main : IO ()
main = proxyMain

-- Check feature toggle before execution
myFunction : IO ()
myFunction = do
  shouldBeActive 0x12345678  -- Revert if disabled
  -- ... function logic
```

## Architecture

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

## Etherscan Verification

Subcontracts generate Solidity interfaces for Etherscan verification:

1. Define ABI using `EVM.ABI.Types` (in idris2-yul)
2. Generate Solidity interface with `toSolidityInterface`
3. Verify interface on Etherscan
4. Proxy bytecode can be compared against repository

```idris
import EVM.ABI.Types
import EVM.ABI.JSON

myABI : ContractABI
myABI = MkContractABI "MyContract"
  [ MkFunction "propose" 0x12345678
      [param "header" Bytes32, param "creator" Address]
      [anon Uint256]
      Nonpayable
  ]
  []  -- events
  []  -- errors

-- Generate: interface IMyContract { function propose(bytes32,address) external returns (uint256); }
solidityInterface : String
solidityInterface = toSolidityInterface myABI
```

## Related Projects

- [idris2-yul](https://github.com/shogochiai/idris2-yul) - Idris2 to EVM/Yul compiler
- [LazyEvm](https://github.com/ecdysisxyz/lazy) - Integration target
- [EIP-7546](https://eips.ethereum.org/EIPS/eip-7546) - UCS Proxy Standard

## License

MIT
