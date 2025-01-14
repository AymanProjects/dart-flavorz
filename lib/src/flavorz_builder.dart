import 'dart:convert';
import 'package:build/build.dart';

/// Input file must end with .json
const inputExtension = ".flavorz.json";

/// Output file must end with .dart
const outputExtension = ".flavorz.dart";

/// The key of the list of environments(flavors) inside the json file
const environmentsJsonKey = "environments";

/// This is the key from the .flavorz.json file that specify which environment is the default
const defaultEnvironmentJsonKey = "default";

/// The `FlavorBuilder` is a code gerenator that will look for files
/// that end with [inputExtension] inside the lib folder, and consturct a new dart file that will
/// contain `Environment` class, that will be used across the app.
///
/// The generated file will have the same name & path of the input file but with this extension: [outputExtension].
///
/// For more info. refer to the README.md file
class FlavorBuilder implements Builder {
  /// Specify the input & output file extensions
  @override
  final buildExtensions = const {
    inputExtension: [outputExtension]
  };

  /// This build function will be called for each file that ends with [inputExtension].
  /// In our case, there should be only one file.
  @override
  Future<void> build(BuildStep buildStep) async {
    /// Store the input file path
    final inputFileId = buildStep.inputId;

    final inputContent = await buildStep.readAsString(inputFileId);

    /// Generate the `Environment` class
    final outputContent = generateEnvironmentClass(inputContent);

    final outputFileId = createOutputFileId(inputFileId);

    /// Finally, create & write to the output file
    await buildStep.writeAsString(outputFileId, outputContent);
  }

  /// The output file will have the same path & name of the input file
  /// but with [outputExtension] instead of [inputExtension].
  AssetId createOutputFileId(AssetId inputFileId) {
    final outputFileId = inputFileId.changeExtension('.dart');
    return outputFileId;
  }

  /// This will gerenate the Environment class based on the attributes inside the json file
  String generateEnvironmentClass(String inputContent) {
    /// Since all elements in the `flavors` list are identical in terms of structure,
    /// we will just grab the first element to generate the `Environment` class from it.
    final flavors = jsonDecode(inputContent)[environmentsJsonKey] as List;

    return '''
/// Auto Generated. Do Not Edit ⚠️
///
/// For more info. refer to the README.md file https://pub.dev/packages/flavorz
///

/// This is the key of the list of environments(flavors) inside the .flavorz.json file
const environmentsJsonKey = '$environmentsJsonKey';

/// This is the key from the .flavorz.json file that specify which environment is the default
const defaultEnvironmentJsonKey = '$defaultEnvironmentJsonKey';

/// This will holds the name of the environment that we want to run,
/// using `flutter run --dart-define="env=dev"`.
/// if we run without specifying the env variable, then the default value inside json file will be used.
const environmentToRun = String.fromEnvironment('env');

class Environment {
${generateAttributes(flavors)}
  ${generatePrivateConstructor(flavors)}

  /// `type` is an `enum`, to be used for comparison, instead of hardcoding the name
  EnvironmentType get type => EnvironmentType.fromString(_name);

  static Environment? _this;

  /// This factory is an access point from anywhere in the application.
  /// And it will always return the same instance, since it is a singleton.
  factory Environment() {
    _this ??= _init();
    return _this!;
  }

  /// This will initialize the environment based on the [environmentToRun]
  static Environment _init() {
    final content = jsonConfigFileContent;
    List<Environment> environments = _loadAllEnvironments(content);
    String envToRun = environmentToRun;

    if (envToRun.isEmpty) {
      if (content.keys.contains(defaultEnvironmentJsonKey)) {
        final defaultEnvironment = content[defaultEnvironmentJsonKey] as String;
        envToRun = defaultEnvironment;
      } else {
        throw Exception(
            'The \$defaultEnvironmentJsonKey key is not defined inside the .flavorz.json file, make sure to include it and regenerate the code again');
      }
    }

    final matchedEnvironments = environments
        .where((env) => env._name.toLowerCase() == envToRun.toLowerCase());
    if (matchedEnvironments.isNotEmpty) {
      return matchedEnvironments.first;
    } else {
      throw Exception(
          'The environment \$envToRun does not exist in .flavorz.json file, make sure to include it and regenerate the code again');
    }
  }

  static List<Environment> _loadAllEnvironments(Map<String, dynamic> json) {
    /// if the [environmentsJsonKey] is not found inside the .flavorz.json file
    if (!json.keys.contains(environmentsJsonKey)) {
      throw Exception(
          'The \$environmentsJsonKey key is not defined inside the .flavorz.json file');
    }
    final environments = json[environmentsJsonKey] as List;
    return environments
        .map((map) => Environment._fromMap(map as Map<String, dynamic>))
        .toList();
  }

  ${generateFromMapFuntion(flavors)}

  ${generateToString(flavors)}
}

${generateEnumTypes(flavors)}

/// This is the content of the .flavorz.json file
const jsonConfigFileContent = $inputContent;
''';
  }

