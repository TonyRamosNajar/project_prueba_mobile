import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get sku => text()();

  IntColumn get stock => integer()();

  RealColumn get price => real()();
}

@DriftDatabase(tables: [Products])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<List<Product>> getAllProducts() {
    return select(products).get();
  }

  Future<int> insertProduct({
    required String name,
    required String sku,
    required int stock,
    required double price,
  }) {
    return into(products).insert(
      ProductsCompanion.insert(
        name: name,
        sku: sku,
        stock: stock,
        price: price,
      ),
    );
  }

  Future<Product?> getProductById(int id) {
    return (select(products)
          ..where((product) => product.id.equals(id)))
        .getSingleOrNull();
  }

  Future<bool> updateProduct({
    required int id,
    required String name,
    required String sku,
    required int stock,
    required double price,
  }) {
    return update(products).replace(
      ProductsCompanion(
        id: Value(id),
        name: Value(name),
        sku: Value(sku),
        stock: Value(stock),
        price: Value(price),
      ),
    );
  }

  Future<int> deleteProduct(int id) {
  return (delete(products)
        ..where((product) => product.id.equals(id)))
      .go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();

    final file = File(
      p.join(
        directory.path,
        'project_prueba.sqlite',
      ),
    );

    return NativeDatabase.createInBackground(file);
  });
}