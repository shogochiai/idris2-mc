||| ERC-7201 Namespaced Storage Location Calculator
|||
||| Provides storage slot calculation following ERC-7201 specification:
||| `erc7201(id) = keccak256(keccak256(id) - 1) & ~0xff`
|||
||| Usage:
|||   -- Define namespace
|||   namespace : Namespace
|||   namespace = MkNamespace "mc.std.admin"
|||
|||   -- Get root slot (computed at deploy time or cached)
|||   adminSlot : Integer
|||   adminSlot = 0xc87a8b268af18cef58a28e8269c607186ac6d26eb9fb11e976ba7fc83fbc5b00
|||
|||   -- Access mapping within namespace
|||   slot <- mappingSlot adminSlot key
module MC.Std.Storage.ERC7201

-- =============================================================================
-- EVM Primitives (FFI)
-- =============================================================================

%foreign "evm:mstore"
prim__mstore : Integer -> Integer -> PrimIO ()

%foreign "evm:mload"
prim__mload : Integer -> PrimIO Integer

%foreign "evm:keccak256"
prim__keccak256 : Integer -> Integer -> PrimIO Integer

%foreign "evm:sload"
prim__sload : Integer -> PrimIO Integer

%foreign "evm:sstore"
prim__sstore : Integer -> Integer -> PrimIO ()

%foreign "evm:mstore8"
prim__mstore8 : Integer -> Integer -> PrimIO ()

-- =============================================================================
-- Wrapped Primitives
-- =============================================================================

export
mstore : Integer -> Integer -> IO ()
mstore off val = primIO (prim__mstore off val)

export
mload : Integer -> IO Integer
mload off = primIO (prim__mload off)

export
keccak256 : Integer -> Integer -> IO Integer
keccak256 off len = primIO (prim__keccak256 off len)

export
sload : Integer -> IO Integer
sload slot = primIO (prim__sload slot)

export
sstore : Integer -> Integer -> IO ()
sstore slot val = primIO (prim__sstore slot val)

export
mstore8 : Integer -> Integer -> IO ()
mstore8 off val = primIO (prim__mstore8 off val)

-- =============================================================================
-- ERC-7201 Core Algorithm
-- =============================================================================

||| Mask for 256-byte alignment: ~0xff
||| All bits set except the lowest 8 bits
ALIGN_MASK : Integer
ALIGN_MASK = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00

