import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import 'providers/database_provider.dart';
import 'providers/product_provider.dart';
import 'providers/backend_product_provider.dart';

import 'package:graphql_flutter/graphql_flutter.dart';
import 'graphql/client.dart';

final router = GoRouter(
  routes: [
    // Ruta 1: Inventario
    GoRoute(
      path: '/',
      builder: (context, state) => const InventoryPage(),
    ),

    // Ruta 2: Nuevo producto
    GoRoute(
      path: '/products/new',
      builder: (context, state) => const NewProductPage(),
    ),

    // Ruta 3: Editar producto
    GoRoute(
      path: '/products/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;

        return ProductDetailPage(productId: id);
      },
    ),
  ],
);


class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final backendProductsAsync = ref.watch(backendProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Prueba'),
      ),

      body: Column(
        children: [

          backendProductsAsync.when(
            loading: () => const LinearProgressIndicator(),

            error: (error, stack) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Backend: $error',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            data: (products) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Backend: ${products.length} productos',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),


          Expanded(
            child: productsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),

              error: (error, stack) => Center(
                child: Text(
                  'Error: $error',
                ),
              ),

              data: (products) {
                if (products.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay productos todavía',
                      style: TextStyle(
                        fontSize: 20,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,

                  itemBuilder: (context, index) {
                    final product = products[index];


                    return Slidable(
                      key: ValueKey(product.id),

                      endActionPane: ActionPane(
                        motion: const ScrollMotion(),
                        extentRatio: 0.50,

                        children: [

                          SlidableAction(
                            onPressed: (context) {
                              context.push(
                                '/products/${product.id}',
                              );
                            },
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            icon: Icons.edit,
                            borderRadius: BorderRadius.circular(16),
                          ),


                          SlidableAction(
                            onPressed: (context) {
                              _showDeleteDialog(
                                context,
                                ref,
                                product.id,
                                product.name,
                              );
                            },
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            icon: Icons.delete,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ],
                      ),


                      child: Card(
                        child: ListTile(
                          title: Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          subtitle: Text(
                            'SKU: ${product.sku}\n'
                            'Stock: ${product.stock} | '
                            'Precio: S/ '
                            '${product.price.toStringAsFixed(2)}',
                          ),

                          isThreeLine: true,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),


      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/products/new');
        },
        child: const Icon(Icons.add),
      ),
    );
  }


  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    int productId,
    String productName,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Eliminar producto',
          ),
          content: Text(
            '¿Seguro que deseas eliminar "$productName"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Cancelar',
              ),
            ),

            FilledButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                try {
                  final database = ref.read(databaseProvider);

                  await database.deleteProduct(productId);

                  ref.invalidate(productsProvider);

                  if (!context.mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '"$productName" eliminado correctamente',
                      ),
                    ),
                  );
                } catch (error) {
                  if (!context.mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error al eliminar: $error',
                      ),
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text(
                'Eliminar',
              ),
            ),
          ],
        );
      },
    );
  }
}


class NewProductPage extends ConsumerStatefulWidget {
  const NewProductPage({super.key});

  @override
  ConsumerState<NewProductPage> createState() =>
      _NewProductPageState();
}

