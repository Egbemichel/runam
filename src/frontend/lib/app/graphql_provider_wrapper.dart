import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../services/graphql_client.dart';

class GraphQLProviderWrapper extends StatelessWidget {
  final Widget child;
  const GraphQLProviderWrapper({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return GraphQLProvider(
      client: ValueNotifier(GraphQLClientInstance.client),
      child: child,
    );
  }
}

