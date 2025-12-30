||| Schema Definition DSL for ERC-7201 Storage
|||
||| Provides a declarative way to define storage schemas similar to Solidity:
|||
|||   -- Solidity:
|||   -- /// @custom:storage-location erc7201:textdao.deliberation
|||   -- struct $Deliberation {
|||   --     Proposal[] proposals;
|||   --     DeliberationConfig config;
|||   -- }
|||
|||   -- Idris2:
|||   DeliberationSchema : Schema
|||   DeliberationSchema = MkSchema "textdao.deliberation"
|||     [ ArrayField "proposals" ProposalSchema
|||     , StructField "config" ConfigSchema
|||     ]
|||
module MC.Std.Storage.Schema

import MC.Std.Storage.ERC7201

-- =============================================================================
-- Schema Type Definitions
-- =============================================================================

||| Primitive storage types
public export
data StorageType
  = TUint256      -- uint256
  | TUint128      -- uint128 (packed)
  | TUint64       -- uint64 (packed)
  | TUint32       -- uint32 (packed)
  | TUint8        -- uint8 (packed)
  | TInt256       -- int256
  | TAddress      -- address (20 bytes)
  | TBool         -- bool
  | TBytes32      -- bytes32
  | TBytes4       -- bytes4 (selector)

||| Calculate slot size for a type (in 32-byte slots)
export
typeSlotSize : StorageType -> Integer
typeSlotSize TUint256 = 1
typeSlotSize TUint128 = 1  -- Takes full slot unless packed
typeSlotSize TUint64 = 1
typeSlotSize TUint32 = 1
typeSlotSize TUint8 = 1
typeSlotSize TInt256 = 1
typeSlotSize TAddress = 1
typeSlotSize TBool = 1
typeSlotSize TBytes32 = 1
typeSlotSize TBytes4 = 1

||| Field definition within a struct
public export
data FieldDef : Type where
  ||| Simple value field: field name, type, slot offset
  ValueField : String -> StorageType -> Integer -> FieldDef
  ||| Mapping field: field name, key type, value type, slot offset
  MappingField : String -> StorageType -> StorageType -> Integer -> FieldDef
  ||| Nested mapping: field name, key1 type, key2 type, value type, slot offset
  NestedMappingField : String -> StorageType -> StorageType -> StorageType -> Integer -> FieldDef
  ||| Dynamic array: field name, element size (slots), slot offset
  ArrayField : String -> Integer -> Integer -> FieldDef
  ||| Nested struct: field name, struct size (slots), slot offset
  StructField : String -> Integer -> Integer -> FieldDef

||| Get field name
export
fieldName : FieldDef -> String
fieldName (ValueField n _ _) = n
fieldName (MappingField n _ _ _) = n
fieldName (NestedMappingField n _ _ _ _) = n
fieldName (ArrayField n _ _) = n
fieldName (StructField n _ _) = n

||| Get field offset
export
fieldOffset : FieldDef -> Integer
fieldOffset (ValueField _ _ off) = off
fieldOffset (MappingField _ _ _ off) = off
fieldOffset (NestedMappingField _ _ _ _ off) = off
fieldOffset (ArrayField _ _ off) = off
fieldOffset (StructField _ _ off) = off

||| Schema definition
public export
record Schema where
  constructor MkSchema
  ||| Namespace ID (e.g., "textdao.deliberation")
  namespaceId : String
  ||| Pre-computed ERC-7201 root slot
  rootSlot : Integer
  ||| Field definitions
  fields : List FieldDef

-- =============================================================================
-- Schema Accessor Generation
-- =============================================================================

||| Get the root slot for a schema
export
schemaRoot : Schema -> Integer
schemaRoot = rootSlot

||| Get field slot from schema
export
getFieldSlot : Schema -> String -> Maybe Integer
getFieldSlot schema name = findField (fields schema)
  where
    findField : List FieldDef -> Maybe Integer
    findField [] = Nothing
    findField (f :: fs) =
      if fieldName f == name
        then Just (rootSlot schema + fieldOffset f)
        else findField fs

-- =============================================================================
-- Storage Access Functions
-- =============================================================================

||| Access a simple value field
export
accessValue : Schema -> String -> IO (Maybe Integer)
accessValue schema name =
  case getFieldSlot schema name of
    Nothing => pure Nothing
    Just slot => do
      val <- sload slot
      pure (Just val)

