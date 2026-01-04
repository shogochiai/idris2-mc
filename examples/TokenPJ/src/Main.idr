||| TokenPJ Main Entry Point
|||
||| Combines all function modules into a single dispatcher.
||| This is the implementation contract deployed behind ERC-7546 proxy.
module Main

import Subcontract.Core.Entry

import Main.Functions.Transfer
import Main.Functions.Approve
import Main.Functions.Mint
import Main.Functions.View

-- =============================================================================
-- Main Dispatcher
-- =============================================================================

||| Token implementation entry point
||| Called via DELEGATECALL from Proxy
export
main : IO ()
main = dispatch
  [ -- Transfer
    entry transferEntry
    -- Approve
  , entry approveEntry
  , entry allowanceEntry
    -- Mint
  , entry mintEntry
    -- View
  , entry totalSupplyEntry
  , entry balanceOfEntry
  , entry ownerEntry
  ]
