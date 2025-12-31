||| Subcontract Standard Function: Clone
|||
||| Creates new proxy contracts pointing to the same dictionary.
||| Uses EIP-1167 minimal proxy pattern.
module Subcontract.Std.Functions.Clone

import EVM.Storage.ERC7201
import EVM.Storage.ERC7546

-- =============================================================================
-- Additional EVM Primitives
-- =============================================================================

%foreign "evm:create"
prim__create : Integer -> Integer -> Integer -> PrimIO Integer

%foreign "evm:shl"
prim__shl : Integer -> Integer -> PrimIO Integer

%foreign "evm:or"
prim__or : Integer -> Integer -> PrimIO Integer

%foreign "evm:log2"
prim__log2 : Integer -> Integer -> Integer -> Integer -> PrimIO ()

create : Integer -> Integer -> Integer -> IO Integer
create value off size = primIO (prim__create value off size)

shl : Integer -> Integer -> IO Integer
shl shift val = primIO (prim__shl shift val)

bitor : Integer -> Integer -> IO Integer
bitor a b = primIO (prim__or a b)

log2 : Integer -> Integer -> Integer -> Integer -> IO ()
log2 off size topic1 topic2 = primIO (prim__log2 off size topic1 topic2)

-- =============================================================================
-- Event Signatures
-- =============================================================================

||| ProxyCreated(address indexed dictionary, address indexed proxy)
export
EVENT_PROXY_CREATED : Integer
EVENT_PROXY_CREATED = 0x9678a1e87ca9f1a37dc659a97b39d812d98cd236947e1b53b3d0d6fd346acb6e

-- =============================================================================
-- EIP-1167 Minimal Proxy Bytecode
-- =============================================================================

||| Create EIP-1167 minimal proxy pointing to dictionary
||| Uses the same bytecode as ProxyCreator
export
createMinimalProxy : Integer -> IO Integer
createMinimalProxy dictionary = do
  -- EIP-1167 minimal proxy bytecode:
  -- 0x363d3d373d3d3d363d73 <address> 5af43d82803e903d91602b57fd5bf3
  --
  -- Build in memory using shl/or opcodes
  let prefix10 = 0x363d3d373d3d3d363d73  -- 10 bytes
  let suffix2 = 0x5af4  -- 2 bytes

  -- Shift prefix left 176 bits (22 bytes)
  prefixShifted <- shl 176 prefix10
  -- Shift dictionary left 16 bits (2 bytes)
  dictShifted <- shl 16 dictionary
  -- Combine: prefix | dict | suffix2
  tmp1 <- bitor prefixShifted dictShifted
  word0 <- bitor tmp1 suffix2
  mstore 0 word0

  -- Remaining 13 bytes of suffix at offset 32
  -- 0x3d82803e903d91602b57fd5bf3 (13 bytes)
  let suffix13 = 0x3d82803e903d91602b57fd5bf3
  -- Shift left by 152 bits (19 bytes) to left-align
  word1 <- shl 152 suffix13
  mstore 32 word1

  -- Create the proxy contract with 0 ETH value
  -- Total bytecode size: 45 bytes
  create 0 0 45

-- =============================================================================
-- Clone Function
-- =============================================================================

||| Clone the current contract (create new proxy with same dictionary)
export
clone : IO Integer
clone = do
  dictionary <- getDictionary
  proxyAddr <- createMinimalProxy dictionary
  -- Emit event
  log2 0 0 EVENT_PROXY_CREATED dictionary
  pure proxyAddr

||| Clone with custom dictionary
export
cloneWithDictionary : Integer -> IO Integer
cloneWithDictionary dictionary = do
  proxyAddr <- createMinimalProxy dictionary
  log2 0 0 EVENT_PROXY_CREATED dictionary
  pure proxyAddr