||| Access a mapping field
export
accessMapping : Schema -> String -> Integer -> IO (Maybe Integer)
accessMapping schema name key =
  case getFieldSlot schema name of
    Nothing => pure Nothing
    Just baseSlot => do
      slot <- mappingSlot baseSlot key
      val <- sload slot
      pure (Just val)

||| Access a nested mapping field
export
accessNestedMapping : Schema -> String -> Integer -> Integer -> IO (Maybe Integer)
accessNestedMapping schema name key1 key2 =
  case getFieldSlot schema name of
    Nothing => pure Nothing
    Just baseSlot => do
      slot <- nestedMappingSlot baseSlot key1 key2
      val <- sload slot
      pure (Just val)

||| Access an array element
export
accessArrayElement : Schema -> String -> Integer -> Integer -> IO (Maybe Integer)
accessArrayElement schema name index elemSize =
  case getFieldSlot schema name of
    Nothing => pure Nothing
    Just baseSlot => do
      slot <- arrayElementSlot baseSlot index elemSize
      val <- sload slot
      pure (Just val)

||| Get array length
export
getArrayLength : Schema -> String -> IO (Maybe Integer)
getArrayLength schema name =
  case getFieldSlot schema name of
    Nothing => pure Nothing
    Just slot => do
      len <- sload slot
      pure (Just len)

-- =============================================================================
-- Example: MC Standard Schemas
-- =============================================================================

||| Admin schema: { address admin; }
export
AdminSchema : Schema
AdminSchema = MkSchema
  "mc.std.admin"
  SLOT_MC_ADMIN
  [ ValueField "admin" TAddress 0
  ]

||| Clone schema: { address dictionary; }
export
CloneSchema : Schema
CloneSchema = MkSchema
  "mc.std.clone"
  SLOT_MC_CLONE
  [ ValueField "dictionary" TAddress 0
  ]

||| Member schema: { address[] members; }
export
MemberSchema : Schema
MemberSchema = MkSchema
  "mc.std.member"
  SLOT_MC_MEMBER
  [ ArrayField "members" 1 0  -- 1 slot per address
  ]

||| FeatureToggle schema: { mapping(bytes4 => bool) disabledFeature; }
export
FeatureToggleSchema : Schema
FeatureToggleSchema = MkSchema
  "mc.std.featureToggle"
  SLOT_MC_FEATURE_TOGGLE
  [ MappingField "disabledFeature" TBytes4 TBool 0
  ]

||| Initialization schema: { uint64 initialized; bool initializing; }
export
InitializationSchema : Schema
InitializationSchema = MkSchema
  "mc.std.initialization"
  SLOT_MC_INITIALIZATION
  [ ValueField "initialized" TUint64 0
  , ValueField "initializing" TBool 0  -- Packed in same slot
  ]

-- =============================================================================
-- Convenience Functions for Common Patterns
-- =============================================================================

||| Read admin address from Admin schema
export
readAdmin : IO Integer
readAdmin = do
  let slot = schemaRoot AdminSchema
  readAddress slot

||| Write admin address
export
writeAdmin : Integer -> IO ()
writeAdmin addr = do
  let slot = schemaRoot AdminSchema
  writeAddress slot addr

||| Read dictionary address from Clone schema
export
readDictionary : IO Integer
readDictionary = do
  let slot = schemaRoot CloneSchema
  readAddress slot

||| Check if a feature selector is disabled
export
isFeatureDisabled : Integer -> IO Bool
isFeatureDisabled selector = do
  let baseSlot = schemaRoot FeatureToggleSchema
  slot <- mappingSlot baseSlot selector
  readBool slot

||| Toggle feature enabled/disabled
export
toggleFeature : Integer -> IO ()
toggleFeature selector = do
  let baseSlot = schemaRoot FeatureToggleSchema
  slot <- mappingSlot baseSlot selector
  current <- readBool slot
  writeBool slot (not current)

||| Check if contract is initialized
export
isInitialized : IO Bool
isInitialized = do
  let slot = schemaRoot InitializationSchema
  val <- sload slot
  pure (val /= 0)

||| Get member at index
export
getMemberAt : Integer -> IO Integer
getMemberAt index = do
  let baseSlot = schemaRoot MemberSchema
  slot <- arrayElementSlot baseSlot index 1
  readAddress slot

||| Get member count
export
getMemberCount : IO Integer
getMemberCount = do
  let slot = schemaRoot MemberSchema
  arrayLength slot
