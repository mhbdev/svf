import 'dart:convert';
import '../errors/svf_exception.dart';

/// The primitive or compound data type of a schema definition.
enum SvfSchemaType {
  string('string'),
  number('number'),
  integer('integer'),
  boolean('boolean'),
  array('array'),
  object('object');

  final String value;
  const SvfSchemaType(this.value);
}

/// Declarative schema builder for structured outputs, parameter validation,
/// and AI grammar constraints (inspired by JSON Schema & Zod).
abstract class SvfSchema {
  /// The schema data type.
  final SvfSchemaType type;

  /// Optional documentation explaining the expected meaning of the field.
  final String? description;

  /// Whether null is permitted.
  final bool isNullable;

  const SvfSchema({
    required this.type,
    this.description,
    this.isNullable = false,
  });

  /// Creates a string schema.
  static SvfStringSchema string({
    String? description,
    List<String>? enumeration,
    String? pattern,
    int? minLength,
    int? maxLength,
    bool isNullable = false,
  }) => SvfStringSchema(
    description: description,
    enumeration: enumeration,
    pattern: pattern,
    minLength: minLength,
    maxLength: maxLength,
    isNullable: isNullable,
  );

  /// Creates a floating-point number schema.
  static SvfNumberSchema number({
    String? description,
    num? minimum,
    num? maximum,
    bool isNullable = false,
  }) => SvfNumberSchema(
    description: description,
    minimum: minimum,
    maximum: maximum,
    isNullable: isNullable,
  );

  /// Creates an integer number schema.
  static SvfIntegerSchema integer({
    String? description,
    int? minimum,
    int? maximum,
    bool isNullable = false,
  }) => SvfIntegerSchema(
    description: description,
    minimum: minimum,
    maximum: maximum,
    isNullable: isNullable,
  );

  /// Creates a boolean true/false schema.
  static SvfBooleanSchema boolean({
    String? description,
    bool isNullable = false,
  }) => SvfBooleanSchema(description: description, isNullable: isNullable);

  /// Creates an enum string schema with restricted allowed values.
  static SvfStringSchema enumeration(
    List<String> values, {
    String? description,
    bool isNullable = false,
  }) => SvfStringSchema(
    description: description,
    enumeration: values,
    isNullable: isNullable,
  );

  /// Creates an array/list schema with a defined item element schema.
  static SvfArraySchema array({
    required SvfSchema items,
    String? description,
    int? minItems,
    int? maxItems,
    bool isNullable = false,
  }) => SvfArraySchema(
    items: items,
    description: description,
    minItems: minItems,
    maxItems: maxItems,
    isNullable: isNullable,
  );

  /// Creates a compound key-value object schema.
  static SvfObjectSchema object({
    required Map<String, SvfSchema> properties,
    List<String>? required,
    String? description,
    bool additionalProperties = false,
    bool isNullable = false,
  }) => SvfObjectSchema(
    properties: properties,
    required: required,
    description: description,
    additionalProperties: additionalProperties,
    isNullable: isNullable,
  );

  /// Generates standard JSON Schema representation.
  Map<String, dynamic> toJsonSchema({bool strict = true});

  /// Validates an untyped JSON-compatible value against this schema. Returns
  /// an empty list when the value is valid.
  List<String> validate(Object? value);

  /// Returns true if [value] complies with the schema.
  bool isValid(Object? value) => validate(value).isEmpty;

  /// Asserts validity of [value], throwing [SvfSchemaValidationException] on failure.
  void assertValid(Object? value) {
    final errors = validate(value);
    if (errors.isNotEmpty) {
      throw SvfSchemaValidationException(
        'Schema validation failed: ${errors.join(', ')}',
        rawOutput: value is Map<String, dynamic> ? value : null,
        validationErrors: errors,
      );
    }
  }
}

/// String schema implementation.
class SvfStringSchema extends SvfSchema {
  final List<String>? enumeration;
  final String? pattern;
  final int? minLength;
  final int? maxLength;

  const SvfStringSchema({
    super.description,
    this.enumeration,
    this.pattern,
    this.minLength,
    this.maxLength,
    super.isNullable,
  }) : super(type: SvfSchemaType.string);

