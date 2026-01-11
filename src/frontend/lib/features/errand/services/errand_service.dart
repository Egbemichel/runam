import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_storage/get_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../services/graphql_client.dart';
import '../models/errand.dart';
import '../models/errand_draft.dart';

class ErrandService {
  final _storage = GetStorage();

  /// Creates an errand with optional image upload
  /// Image is uploaded separately and the URL is included in the errand data
  Future<void> createErrand(ErrandDraft draft, {File? image}) async {
    final GraphQLClient client = GraphQLClientInstance.client;

    // If there's an image, upload it first and get the URL
    String? imageUrl;
    if (image != null) {
      imageUrl = await uploadImage(image);
    }

    const mutation = r'''
    mutation CreateErrand($input: CreateErrandInput!) {
      createErrand(input: $input) {
        errandId
      }
    }
    ''';

    // Add image URL to the draft payload
    final payload = draft.toJson();
    if (imageUrl != null) {
      payload['imageUrl'] = imageUrl;
    }

    final result = await client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {
          "input": payload,
        },
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }
  }

  /// Fetch all errands for the current user
  Future<List<Errand>> fetchMyErrands() async {
    final GraphQLClient client = GraphQLClientInstance.client;

    const query = r'''
    query MyErrands {
      myErrands {
        id
        type
        instructions
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
        instructions
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

  /// Uploads an image to the backend
  /// Backend handles storage (local file in dev, Supabase in prod)
  /// Returns the image URL/path
  Future<String> uploadImage(File image) async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';
    final uploadUrl = Uri.parse('$baseUrl/api/upload/image/');

    // Create multipart request
    final request = http.MultipartRequest('POST', uploadUrl);

    // Get file extension for content type
    final fileName = image.path.split('/').last;
    final extension = fileName.split('.').last.toLowerCase();
    final contentType = _getContentType(extension);

    // Add the file
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        image.path,
        contentType: contentType,
        filename: fileName,
      ),
    );

    // Add auth header if available
    final token = _storage.read<String>('accessToken');
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'JWT $token';
    }

    // Send request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to upload image: ${response.body}');
    }

    // Parse response to get image URL
    final responseData = jsonDecode(response.body);
    return responseData['url'] ?? responseData['image_url'] ?? responseData['path'];
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
