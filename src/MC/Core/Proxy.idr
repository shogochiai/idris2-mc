||| MC Core: ERC-7546 UCS Proxy Contract
|||
||| Implements the ERC-7546 proxy pattern using idris2-yul's storage API.
||| Forwards all calls to a dictionary contract via DELEGATECALL.
|||
||| Reference: https://eips.ethereum.org/EIPS/eip-7546
module MC.Core.Proxy

import EVM.Storage.ERC7201
import EVM.Storage.ERC7546

-- =============================================================================
-- Proxy Entry Point
-- =============================================================================

||| Main entry point for the proxy contract
||| Simply forwards all calls to the dictionary using ERC-7546 pattern
export
proxyMain : IO ()
proxyMain = forwardToDictionary

-- =============================================================================
-- Initialization
-- =============================================================================

||| Initialize proxy with dictionary address
||| Should be called during deployment via constructor
export
initializeProxy : Integer -> IO ()
initializeProxy dictionary = setDictionary dictionary

-- =============================================================================
-- Query Functions (View)
-- =============================================================================

||| Get the current dictionary address
export
getProxyDictionary : IO Integer
getProxyDictionary = getDictionary

-- =============================================================================
-- Upgrade Functions (Admin only in practice)
-- =============================================================================

||| Upgrade to a new dictionary
||| Note: Access control should be implemented by the calling contract
export
upgradeProxyDictionary : Integer -> IO ()
upgradeProxyDictionary = upgradeDictionary
