import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'database_provider.dart';

final productsProvider = FutureProvider<List<Product>>((ref) async {
  final database = ref.watch(databaseProvider);

  return database.getAllProducts();
});