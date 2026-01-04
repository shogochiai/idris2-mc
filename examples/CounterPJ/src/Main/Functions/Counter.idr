||| CounterPJ: Counter Functions
module Main.Functions.Counter

import EVM.Primitives
import Subcontract.Core.Entry
import Subcontract.Core.ABI.Sig
import Subcontract.Core.ABI.Decoder
import Main.Storages.Schema

-- =============================================================================
-- Events
-- =============================================================================

||| CountChanged(uint256 oldValue, uint256 newValue)
EVENT_COUNT_CHANGED : Integer
EVENT_COUNT_CHANGED = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef

emitCountChanged : Integer -> Integer -> IO ()
emitCountChanged oldVal newVal = do
  mstore 0 oldVal
  mstore 32 newVal
  log1 0 64 EVENT_COUNT_CHANGED

-- =============================================================================
-- Signatures
-- =============================================================================

public export
incrementSig : Sig
incrementSig = MkSig "increment" [] [TUint256]

public export
incrementSel : Sel incrementSig
incrementSel = MkSel 0xd09de08a

public export
decrementSig : Sig
decrementSig = MkSig "decrement" [] [TUint256]

public export
decrementSel : Sel decrementSig
decrementSel = MkSel 0x2baeceb7

public export
addSig : Sig
addSig = MkSig "add" [TUint256] [TUint256]

public export
addSel : Sel addSig
addSel = MkSel 0x1003e2d2

public export
getCountSig : Sig
getCountSig = MkSig "getCount" [] [TUint256]

public export
getCountSel : Sel getCountSig
getCountSel = MkSel 0xa87d942c

-- =============================================================================
-- Implementation
-- =============================================================================

increment : IO Integer
increment = do
  old <- getCount
  let new = old + 1
  setCount new
  emitCountChanged old new
  pure new

decrement : IO Integer
decrement = do
  old <- getCount
  if old == 0
    then do
      evmRevert 0 0
      pure 0
    else do
      let new = old - 1
      setCount new
      emitCountChanged old new
      pure new

add : Integer -> IO Integer
add amount = do
  old <- getCount
  let new = old + amount
  setCount new
  emitCountChanged old new
  pure new

-- =============================================================================
-- Entry Points
-- =============================================================================

export
incrementEntry : Entry incrementSig
incrementEntry = MkEntry incrementSel $ do
  result <- increment
  returnUint result

export
decrementEntry : Entry decrementSig
decrementEntry = MkEntry decrementSel $ do
  result <- decrement
  returnUint result

export
addEntry : Entry addSig
addEntry = MkEntry addSel $ do
  amount <- runDecoder decodeUint256
  result <- add (uint256Value amount)
  returnUint result

export
getCountEntry : Entry getCountSig
getCountEntry = MkEntry getCountSel $ do
  count <- getCount
  returnUint count
