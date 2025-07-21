import "package:flutter/material.dart";
import "widgets/world_fog_app.dart";

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const WorldFogApp();
  }
}
