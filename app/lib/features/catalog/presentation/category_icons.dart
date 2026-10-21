import 'package:flutter/material.dart';

/// Maps `Category.iconKey` to a Material icon.
IconData iconForCategoryKey(String key) => switch (key) {
  'pasta' => Icons.ramen_dining_rounded,
  'salad' => Icons.eco_rounded,
  'soup' => Icons.soup_kitchen_rounded,
  'hungarian' => Icons.dinner_dining_rounded,
  'sandwich' => Icons.lunch_dining_rounded,
  'dessert' => Icons.cake_rounded,
  'drink' => Icons.local_drink_rounded,
  _ => Icons.restaurant_rounded,
};
