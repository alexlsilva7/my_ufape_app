import 'package:flutter/widgets.dart';

import '../config/dependencies.dart';
import '../core/app_state.dart';
import '../features/admin/admin_view.dart';
import '../features/admin/admin_view_model.dart';

/// Owns the screen-scoped administrative ViewModel for the route lifetime.
class AdminRoute extends StatefulWidget {
  const AdminRoute({super.key, required this.state});

  final AppState state;

  @override
  State<AdminRoute> createState() => _AdminRouteState();
}

class _AdminRouteState extends State<AdminRoute> {
  late final AdminViewModel _viewModel = createAdminViewModel(widget.state);

  @override
  Widget build(BuildContext context) => AdminView(viewModel: _viewModel);

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
}
