import 'package:ev_tool_app/core/routing/route_names.dart';

/// Resolves the global redirect for auth-gated routes.
///
/// Returns the path to redirect to, or `null` to allow navigation through.
///
/// Gate for [RouteNames.profile]:
/// Not authenticated → send to login, preserving the intended location in
/// the `from` query param.
String? resolveProtectedAccess({
  required String location,
  required bool isAuthenticated,
}) {
  const protected = <String>{RouteNames.profile};

  if (!protected.contains(location)) {
    return null;
  }

  if (!isAuthenticated) {
    return '${RouteNames.login}?from=$location';
  }

  return null;
}
