import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';

final backendProductsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    const query = r'''
      query {
        products {
          id
          name
          sku
          stock
          price
        }
      }
    ''';

    final result = await graphqlClient.value.query(
      QueryOptions(document: gql(query)),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    final data = result.data?['products'] as List<dynamic>? ?? [];

    return data.cast<Map<String, dynamic>>();
  },
);