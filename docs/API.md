# idris2-subcontract API Reference

## Module: Subcontract.Standards.ERC7546.Slots

Constants for ERC-7546 UCS pattern storage slots and selectors.

### Storage Slots

```idris
||| Dictionary storage slot
||| keccak256("erc7546.proxy.dictionary") - 1
DICTIONARY_SLOT : Integer
DICTIONARY_SLOT = 0x267691be3525af8a813d30db0c9e2bad08f63baecf6dceb85e2cf3676cff56f4
```

### Function Selectors

| Constant | Function | Value |
|----------|----------|-------|
| `SEL_GET_IMPL` | `getImplementation(bytes4)` | `0xdc9cc645` |
| `SEL_SET_IMPL` | `setImplementation(bytes4,address)` | `0x2c3c3e4e` |
| `SEL_OWNER` | `owner()` | `0x8da5cb5b` |
| `SEL_TRANSFER` | `transferOwnership(address)` | `0xf2fde38b` |

### Events

| Constant | Event | Topic |
|----------|-------|-------|
| `EVENT_DICTIONARY_UPGRADED` | `DictionaryUpgraded(address indexed)` | `0x23e4...` |

---

## Module: Subcontract.Standards.ERC7546.Forward

Core forwarding functions for ERC-7546 proxy pattern.

### Dictionary Access

```idris
||| Get dictionary address from storage
getDictionary : IO Integer

||| Set dictionary address in storage
setDictionary : Integer -> IO ()
```

### Query Implementation

```idris
||| Query dictionary for implementation address via STATICCALL
||| Calls dictionary.getImplementation(bytes4 selector)
|||
||| @param selector - The function selector to look up
||| @return Implementation address, or 0 if not found
queryDictionary : Integer -> IO Integer
```

**Example:**
```idris
impl <- queryDictionary 0x12345678
if impl == 0
  then evmRevert 0 0
  else -- call implementation
```

### Forwarding

```idris
||| Forward call to dictionary via DELEGATECALL
||| Simple pattern where dictionary handles dispatch
forwardToDictionary : IO ()

||| Forward call to implementation (correct ERC-7546 flow)
||| 1. Extract selector from calldata
||| 2. Query dictionary for implementation (STATICCALL)
||| 3. DELEGATECALL to implementation
forwardToImplementation : IO ()
```

### Upgrade

```idris
||| Upgrade dictionary to new address, emit DictionaryUpgraded event
upgradeDictionary : Integer -> IO ()
```

---

## Module: Subcontract.Core.ABI.Sig

Type-safe function signatures and selectors with phantom type binding.

### ABI Types

```idris
||| Static ABI types (32 bytes each)
data ABIStaticType
  = TUint256
  | TBytes32
  | TAddress
  | TBool

||| Get canonical Solidity type string
abiTypeStr : ABIStaticType -> String
-- abiTypeStr TAddress = "address"
```

### Function Signature

```idris
||| Function signature with name and typed parameters
record Sig where
  constructor MkSig
  name : String
  args : List ABIStaticType
  rets : List ABIStaticType

||| Generate canonical signature string
sigString : Sig -> String
-- sigString (MkSig "transfer" [TAddress, TUint256] [TBool])
-- => "transfer(address,uint256)"
```

**Example:**
```idris
transferSig : Sig
transferSig = MkSig "transfer" [TAddress, TUint256] [TBool]
```

### Phantom-Typed Selector

```idris
||| Selector bound to specific signature via phantom type
data Sel : (sig : Sig) -> Type where
  MkSel : (value : Integer) -> Sel sig

||| Extract 4-byte selector value
selValue : Sel sig -> Integer

||| Show selector with signature for debugging
showSel : {sig : Sig} -> Sel sig -> String
```

**Example:**
```idris
transferSel : Sel transferSig
transferSel = MkSel 0xa9059cbb

-- Type-safe: transferSel can only be used with transferSig
```

---

## Module: Subcontract.Core.ABI.Decoder

Type-safe calldata decoder with automatic offset tracking.

### Typed Wrappers