  /// Will go over all the attributes in the json file and make the same attributes in the Environment class
  String generateAttributes(List flavors) {
    String attributes = '';
    final entries = _getAllPossibleAttributes(flavors);
    for (var entry in entries) {
      if (entry.key == "_name") {
        attributes += '  final ${entry.value.runtimeType} ${entry.key};\n';
      } else {
        attributes += '  final ${entry.value.runtimeType}? ${entry.key};\n';
      }
    }
    return attributes;
  }

  /// Will generate a private constructor based on the attributes in the json file
  String generatePrivateConstructor(List flavors) {
    String attributes = "";
    final entries = _getAllPossibleAttributes(flavors);
    for (int i = 0; i < entries.length; i++) {
      attributes += '    this.${entries[i].key},';
      if (i != entries.length - 1) {
        attributes += '\n';
      }
    }
    return '''
Environment._(
$attributes
  );''';
  }

  /// Will generate the `fromMap` function to prase json into object of type `Environment`
  String generateFromMapFuntion(List flavors) {
    String attributes = '';
    final entries = _getAllPossibleAttributes(flavors);
    for (int i = 0; i < entries.length; i++) {
      if (entries[i].key == "_name") {
        attributes +=
            '      map["${entries[i].key}"] as ${entries[i].value.runtimeType},';
      } else {
        attributes +=
            '      map["${entries[i].key}"] as ${entries[i].value.runtimeType}?,';
      }
      if (i != entries.length - 1) {
        attributes += '\n';
      }
    }
    return '''
factory Environment._fromMap(Map<String, dynamic> map) {
    return Environment._(
$attributes
    );
  }''';
  }

  /// Will generate enum types for each environment in the json file.
  /// The name of each type is matched to the `_name` attribute inside the json file.
  String generateEnumTypes(List flavors) {
    String types = "";
    for (int i = 0; i < flavors.length; i++) {
      final flavor = flavors[i] as Map<String, dynamic>;
      final nameAttribute = flavor['_name'] as String;
      types += '  $nameAttribute';
      if (i != flavors.length - 1) {
        types += ',\n';
      } else {
        types += ';';
      }
    }
    return '''
enum EnvironmentType {
$types

  factory EnvironmentType.fromString(String name) {
    return values.firstWhere((EnvironmentType e) => e.name == name);
  }
}''';
  }

  String generateToString(List flavors) {
    String attributes = '';
    final entries = _getAllPossibleAttributes(flavors);
    for (var entry in entries) {
      attributes += '"${entry.key}": \$${entry.key}';
      if (entry.key != entries.last.key) {
        attributes += ', ';
      }
    }
    return '''
@override
  String toString() {
    return '{$attributes}';
  }''';
  }

  /// We will try to get all the attributes defined in the json file,
  /// even if the flavors did not have similar attributes.
  ///
  /// Given
  ///  [
  //     {
  //       "_name": "dev",
  //       "date": "10/30"
  //     },
  //     {
  //       "_name": "local",
  //       "versionNumber": "Local 1.0.1"
  //     }
  //   ]
  ///
  /// Will result into
  /// [
  ///    "_name": "local",
  ///    "date": "10/30",
  ///    "versionNumber": "Local 1.0.1"
  /// ]
  ///
  List<MapEntry> _getAllPossibleAttributes(List flavors) {
    final attributes = <MapEntry>[];
    for (var flavor in flavors) {
      for (var currentEntry in flavor.entries) {
        if (attributes
            .where((entry) => entry.key == currentEntry.key)
            .isEmpty) {
          attributes.add(currentEntry);
        }
      }
    }
    return attributes;
  }
}