class _NewProductPageState extends ConsumerState<NewProductPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _stockController = TextEditingController();
  final _priceController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _stockController.dispose();
    _priceController.dispose();

    super.dispose();
  }

  // GUARDAR NUEVO PRODUCTO

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

  try {
    const mutation = r'''
      mutation CreateProduct(
        $name: String!,
        $sku: String!,
        $stock: Int!,
        $price: Float!
      ) {
        createProduct(
          name: $name,
          sku: $sku,
          stock: $stock,
          price: $price
        ) {
          id
          name
          sku
          stock
          price
        }
      }
    ''';

    final result = await graphqlClient.value.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {
          'name': _nameController.text.trim(),
          'sku': _skuController.text.trim(),
          'stock': int.parse(_stockController.text),
          'price': double.parse(_priceController.text),
        },
      ),
    );

    if (result.hasException) {
      throw result.exception!;
    }

    final database = ref.read(databaseProvider);

    await database.insertProduct(
      name: _nameController.text.trim(),
      sku: _skuController.text.trim(),
      stock: int.parse(_stockController.text),
      price: double.parse(_priceController.text),
    );

    ref.invalidate(productsProvider);
    ref.invalidate(backendProductsProvider);

    if (mounted) {
      context.pop();
    }
  } catch (error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $error'),
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nuevo producto',
        ),
      ),

      body: Form(
        key: _formKey,

        child: ListView(
          padding: const EdgeInsets.all(16),

          children: [

            TextFormField(
              controller: _nameController,

              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),

              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Ingresa el nombre';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),


            TextFormField(
              controller: _skuController,

              decoration: const InputDecoration(
                labelText: 'SKU',
                border: OutlineInputBorder(),
              ),

              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Ingresa el SKU';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),


            TextFormField(
              controller: _stockController,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(
                labelText: 'Stock',
                border: OutlineInputBorder(),
              ),

              validator: (value) {
                if (value == null ||
                    int.tryParse(value) == null) {
                  return 'Ingresa un número válido';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),


            TextFormField(
              controller: _priceController,

              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),

              decoration: const InputDecoration(
                labelText: 'Precio',
                border: OutlineInputBorder(),
              ),

              validator: (value) {
                if (value == null ||
                    double.tryParse(value) == null) {
                  return 'Ingresa un precio válido';
                }

                return null;
              },
            ),

            const SizedBox(height: 24),


            FilledButton.icon(
              onPressed:
                  _isSaving ? null : _saveProduct,

              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,

                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.save,
                    ),

              label: Text(
                _isSaving
                    ? 'Guardando...'
                    : 'Guardar producto',
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class ProductDetailPage extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailPage({
    super.key,
    required this.productId,
  });

  @override
  ConsumerState<ProductDetailPage> createState() =>
      _ProductDetailPageState();
}

class _ProductDetailPageState
    extends ConsumerState<ProductDetailPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _stockController = TextEditingController();
  final _priceController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  // CARGAR PRODUCTO

  @override
  void initState() {
    super.initState();

    _loadProduct();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _stockController.dispose();
    _priceController.dispose();

    super.dispose();
  }

  Future<void> _loadProduct() async {
    final database = ref.read(databaseProvider);

    final id = int.tryParse(widget.productId);

    if (id == null) {
      setState(() {
        _loading = false;
      });

      return;
    }

    final product = await database.getProductById(id);

    if (!mounted) {
      return;
    }

    if (product != null) {
      _nameController.text = product.name;
      _skuController.text = product.sku;
      _stockController.text = product.stock.toString();
      _priceController.text = product.price.toString();
    }

    setState(() {
      _loading = false;
    });
  }

  // ACTUALIZAR PRODUCTO

  Future<void> _updateProduct() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    _saving = true;
  });

  try {
    const mutation = r'''
    mutation UpdateProduct($sku: String!, $stock: Int!) {
    updateProduct(sku: $sku, stock: $stock) {
      id
      name
      stock
      price
      }
    }
  ''';

  final result = await graphqlClient.value.mutate(
    MutationOptions(
    document: gql(mutation),
    variables: {
      'sku': _skuController.text.trim(),
      'stock': int.parse(_stockController.text),
      },
    ),
  );

    if (result.hasException) {
      throw result.exception!;
    }

    // Mantener también actualizado el CRUD local.
    final database = ref.read(databaseProvider);

    await database.updateProduct(
      id: int.parse(widget.productId),
      name: _nameController.text.trim(),
      sku: _skuController.text.trim(),
      stock: int.parse(_stockController.text),
      price: double.parse(_priceController.text),
    );

    ref.invalidate(productsProvider);
    ref.invalidate(backendProductsProvider);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Producto actualizado correctamente',
        ),
      ),
    );

    context.pop();
  } catch (error) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Error al actualizar: $error',
        ),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _saving = false;
      });
    }
  }
  }


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Editar producto',
        ),
      ),

      body: Form(
        key: _formKey,

        child: ListView(
          padding: const EdgeInsets.all(16),

          children: [

            TextFormField(
              controller: _nameController,

              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),

              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Ingresa el nombre';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),


            TextFormField(
              controller: _skuController,

              decoration: const InputDecoration(
                labelText: 'SKU',
                border: OutlineInputBorder(),
              ),

              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Ingresa el SKU';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),


            TextFormField(
              controller: _stockController,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(
                labelText: 'Stock',
                border: OutlineInputBorder(),
              ),

              validator: (value) {
                if (value == null ||
                    int.tryParse(value) == null) {
                  return 'Ingresa un número válido';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),


            TextFormField(
              controller: _priceController,

              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),

              decoration: const InputDecoration(
                labelText: 'Precio',
                border: OutlineInputBorder(),
              ),

              validator: (value) {
                if (value == null ||
                    double.tryParse(value) == null) {
                  return 'Ingresa un precio válido';
                }

                return null;
              },
            ),

            const SizedBox(height: 24),


            FilledButton.icon(
              onPressed:
                  _saving ? null : _updateProduct,

              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,

                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.save,
                    ),

              label: Text(
                _saving
                    ? 'Guardando cambios...'
                    : 'Guardar cambios',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
