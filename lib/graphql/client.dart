import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter/foundation.dart';

final HttpLink httpLink = HttpLink(
    //Aca apunta a local
    //'http://10.0.2.2:4000/api/graphql',
  'https://project-prueba-backend.onrender.com/api/graphql',
    defaultHeaders: {
    'Accept-Encoding': 'identity',
  },
);

final ValueNotifier<GraphQLClient> graphqlClient = ValueNotifier(
  GraphQLClient(
    link: httpLink,
    cache: GraphQLCache(),
  ),
);