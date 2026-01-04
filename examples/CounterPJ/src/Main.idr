||| CounterPJ Main Entry Point
module Main

import Subcontract.Core.Entry
import Main.Functions.Counter

export
main : IO ()
main = dispatch
  [ entry incrementEntry
  , entry decrementEntry
  , entry addEntry
  , entry getCountEntry
  ]
