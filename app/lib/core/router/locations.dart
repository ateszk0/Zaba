/// The four tabs of the home shell. Going to one of them replaces the stack down
/// to that tab, where pushing it would stack a second copy of the whole shell.
const tabLocations = {'/menu', '/cart', '/orders', '/profile'};

bool isTabLocation(String location) =>
    tabLocations.contains(Uri.tryParse(location)?.path);
