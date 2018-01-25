module Build.Generate (code) where

import Data.List (intercalate)
import Data.Either (rights)

import Types


code :: String -> [OpCode [[Type]]] -> String
code moduleName ops =
  "module " ++ moduleName ++ " (" ++ sepBy comma _op_name ops ++ ") where\n"
    ++ "import Codec.Beam.Internal.Types\n\n"
    ++ sepBy "\n\n" pp (concatMap topLevels ops)


-- AST


data TopLevel
  = Class Int String
  | Instance Int String Type
  | Function String Int [Either (Int, Type) Int]


topLevels :: OpCode [[Type]] -> [TopLevel]
topLevels (OpCode code name args) =
  let arguments = zipWith (argument name) [1..] args in
  Function name code (map (fmap fst) arguments) : concatMap snd (rights arguments)


argument :: String -> Int -> [Type] -> Either (Int, Type) (Int, [TopLevel])
argument _ index [type_]        = Left (index, type_)
argument baseName index types   = Right (index, constraint)
  where
    constraint = Class index baseName : map (Instance index baseName) types



-- PRETTY PRINTING


pp :: TopLevel -> String
pp topLevel =
  case topLevel of
    Class index baseName ->
      "class " ++ className index baseName ++ space
        ++ argumentName index ++ " where\n"
        ++ indent ++ methodName index baseName ++ " :: "
        ++ argumentName index ++ " -> " ++ encodingName

    Instance index baseName type_ ->
      "instance " ++ className index baseName ++ space
        ++ srcType type_ ++ " where\n"
        ++ indent ++ methodName index baseName ++ " = "
        ++ encoderName type_

    Function name opCode args ->
      name ++ " :: " ++ constraints name (rights args)
        ++ sepBy "" ((++ " -> ") . either (srcType . snd) argumentName) args
        ++ opName ++ "\n"
        ++ name ++ space ++ sepBy space (argumentName . either fst id) args
        ++ " = " ++ opName ++ space ++ show opCode
        ++ " [" ++ sepBy comma (encoding name) args ++ "]"


constraints :: String -> [Int] -> String
constraints _ []             = ""
constraints baseName indexes = "(" ++ sepBy comma class_ indexes ++ ") => "
  where
    class_ i = className i baseName ++ space ++ argumentName i


encoding :: String -> Either (Int, Type) Int -> String
encoding _ (Left (i, type_)) = encoderName type_ ++ space ++ argumentName i
encoding baseName (Right i)  = methodName i baseName ++ space ++ argumentName i


srcType :: Type -> String
srcType Import        = "Import"
srcType Atom          = "ByteString"
srcType XRegister     = "X"
srcType YRegister     = "Y"
srcType FloatRegister = "F"
srcType Literal       = "Literal"
srcType Label         = "Label"
srcType Untagged      = "Int"


indent :: String
indent =
  replicate 8 ' '


space :: String
space =
  " "


comma :: String
comma =
  ", "


sepBy :: String -> (a -> String) -> [a] -> String
sepBy separator transform =
  intercalate separator . map transform



-- NAMES


className :: Int -> String -> String
className index beamName =
  "T" ++ show index ++ "__" ++ beamName


argumentName :: Int -> String
argumentName index =
  "a" ++ show index


methodName :: Int -> String -> String
methodName index beamName =
  "fromT" ++ show index ++ "__" ++ beamName


encoderName :: Type -> String
encoderName type_ =
  "From" ++ srcType type_


encodingName :: String
encodingName =
 "Encoding"


opName :: String
opName =
  "Op"
