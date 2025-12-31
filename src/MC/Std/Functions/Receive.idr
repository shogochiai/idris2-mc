||| MC Standard Function: Receive
|||
||| Emits Received event when ETH is sent to the contract.
||| Handles the receive() fallback function.
module MC.Std.Functions.Receive

import EVM.Storage.ERC7201

-- =============================================================================
-- Additional EVM Primitives
-- =============================================================================

%foreign "evm:caller"
prim__caller : PrimIO Integer

%foreign "evm:callvalue"
prim__callvalue : PrimIO Integer

%foreign "evm:calldatasize"
prim__calldatasize : PrimIO Integer

%foreign "evm:log2"
prim__log2 : Integer -> Integer -> Integer -> Integer -> PrimIO ()

%foreign "evm:stop"
prim__stop : PrimIO ()

caller : IO Integer
caller = primIO prim__caller

callvalue : IO Integer
callvalue = primIO prim__callvalue

calldatasize : IO Integer
calldatasize = primIO prim__calldatasize

log2 : Integer -> Integer -> Integer -> Integer -> IO ()
log2 off size topic1 topic2 = primIO (prim__log2 off size topic1 topic2)

stop : IO ()
stop = primIO prim__stop

-- =============================================================================
-- Event Signature
-- =============================================================================

||| Received(address indexed from, uint256 amount)
||| keccak256("Received(address,uint256)")
export
EVENT_RECEIVED : Integer
EVENT_RECEIVED = 0x88a5966d370b9919b20f3e2c13ff65706f196a4e32cc2c12bf57088f88525874

-- =============================================================================
-- Receive Function
-- =============================================================================

||| Emit Received event with sender and amount
export
emitReceived : Integer -> Integer -> IO ()
emitReceived from amount = do
  mstore 0 amount
  log2 0 32 EVENT_RECEIVED from

||| Handle incoming ETH transfer
||| Equivalent to Solidity's receive() external payable
export
receive : IO ()
receive = do
  from <- caller
  amount <- callvalue
  emitReceived from amount

||| Main dispatcher for receive functionality
||| If calldata is empty, treat as receive()
export
receiveMain : IO ()
receiveMain = do
  size <- calldatasize
  if size == 0
    then do
      receive
      stop
    else stop  -- Unknown function, just stop