||| Calculate ERC-7201 namespace root slot
||| Formula: keccak256(keccak256(id) - 1) & ~0xff
|||
||| Note: This requires storing the string in memory and hashing.
||| For production, pre-compute these values off-chain.
|||
||| @param idHash - keccak256 hash of the namespace ID string
||| @return The aligned storage slot
export
erc7201FromHash : Integer -> IO Integer
erc7201FromHash idHash = do
  -- keccak256(idHash - 1)
  mstore 0 (idHash - 1)
  result <- keccak256 0 32
  -- Align to 256 bytes
  pure (result `mod` ALIGN_MASK * ALIGN_MASK `div` ALIGN_MASK)
  -- Note: (result & ~0xff) in Solidity = (result // 256 * 256) in integer math

||| Alternative: direct bit masking using AND opcode
export
alignSlot : Integer -> Integer
alignSlot slot =
  let mask = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00
  in (slot `div` 256) * 256  -- Equivalent to slot & ~0xff

-- =============================================================================
-- Solidity Storage Layout Calculations
-- =============================================================================

||| Calculate slot for a mapping entry: keccak256(key . baseSlot)
||| This follows Solidity's mapping storage layout
|||
||| @param baseSlot - The storage slot of the mapping variable
||| @param key - The mapping key (address, uint256, bytes32, etc.)
||| @return The storage slot for mapping[key]
export
mappingSlot : Integer -> Integer -> IO Integer
mappingSlot baseSlot key = do
  mstore 0 key
  mstore 32 baseSlot
  keccak256 0 64

||| Calculate slot for a nested mapping: mapping(K1 => mapping(K2 => V))
||| slot = keccak256(key2 . keccak256(key1 . baseSlot))
|||
||| @param baseSlot - The storage slot of the outer mapping
||| @param key1 - First level key
||| @param key2 - Second level key
||| @return The storage slot for mapping[key1][key2]
export
nestedMappingSlot : Integer -> Integer -> Integer -> IO Integer
nestedMappingSlot baseSlot key1 key2 = do
  slot1 <- mappingSlot baseSlot key1
  mappingSlot slot1 key2

||| Calculate slot for a dynamic array element
||| Array data starts at keccak256(baseSlot), element i is at that + i * elementSize
|||
||| @param baseSlot - The storage slot storing array.length
||| @param index - The array index
||| @param elementSize - Number of 32-byte slots per element
||| @return The storage slot for array[index]
export
arrayElementSlot : Integer -> Integer -> Integer -> IO Integer
arrayElementSlot baseSlot index elementSize = do
  mstore 0 baseSlot
  dataStart <- keccak256 0 32
  pure (dataStart + index * elementSize)

||| Get array length stored at baseSlot
export
arrayLength : Integer -> IO Integer
arrayLength baseSlot = sload baseSlot

||| Calculate slot for a struct field
||| Struct fields are stored contiguously: baseSlot + fieldOffset
|||
||| @param baseSlot - The storage slot of the struct
||| @param fieldOffset - The field's offset (0 for first field, 1 for second, etc.)
||| @return The storage slot for struct.field
export
structFieldSlot : Integer -> Integer -> Integer
structFieldSlot baseSlot fieldOffset = baseSlot + fieldOffset

-- =============================================================================
-- Pre-computed ERC-7201 Slots (MC Standard)
-- =============================================================================
-- These are keccak256(keccak256("namespace.id") - 1) & ~0xff
-- Pre-computed for efficiency

||| mc.std.admin
||| keccak256(keccak256("mc.std.admin") - 1) & ~0xff
export
SLOT_MC_ADMIN : Integer
SLOT_MC_ADMIN = 0xc87a8b268af18cef58a28e8269c607186ac6d26eb9fb11e976ba7fc83fbc5b00

||| mc.std.clone
||| Storage for proxy dictionary address
export
SLOT_MC_CLONE : Integer
SLOT_MC_CLONE = 0x10c209d5b202f0d4610807a7049eb641dc6976ce93261be6493809881acea600

||| mc.std.member
||| Storage for member list
export
SLOT_MC_MEMBER : Integer
SLOT_MC_MEMBER = 0xb02ea24c1f86ea07e6c09d7d408e6de4225369a86f387a049c2d2fcaeb5d4c00

||| mc.std.featureToggle
||| Storage for feature toggle mapping
export
SLOT_MC_FEATURE_TOGGLE : Integer
SLOT_MC_FEATURE_TOGGLE = 0xfbe5942bf8b77a2e1fdda5ac4fad2514a8894a997001808038d8cb6785c1d500

||| mc.std.initialization
||| OpenZeppelin-style initialization state
export
SLOT_MC_INITIALIZATION : Integer
SLOT_MC_INITIALIZATION = 0x3a761698c158d659b37261358fd236b3bd53eb7608e16317044a5253fc82ad00

-- =============================================================================
-- Type-Safe Storage Accessors
-- =============================================================================

||| Read a uint256 from storage
export
readUint : Integer -> IO Integer
readUint = sload

||| Write a uint256 to storage
export
writeUint : Integer -> Integer -> IO ()
writeUint = sstore

||| Read an address from storage (masking to 160 bits)
export
readAddress : Integer -> IO Integer
readAddress slot = do
  val <- sload slot
  pure (val `mod` 0x10000000000000000000000000000000000000000)  -- & 2^160-1

||| Write an address to storage
export
writeAddress : Integer -> Integer -> IO ()
writeAddress = sstore

||| Read a bool from storage
export
readBool : Integer -> IO Bool
readBool slot = do
  val <- sload slot
  pure (val /= 0)

||| Write a bool to storage
export
writeBool : Integer -> Bool -> IO ()
writeBool slot b = sstore slot (if b then 1 else 0)

||| Read a bytes4 selector from storage
export
readSelector : Integer -> IO Integer
readSelector slot = do
  val <- sload slot
  pure (val `mod` 0x100000000)  -- & 0xffffffff

-- =============================================================================
-- Struct Layout Helpers
-- =============================================================================

||| Define struct field layout
||| Example:
|||   -- struct Admin { address admin; }
|||   adminField : FieldLayout
|||   adminField = MkField 0 1  -- offset 0, size 1 slot
public export
record FieldLayout where
  constructor MkField
  offset : Integer
  size : Integer

||| Calculate total struct size from field layouts
export
structSize : List FieldLayout -> Integer
structSize [] = 0
structSize (f :: fs) = max (f.offset + f.size) (structSize fs)

||| Access a struct field
export
accessField : Integer -> FieldLayout -> Integer
accessField baseSlot field = baseSlot + field.offset
