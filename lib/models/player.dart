class Player {
  final String name;
  String symbol;

  Player({
    required this.name,
    this.symbol = '',  // Make symbol optional and default to empty
  });
}
