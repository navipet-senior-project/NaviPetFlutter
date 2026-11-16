# Rewrites TypeBox-style unions that openapi-generator's dart target cannot
# model, so every generated file compiles:
#   anyOf: [{type: string, enum: [a]}, {type: string, enum: [b]}]
#     -> {type: string, enum: [a, b]}
#   anyOf: [X, {enum: [null], nullable: true}]
#     -> X + {nullable: true}
def string_enum_member:
  type == "object" and .type == "string" and has("enum")
  and ((keys - ["type", "enum"]) | length == 0);

def merge_string_enums:
  if type == "object" and (.anyOf? | type == "array") and (.anyOf | length > 0)
     and (.anyOf | all(string_enum_member))
  then (del(.anyOf) + {type: "string",
         enum: (reduce (.anyOf[].enum[]) as $v ([];
                  if any(.[]; . == $v) then . else . + [$v] end))})
  else . end;

def null_member: type == "object" and .enum == [null];

def collapse_nullable:
  if type == "object" and (.anyOf? | type == "array") and (.anyOf | length == 2)
     and (.anyOf | any(null_member))
  then ((.anyOf | map(select(null_member | not))[0]) + del(.anyOf) + {nullable: true})
  else . end;

# OpenAPI 3.0 requires one items schema. TypeBox emits homogeneous coordinate
# tuples; preserve their fixed length while using the shared number schema.
def collapse_homogeneous_tuple:
  if type == "object" and .type? == "array"
     and (.items? | type == "array") and (.items | length > 0)
     and (.items | .[0] as $first | all(. == $first))
  then (.items | length) as $count
    | (if .additionalItems? == false then .maxItems = $count else . end)
    | .items = .items[0] | del(.additionalItems)
  else . end;

walk(merge_string_enums | collapse_nullable | collapse_homogeneous_tuple)