  @override
  Map<String, dynamic> toJsonSchema({bool strict = true}) {
    final map = <String, dynamic>{
      'type': isNullable ? ['string', 'null'] : 'string',
    };
    if (description != null) map['description'] = description;
    if (enumeration != null) map['enum'] = enumeration;
    if (pattern != null) map['pattern'] = pattern;
    if (minLength != null) map['minLength'] = minLength;
    if (maxLength != null) map['maxLength'] = maxLength;
    return map;
  }

  @override
  List<String> validate(Object? value) {
    if (value == null) {
      return isNullable ? [] : ['Value cannot be null'];
    }
    if (value is! String) {
      return ['Expected String, received ${value.runtimeType}'];
    }
    final errors = <String>[];
    if (enumeration != null && !enumeration!.contains(value)) {
      errors.add(
        'Value "$value" not in allowed enum: ${enumeration!.join(', ')}',
      );
    }
    if (minLength != null && value.length < minLength!) {
      errors.add(
        'String length ${value.length} is less than minLength $minLength',
      );
    }
    if (maxLength != null && value.length > maxLength!) {
      errors.add(
        'String length ${value.length} is greater than maxLength $maxLength',
      );
    }
    if (pattern != null && !RegExp(pattern!).hasMatch(value)) {
      errors.add('String does not match pattern "$pattern"');
    }
    return errors;
  }
}

/// Number (double/float/int) schema implementation.
class SvfNumberSchema extends SvfSchema {
  final num? minimum;
  final num? maximum;

  const SvfNumberSchema({
    super.description,
    this.minimum,
    this.maximum,
    super.isNullable,
  }) : super(type: SvfSchemaType.number);

  @override
  Map<String, dynamic> toJsonSchema({bool strict = true}) {
    final map = <String, dynamic>{
      'type': isNullable ? ['number', 'null'] : 'number',
    };
    if (description != null) map['description'] = description;
    if (minimum != null) map['minimum'] = minimum;
    if (maximum != null) map['maximum'] = maximum;
    return map;
  }

  @override
  List<String> validate(Object? value) {
    if (value == null) {
      return isNullable ? [] : ['Value cannot be null'];
    }
    if (value is! num) {
      return ['Expected Number, received ${value.runtimeType}'];
    }
    final errors = <String>[];
    if (minimum != null && value < minimum!) {
      errors.add('Value $value is less than minimum $minimum');
    }
    if (maximum != null && value > maximum!) {
      errors.add('Value $value is greater than maximum $maximum');
    }
    return errors;
  }
}

/// Integer schema implementation.
class SvfIntegerSchema extends SvfSchema {
  final int? minimum;
  final int? maximum;

  const SvfIntegerSchema({
    super.description,
    this.minimum,
    this.maximum,
    super.isNullable,
  }) : super(type: SvfSchemaType.integer);

  @override
  Map<String, dynamic> toJsonSchema({bool strict = true}) {
    final map = <String, dynamic>{
      'type': isNullable ? ['integer', 'null'] : 'integer',
    };
    if (description != null) map['description'] = description;
    if (minimum != null) map['minimum'] = minimum;
    if (maximum != null) map['maximum'] = maximum;
    return map;
  }

  @override
  List<String> validate(Object? value) {
    if (value == null) {
      return isNullable ? [] : ['Value cannot be null'];
    }
    if (value is! int) {
      return ['Expected Integer, received ${value.runtimeType}'];
    }
    final errors = <String>[];
    if (minimum != null && value < minimum!) {
      errors.add('Value $value is less than minimum $minimum');
    }
    if (maximum != null && value > maximum!) {
      errors.add('Value $value is greater than maximum $maximum');
    }
    return errors;
  }
}

/// Boolean schema implementation.
class SvfBooleanSchema extends SvfSchema {
  const SvfBooleanSchema({super.description, super.isNullable})
    : super(type: SvfSchemaType.boolean);

  @override
  Map<String, dynamic> toJsonSchema({bool strict = true}) {
    final map = <String, dynamic>{
      'type': isNullable ? ['boolean', 'null'] : 'boolean',
    };
    if (description != null) map['description'] = description;
    return map;
  }