```idris
record Address where
  constructor MkAddress
  addrValue : Integer

record Bytes32 where
  constructor MkBytes32
  bytes32Value : Integer

record Uint256 where
  constructor MkUint256
  uint256Value : Integer
```

### Decoder Monad

```idris
||| Decoder that reads from calldata at current offset
||| Offset starts at 4 (after selector) and advances by 32 per slot
record Decoder a where
  constructor MkDecoder
  runDec : Integer -> IO (a, Integer)

-- Implements Functor, Applicative, Monad
```

### Primitive Decoders

```idris
||| Decode raw 32-byte slot
decodeSlot : Decoder Integer

||| Decode Address (masked to 20 bytes)
decodeAddress : Decoder Address

||| Decode Bytes32
decodeBytes32 : Decoder Bytes32

||| Decode Uint256
decodeUint256 : Decoder Uint256

||| Decode Bool (non-zero = True)
decodeBool : Decoder Bool
```

### Runner

```idris
||| Run decoder starting at offset 4 (after selector)
runDecoder : Decoder a -> IO a

||| Get current offset (for debugging)
getOffset : Decoder Integer
```

**Example:**
```idris
-- Decode transfer(address to, uint256 amount)
decodeTransfer : Decoder (Address, Uint256)
decodeTransfer = do
  to <- decodeAddress
  amount <- decodeUint256
  pure (to, amount)

-- In entry point:
main : IO ()
main = do
  (to, amount) <- runDecoder decodeTransfer
  transferImpl (addrValue to) (uint256Value amount)
```

---

## Module: Subcontract.Core.Entry

Type-safe entry points with dispatch.

### Entry Point

```idris
||| Entry point bound to specific signature
record Entry (sig : Sig) where
  constructor MkEntry
  selector : Sel sig
  handler : IO ()
```

### Existential Wrapper

```idris
||| Existential wrapper for entries with different signatures
data SomeEntry : Type where
  MkSomeEntry : {sig : Sig} -> Entry sig -> SomeEntry

||| Convert typed entry to existential
entry : {sig : Sig} -> Entry sig -> SomeEntry
```

### Dispatch

```idris
||| Dispatch based on selector from calldata
||| Finds matching entry and executes handler, reverts if not found
dispatch : List SomeEntry -> IO ()

||| Get list of registered selector values (for debugging)
registeredSelectors : List SomeEntry -> List Integer
```

**Example:**
```idris
-- Define entries
transferEntry : Entry transferSig
transferEntry = MkEntry transferSel $ do
  (to, amount) <- runDecoder decodeTransfer
  transferImpl (addrValue to) (uint256Value amount)
  returnBool True

balanceOfEntry : Entry balanceOfSig
balanceOfEntry = MkEntry balanceOfSel $ do
  addr <- runDecoder decodeAddress
  bal <- getBalance (addrValue addr)
  returnUint bal

-- Dispatch
main : IO ()
main = dispatch [entry transferEntry, entry balanceOfEntry]
```

---

## Module: Subcontract.Core.StorageCap

Capability-based storage access control.

### Storage Capability

```idris
||| Opaque capability token
||| Constructor not exported - only framework can create
data StorageCap : Type

||| Handler type: function that receives StorageCap
Handler : Type -> Type
Handler a = StorageCap -> IO a
```

### Storage Operations (require capability)

```idris
||| Read from storage slot
sloadCap : StorageCap -> Integer -> IO Integer

||| Write to storage slot
sstoreCap : StorageCap -> Integer -> Integer -> IO ()

||| Memory store
mstoreCap : StorageCap -> Integer -> Integer -> IO ()

||| Keccak256 hash
keccak256Cap : StorageCap -> Integer -> Integer -> IO Integer
```

### Mapping Operations

```idris
||| Calculate mapping slot: keccak256(key . baseSlot)
mappingSlotCap : StorageCap -> Integer -> Integer -> IO Integer

||| Read from mapping
readMappingCap : StorageCap -> Integer -> Integer -> IO Integer

||| Write to mapping
writeMappingCap : StorageCap -> Integer -> Integer -> Integer -> IO ()
```

### Running Handlers

```idris
||| Run handler with storage capability
||| Only framework calls this - user code receives the cap
runHandler : Handler a -> IO a
```

