import 'package:flutter_test/flutter_test.dart';

import 'package:ev_tool_app/core/routing/access_guard.dart';
import 'package:ev_tool_app/core/routing/route_names.dart';

void main() {
  group('resolveProtectedAccess', () {
    test('returns null for non-protected routes (e.g. home)', () {
      // Arrange
      const location = RouteNames.home;

      // Act
      final result = resolveProtectedAccess(
        location: location,
        isAuthenticated: false,
      );

      // Assert — home is not gated even for a logged-out user
      expect(result, isNull);
    });

    test('returns null for /login to avoid redirect loops', () {
      // Arrange
      const location = RouteNames.login;

      // Act
      final result = resolveProtectedAccess(
        location: location,
        isAuthenticated: false,
      );

      // Assert
      expect(result, isNull);
    });

    test('redirects to login when unauthenticated on a protected route', () {
      // Arrange
      const location = RouteNames.profile;

      // Act
      final result = resolveProtectedAccess(
        location: location,
        isAuthenticated: false,
      );

      // Assert
      expect(result, '${RouteNames.login}?from=$location');
    });

    test('returns null when authenticated on a protected route', () {
      // Arrange
      const location = RouteNames.profile;

      // Act
      final result = resolveProtectedAccess(
        location: location,
        isAuthenticated: true,
      );

      // Assert
      expect(result, isNull);
    });
  });
}
