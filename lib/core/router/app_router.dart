import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/preview/presentation/preview_screen.dart';
import '../../features/record/presentation/record_screen.dart';

/// App routes:
///   /              dashboard
///   /record        record audio
///   /preview/:id   clean + before/after preview + export
final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/record',
      builder: (context, state) => const RecordScreen(),
    ),
    GoRoute(
      path: '/preview/:id',
      builder: (context, state) =>
          PreviewScreen(recordingId: state.pathParameters['id']!),
    ),
  ],
);
