// Presentation-only placeholder content for the Home screen — there is no
// poster/catalog backend yet, so this is static mock data rather than a
// domain entity. Replace with real data once a poster repository exists.

class HomeCollection {
  const HomeCollection({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;
}

class HomePoster {
  const HomePoster({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.condition,
    this.badgeLabel,
  });

  final String title;
  final String subtitle;
  final String price;
  final String condition;

  /// e.g. "Only 1 Left" — shown on Ending Soon items, null on All Posters.
  final String? badgeLabel;
}

const List<HomeCollection> featuredCollections = [
  HomeCollection(eyebrow: 'CURATED', title: '70s Sci-Fi Masterpieces'),
  HomeCollection(eyebrow: 'TRENDING', title: 'A24 Modern Classics'),
  HomeCollection(eyebrow: 'IMPORTED', title: 'Studio Ghibli Originals'),
];

const List<HomePoster> endingSoonPosters = [
  HomePoster(
    title: 'Blade Runner',
    subtitle: '1982 • US Original',
    price: '\$450',
    condition: 'Mint',
    badgeLabel: 'Only 1 Left',
  ),
  HomePoster(
    title: 'The Shining',
    subtitle: '1980 • UK Quad',
    price: '\$620',
    condition: 'Near Mint',
    badgeLabel: 'Only 1 Left',
  ),
  HomePoster(
    title: 'Apocalypse Now',
    subtitle: '1979 • 1 Sheet',
    price: '\$380',
    condition: 'Fine',
    badgeLabel: 'Only 1 Left',
  ),
];

const List<HomePoster> allPosters = [
  HomePoster(
    title: 'Alien',
    subtitle: '1979 • US 1 Sheet',
    price: '\$290',
    condition: 'Near Mint',
  ),
  HomePoster(
    title: 'Pulp Fiction',
    subtitle: '1994 • French Grande',
    price: '\$410',
    condition: 'Mint',
  ),
  HomePoster(
    title: 'Jaws',
    subtitle: '1975 • US Original',
    price: '\$850',
    condition: 'Very Good',
  ),
  HomePoster(
    title: 'Metropolis',
    subtitle: '1927 • Repro',
    price: '\$120',
    condition: 'Mint',
  ),
];
