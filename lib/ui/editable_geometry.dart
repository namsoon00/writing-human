import 'package:flutter/rendering.dart';

RenderEditable? findEditable(RenderObject? root) {
  if (root is RenderEditable) return root;
  RenderEditable? found;
  root?.visitChildren((child) => found ??= findEditable(child));
  return found;
}
