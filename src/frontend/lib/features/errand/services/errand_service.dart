import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_storage/get_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../services/graphql_client.dart';
import '../models/errand.dart';
import '../models/errand_draft.dart';

class ErrandService {
  static const String _tag = '🏃 [ErrandService]';
  final _storage = GetStorage();

  /// Creates an errand with optional image upload
  /// Image is uploaded separately and the URL is included in the errand data
  Future<void> createErrand(ErrandDraft draft, {File? image}) async {
    debugPrint('$_tag === CREATE ERRAND ===');
    debugPrint('$_tag Draft received:');
    debugPrint('$_tag   Type: ${draft.type}');
    debugPrint('$_tag   Tasks: ${draft.tasks}');
    debugPrint('$_tag   Speed: ${draft.speed}');
    debugPrint('$_tag   Payment: ${draft.paymentMethod}');
    debugPrint('$_tag   GoTo: ${draft.goTo?.name} (${draft.goTo?.latitude}, ${draft.goTo?.longitude})');
    debugPrint('$_tag   ReturnTo: ${draft.returnTo?.name}');
    debugPrint('$_tag   Has image: ${image != null}');

    final GraphQLClient client = GraphQLClientInstance.client;

    // Handle image upload using the backend's store_uploaded_file logic
    String? imageUrl;
    if (image != null) {
      debugPrint('$_tag [LOG] Image file provided. Starting image upload process...');
      final imageStopwatch = Stopwatch()..start();
      try {
        // Assuming uploadImage is a function that handles the file upload
        imageUrl = await uploadImage(image);
        imageStopwatch.stop();
        debugPrint('$_tag [LOG] Image uploaded successfully in ${imageStopwatch.elapsedMilliseconds}ms.');
        debugPrint('$_tag [LOG] Image URL received: $imageUrl');
      } catch (e) {
        debugPrint('$_tag [ERROR] Image upload failed: $e');
        // Re-throw the exception to stop the errand creation process
        throw Exception('Image upload failed: $e');
      }
    } else {
      debugPrint('$_tag [LOG] No image file provided. Skipping image upload.');
    }

    const mutation = r'''
      mutation CreateErrand(
        $type: String!
        $tasks: JSONString!
        $speed: String!
        $paymentMethod: String
        $goTo: JSONString!
        $returnTo: JSONString
        $imageUrl: String
      ) {
        createErrand(
          type: $type
          tasks: $tasks
          speed: $speed
          paymentMethod: $paymentMethod
          goTo: $goTo
          returnTo: $returnTo
          imageUrl: $imageUrl
        ) {
            errandId
        }
      }
    ''';

    final variables = {
      "type": draft.type,
      "tasks": jsonEncode(draft.tasks.map((t) => t.toJson()).toList()),
      "speed": draft.speed,
      "paymentMethod": draft.paymentMethod,
      "goTo": jsonEncode(draft.goTo!.toPayload()),
      "returnTo": draft.returnTo != null ? jsonEncode(draft.returnTo!.toPayload()) : null,
      "imageUrl": imageUrl,
    };

    debugPrint('$_tag [LOG] Preparing to send GraphQL mutation with the following variables:');
    debugPrint(jsonEncode(variables)); // Using jsonEncode for clear, structured logging


    final stopwatch = Stopwatch()..start();
    debugPrint('$_tag [LOG] Sending create_errand mutation');
    final result = await client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: variables,
      ),
    );

    stopwatch.stop();
    debugPrint('$_tag [LOG] GraphQL response received in ${stopwatch.elapsedMilliseconds}ms.');

    if (result.hasException) {
      debugPrint('$_tag [ERROR] GraphQL mutation failed. Exception: ${result.exception}');
      throw result.exception!;
    }

    final errandId = result.data?['createErrand']?['errandId'];
    if (errandId != null) {
      debugPrint('$_tag [SUCCESS] Errand created successfully!');
      debugPrint('$_tag [SUCCESS] New Errand ID: $errandId');
    } else {
      debugPrint('$_tag [ERROR] Errand creation succeeded but no errandId was returned in the response.');
      throw Exception('Failed to create errand: No errand ID returned.');
    }
    debugPrint('$_tag === CREATE ERRAND: Execution Finished ===');
  }

  /// Fetch all errands for the current user
  Future<List<Errand>> fetchMyErrands() async {
    final GraphQLClient client = GraphQLClientInstance.client;
    const query = r'''
query MyErrands {
  myErrands {
    id
    type
    speed
    paymentMethod
    imageUrl
    status
    isOpen
    createdAt
    expiresAt
    runnerId
    runnerName
    price
    tasks {
    description
    price
    }
    goTo {
      address
      latitude
      longitude
      mode
    }
    returnTo {
      address
      latitude
      longitude
      mode
    }
  }
}
''';


    final result = await client.query(
      QueryOptions(
        document: gql(query),
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    final List<dynamic> errandsData = result.data?['myErrands'] ?? [];
    return errandsData.map((e) => Errand.fromJson(e)).toList();
  }

  /// Get a single errand by ID
  Future<Errand> getErrandById(String id) async {
    final GraphQLClient client = GraphQLClientInstance.client;

    const query = r'''
    query GetErrand($id: ID!) {
      errand(id: $id) {
        id
        type
        speed
        paymentMethod
        imageUrl
        status
        isOpen
        createdAt
        expiresAt
        runnerId
        runnerName
        price
        tasks {
        description
        price
        }
        goTo {
          name
          address
          lat
          lng
        }
        returnTo {
          name
          address
          lat
          lng
        }
      }
    }
    ''';

    final result = await client.query(
      QueryOptions(
        document: gql(query),
        variables: {'id': id},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    return Errand.fromJson(result.data!['errand']);
  }

  /// Cancel an errand
  Future<void> cancelErrand(String errandId) async {
    final GraphQLClient client = GraphQLClientInstance.client;

    const mutation = r'''
    mutation CancelErrand($errandId: ID!) {
      cancelErrand(errandId: $errandId) {
        success
        message
      }
    }
    ''';

    final result = await client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {'errandId': errandId},
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    final success = result.data?['cancelErrand']?['success'] ?? false;
    if (!success) {
      throw Exception(result.data?['cancelErrand']?['message'] ?? 'Failed to cancel errand');
    }
  }

  /// Uploads an image to the backend using GraphQL multipart upload
  /// Backend handles storage (local file in dev, Supabase in prod)
  /// Returns the image URL/path
  Future<String> uploadImage(File image) async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';
    final graphqlUrl = Uri.parse('$baseUrl/graphql/');

    // Get file info
    final fileName = image.path.split('/').last;
    final extension = fileName.split('.').last.toLowerCase();
    final contentType = _getContentType(extension);

    // Read file bytes
    final bytes = await image.readAsBytes();

    // GraphQL mutation for file upload (multipart using Upload scalar)
    const multipartMutation = r'''
      mutation UploadImage($file: Upload!) {
        uploadImage(file: $file) {
          success
          imageUrl
          message
        }
      }
    ''';

    // Create multipart request following GraphQL multipart spec
    final request = http.MultipartRequest('POST', graphqlUrl);

    // Add operations (the GraphQL query)
    final operations = jsonEncode({
      'query': multipartMutation,
      'variables': {'file': null},
    });
    request.fields['operations'] = operations;

    // Add map (maps the file to the variable)
    request.fields['map'] = jsonEncode({'0': ['variables.file']});

    // Add the file with key '0'
    request.files.add(http.MultipartFile.fromBytes(
      '0',
      bytes,
      filename: fileName,
      contentType: contentType,
    ));

    // Add auth header if available
    final token = _storage.read<String>('accessToken');
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'JWT $token';
    }

    // Send request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      // Try to parse potential GraphQL error body for helpful logging
      String body = response.body;
      debugPrint('$_tag [ERROR] Multipart upload failed with status ${response.statusCode}: $body');
      // Continue to attempt fallback below instead of immediately throwing
    }

    // Parse GraphQL response
    Map<String, dynamic>? responseData;
    try {
      responseData = jsonDecode(response.body) as Map<String, dynamic>?;
    } catch (e) {
      responseData = null;
      debugPrint('$_tag [WARN] Failed to decode multipart response as JSON: $e');
    }

    // If the server responded with GraphQL errors indicating it doesn't support Upload,
    // fall back to sending the file as a base64 string in a plain JSON GraphQL request.
    final List<dynamic>? errors = responseData?['errors'] as List<dynamic>?;
    final bool multipartFailedDueToUploadType = errors != null && errors.any((err) {
      final msg = (err is Map && err['message'] != null) ? err['message'].toString() : err.toString();
      return msg.contains("Unknown type 'Upload'") || msg.contains("Cannot query field 'uploadImage'");
    });

    if (responseData != null && !multipartFailedDueToUploadType) {
      // Handle normal/multipart success or other GraphQL responses
      if (responseData['errors'] != null && (responseData['errors'] as List).isNotEmpty) {
        final errorMessage = responseData['errors'][0]['message'] ?? 'Upload failed';
        throw Exception(errorMessage);
      }

      final uploadResult = responseData['data']?['uploadImage'];
      if (uploadResult == null || uploadResult['success'] != true) {
        throw Exception(uploadResult?['message'] ?? 'Failed to upload image');
      }

      return uploadResult['imageUrl'];
    }

    // Fallback: server doesn't support Upload scalar or the mutation is unavailable.
    // Encode file as base64 and send as a String variable in a GraphQL mutation.
    debugPrint('$_tag [INFO] Falling back to base64 upload because server did not accept Upload scalar or uploadImage mutation.');
    final base64Data = base64Encode(bytes);
    // Some backends expect a data URL with MIME type prefix, some expect raw base64. We'll send raw base64.

    const base64Mutation = r'''
      mutation UploadImageBase64($file: String!, $filename: String) {
        uploadImage(file: $file, filename: $filename) {
          success
          imageUrl
          message
        }
      }
    ''';

    final base64Payload = jsonEncode({
      'query': base64Mutation,
      'variables': {'file': base64Data, 'filename': fileName},
    });

    final headers = {
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'JWT $token';
    }

    final base64Response = await http.post(graphqlUrl, headers: headers, body: base64Payload);

    if (base64Response.statusCode != 200) {
      debugPrint('$_tag [ERROR] Base64 upload failed with status ${base64Response.statusCode}: ${base64Response.body}');
      throw Exception('Failed to upload image: ${base64Response.body}');
    }

    Map<String, dynamic>? base64ResponseData;
    try {
      base64ResponseData = jsonDecode(base64Response.body) as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('$_tag [ERROR] Failed to decode base64 upload response: $e');
      throw Exception('Failed to upload image: ${base64Response.body}');
    }

    // Check for GraphQL errors safely (base64ResponseData may be null)
    if (base64ResponseData != null) {
      final errors = base64ResponseData['errors'] as List<dynamic>?;
      if (errors != null && errors.isNotEmpty) {
        final first = errors.first;
        final msg = (first is Map && first['message'] != null) ? first['message'].toString() : first.toString();
        debugPrint('$_tag [ERROR] Base64 GraphQL errors: $msg');
        throw Exception(msg);
      }

      final uploadResult = base64ResponseData['data']?['uploadImage'];
      if (uploadResult == null || uploadResult['success'] != true) {
        throw Exception(uploadResult?['message'] ?? 'Failed to upload image');
      }

      return uploadResult['imageUrl'];
    }

    // If we couldn't parse a JSON body, fail explicitly
    throw Exception('Failed to upload image: empty response');
  }

  MediaType _getContentType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      default:
        return MediaType('image', 'jpeg');
    }
  }


  Future<Map<String, dynamic>> saveErrandDraft(Map<String, dynamic> draftJson) async {
    final GraphQLClient client = GraphQLClientInstance.client;

    const mutation = r'''
    mutation SaveErrandDraft($input: ErrandDraftInput!) {
      saveErrandDraft(input: $input) {
        id
      }
    }
    ''';

    final result = await client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {
          "input": draftJson,
        },
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    return result.data?["saveErrandDraft"] ?? {};
  }
}
