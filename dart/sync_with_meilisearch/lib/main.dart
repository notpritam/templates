import 'dart:convert';
import 'dart:io';
import 'utils.dart';

import 'package:http/http.dart' as http;
import 'package:meilisearch/meilisearch.dart';
import 'package:dart_appwrite/dart_appwrite.dart';


Future<void> main(final context) async {

  final requiredEnvVars = [
    'APPWRITE_API_KEY',
    'APPWRITE_DATABASE_ID',
    'APPWRITE_COLLECTION_ID',
    'MEILISEARCH_ENDPOINT',
    'MEILISEARCH_INDEX_NAME',
    'MEILISEARCH_ADMIN_API_KEY',
    'MEILISEARCH_SEARCH_API_KEY',
  ];

  throwIfMissing(Platform.environment, requiredEnvVars);
  

    if (context.method == 'GET') {
      final html = interpolate(await getStaticFile('index.html'), {
        'MEILISEARCH_ENDPOINT': Platform.environment['MEILISEARCH_ENDPOINT'] as String,
        'MEILISEARCH_INDEX_NAME': Platform.environment['MEILISEARCH_INDEX_NAME'] as String,
        'MEILISEARCH_SEARCH_API_KEY':
            Platform.environment['MEILISEARCH_SEARCH_API_KEY'] as String,
      });

      context.req.response
        ..headers.contentType = ContentType.html
        ..write(html)
        ..close();
    } else {
      
      final client = Client()
     .setEndpoint('https://cloud.appwrite.io/v1')
     .setProject(Platform.environment['APPWRITE_FUNCTION_PROJECT_ID'])
     .setKey(Platform.environment['APPWRITE_API_KEY']);

      final databases = Databases(client);

      final meilisearch = MeiliSearchClient('http://127.0.0.1:7700', Platform.environment['MEILISEARCH_ADMIN_API_KEY'] as String);

      final index = meilisearch.index(Platform.environment['MEILISEARCH_INDEX_NAME'] as String);

      String? cursor;

      do {
        final queries = [Query.limit(100)];

        if (cursor != null) {
          queries.add(Query.cursorAfter(cursor!));
        }

        final response = await databases.listDocuments(
         databaseId: Platform.environment['APPWRITE_DATABASE_ID'] as String,
         collectionId: Platform.environment['APPWRITE_COLLECTION_ID'] as String,
        queries: queries,
        );

        final documents = response['documents'];

        if (documents.isNotEmpty) {
          cursor = documents[documents.length - 1]['\$id'];
        } else {
          print('No more documents found.');
          cursor = null;
          break;
        }

        print('Syncing chunk of ${documents.length} documents ...');
        await index.addDocuments(documents, primaryKey: '\$id');
      } while (cursor != null);

      print('Sync finished.');

      context.req.response
        ..write('Sync finished.')
        ..close();
    }
  
}

String interpolate(String content, Map<String, String> variables) {
  for (final entry in variables.entries) {
    content = content.replaceAll('{{${entry.key}}}', entry.value);
  }
  return content;
}