### Composing Handlers

```idris
||| Pure handler (no storage access)
pureHandler : a -> Handler a

||| Bind handlers
bindHandler : Handler a -> (a -> Handler b) -> Handler b

||| Sequence handlers
seqHandler : Handler () -> Handler b -> Handler b
```

**Example:**
```idris
SLOT_BALANCE : Integer
SLOT_BALANCE = 0x1234...

getBalanceHandler : Integer -> Handler Integer
getBalanceHandler addr cap = do
  readMappingCap cap SLOT_BALANCE addr

setBalanceHandler : Integer -> Integer -> Handler ()
setBalanceHandler addr amount cap = do
  writeMappingCap cap SLOT_BALANCE addr amount

-- In main:
main : IO ()
main = do
  addr <- caller
  balance <- runHandler (getBalanceHandler addr)
  returnUint balance
```

---

## Module: Subcontract.Std.Functions.FeatureToggle

Admin-controlled feature enable/disable.

### Storage

| Slot | Description |
|------|-------------|
| `SLOT_ADMIN` | Admin address |
| `SLOT_FEATURE_TOGGLE` | Mapping: selector -> disabled |

### Functions

```idris
||| Check if caller is admin
isAdmin : IO Bool

||| Require caller to be admin, revert if not
requireAdmin : IO ()

||| Check if feature (selector) is disabled
isFeatureDisabled : Integer -> IO Bool

||| Revert if feature is disabled
shouldBeActive : Integer -> IO ()

||| Toggle feature enabled/disabled (admin only)
featureToggle : Integer -> IO ()

||| Enable specific feature (admin only)
enableFeature : Integer -> IO ()

||| Disable specific feature (admin only)
disableFeature : Integer -> IO ()
```

**Example:**
```idris
myFunction : IO ()
myFunction = do
  shouldBeActive 0x12345678  -- Revert if disabled
  -- ... function logic
```

---

## Module: Subcontract.Std.Functions.Clone

EIP-1167 minimal proxy creation.

### Functions

```idris
||| Create EIP-1167 minimal proxy pointing to dictionary
createMinimalProxy : Integer -> IO Integer

||| Clone current contract (new proxy with same dictionary)
clone : IO Integer

||| Clone with custom dictionary
cloneWithDictionary : Integer -> IO Integer
```

### Events

| Event | Topic |
|-------|-------|
| `ProxyCreated(address indexed dictionary, address indexed proxy)` | `EVENT_PROXY_CREATED` |

---

## Module: Subcontract.Std.Functions.Receive

ETH receive handling.

### Functions

```idris
||| Emit Received event
emitReceived : Integer -> Integer -> IO ()

||| Handle incoming ETH transfer
receive : IO ()

||| Main dispatcher for receive functionality
||| If calldata is empty, treat as receive()
receiveMain : IO ()
```

### Events

| Event | Topic |
|-------|-------|
| `Received(address indexed from, uint256 amount)` | `EVENT_RECEIVED` |

---

## EVM Primitives (from idris2-yul)

The following are imported from `EVM.Primitives`:

```idris
-- Storage
sload : Integer -> IO Integer
sstore : Integer -> Integer -> IO ()

-- Memory
mstore : Integer -> Integer -> IO ()
mload : Integer -> IO Integer

-- Calldata
calldatasize : IO Integer
calldataload : Integer -> IO Integer
calldatacopy : Integer -> Integer -> Integer -> IO ()

-- Return/Revert
evmReturn : Integer -> Integer -> IO ()
evmRevert : Integer -> Integer -> IO ()
stop : IO ()

-- Context
caller : IO Integer
callvalue : IO Integer
gas : IO Integer

-- External calls
staticcall : Integer -> Integer -> Integer -> Integer -> Integer -> Integer -> IO Integer
delegatecall : Integer -> Integer -> Integer -> Integer -> Integer -> Integer -> IO Integer

-- Helpers
getSelector : IO Integer
returnUint : Integer -> IO ()
returnBool : Bool -> IO ()
returnOrRevert : Integer -> Integer -> Integer -> IO ()
```

See `EVM.Storage.Namespace` for mapping/array slot calculations.
