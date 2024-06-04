import 'package:flutter/material.dart';

AppBar appBar() {
  return AppBar(
    elevation: 4.0,
    shadowColor: Colors.grey,
    title: const Center(
      child: Text(
        'OpenAir',
        textAlign: TextAlign.center,
      ),
    ),
    actions: [
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: IconButton(
          onPressed: () {},
          icon: const Icon(Icons.search),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 8.0, 0),
        child: IconButton(
          onPressed: () {},
          icon: const Icon(Icons.person),
        ),
      ),
    ],
  );
}