  @override
  List<String> validate(Object? value) {
    if (value == null) {
      return isNullable ? [] : ['Value cannot be null'];
    }
    if (value is! bool) {
      return ['Expected Boolean, received ${value.runtimeType}'];
    }
    return [];
  }
}

/// Array/List schema implementation.
class SvfArraySchema extends SvfSchema {
  final SvfSchema items;
  final int? minItems;
  final int? maxItems;

  const SvfArraySchema({
    required this.items,
    super.description,
    this.minItems,
    this.maxItems,
    super.isNullable,
  }) : super(type: SvfSchemaType.array);

  @override
  Map<String, dynamic> toJsonSchema({bool strict = true}) {
    final map = <String, dynamic>{
      'type': isNullable ? ['array', 'null'] : 'array',
      'items': items.toJsonSchema(strict: strict),
    };
    if (description != null) map['description'] = description;
    if (minItems != null) map['minItems'] = minItems;
    if (maxItems != null) map['maxItems'] = maxItems;
    return map;
  }

  @override
  List<String> validate(Object? value) {
    if (value == null) {
      return isNullable ? [] : ['Value cannot be null'];
    }
    if (value is! List) {
      return ['Expected List, received ${value.runtimeType}'];
    }
    final errors = <String>[];
    if (minItems != null && value.length < minItems!) {
      errors.add(
        'Array length ${value.length} is less than minItems $minItems',
      );
    }
    if (maxItems != null && value.length > maxItems!) {
      errors.add(
        'Array length ${value.length} is greater than maxItems $maxItems',
      );
    }
    for (int i = 0; i < value.length; i++) {
      final itemErrors = items.validate(value[i]);
      for (final err in itemErrors) {
        errors.add('Index [$i]: $err');
      }
    }
    return errors;
  }
}

/// Object / Map schema implementation with strict property validation.
class SvfObjectSchema extends SvfSchema {
  final Map<String, SvfSchema> properties;
  final List<String> required;
  final bool additionalProperties;

  SvfObjectSchema({
    required this.properties,
    List<String>? required,
    super.description,
    this.additionalProperties = false,
    super.isNullable,
  }) : required = required ?? properties.keys.toList(),
       super(type: SvfSchemaType.object);

  @override
  Map<String, dynamic> toJsonSchema({bool strict = true}) {
    final propsMap = <String, dynamic>{};
    for (final entry in properties.entries) {
      propsMap[entry.key] = entry.value.toJsonSchema(strict: strict);
    }

    final map = <String, dynamic>{
      'type': isNullable ? ['object', 'null'] : 'object',
      'properties': propsMap,
      'required': required,
      'additionalProperties': additionalProperties,
    };
    if (description != null) map['description'] = description;
    return map;
  }

  @override
  List<String> validate(Object? value) {
    if (value == null) {
      return isNullable ? [] : ['Value cannot be null'];
    }
    if (value is! Map) {
      return ['Expected Map/Object, received ${value.runtimeType}'];
    }
    final errors = <String>[];

    // Check required fields
    for (final req in required) {
      if (!value.containsKey(req) || value[req] == null) {
        final propSchema = properties[req];
        if (propSchema != null &&
            propSchema.isNullable &&
            value.containsKey(req)) {
          // Permitted null
        } else {
          errors.add('Missing required property: "$req"');
        }
      }
    }

    // Check declared properties
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final val = entry.value;

      if (properties.containsKey(key)) {
        final propSchema = properties[key]!;
        final propErrors = propSchema.validate(val);
        for (final err in propErrors) {
          errors.add('Property "$key": $err');
        }
      } else if (!additionalProperties) {
        errors.add('Unknown extra property "$key" not allowed in strict mode');
      }
    }

    return errors;
  }

  /// Helper to convert schema to clean human-readable JSON string.
  String toJsonSchemaString({bool pretty = true, bool strict = true}) {
    final jsonMap = toJsonSchema(strict: strict);
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(jsonMap);
    }
    return jsonEncode(jsonMap);
  }
}
