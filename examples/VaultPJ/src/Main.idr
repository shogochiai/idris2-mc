||| VaultPJ Main Entry Point
module Main

import Subcontract.Core.Entry
import Main.Functions.Deposit
import Main.Functions.Withdraw
import Main.Functions.Admin

export
main : IO ()
main = dispatch
  [ -- Deposit
    entry depositEntry
  , entry depositOfEntry
    -- Withdraw
  , entry withdrawEntry
  , entry withdrawAllEntry
    -- Admin
  , entry pauseEntry
  , entry unpauseEntry
  , entry ownerEntry
  , entry totalDepositsEntry
  ]
