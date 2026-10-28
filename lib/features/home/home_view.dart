import 'package:flutter/material.dart';

import '../../core/widgets/app_background.dart';
import '../../app/academic_navigation.dart' show navigateAcademic;
import 'home_view_model.dart';
import 'widgets/home_hero.dart';
import 'widgets/home_entrance.dart';
import 'widgets/home_status.dart';
import 'widgets/home_utilities.dart';
import 'widgets/home_course_panel.dart';
import 'widgets/home_calendar_card.dart';
import 'widgets/home_footer.dart';

class HomeView extends StatelessWidget {
  final HomeViewModel viewModel;
  final VoidCallback? onFeedback;
  const HomeView({super.key, required this.viewModel, this.onFeedback});
  HomeViewModel get state => viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      final ink = dark ? const Color(0xfff1f5f9) : const Color(0xff1e293b);
      final muted = dark ? const Color(0xff94a3b8) : const Color(0xff64748b);
      return Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme
              .apply(fontFamily: 'Inter', bodyColor: ink, displayColor: ink),
        ),
        child: DefaultTextStyle(
          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: ink),
          child: AppBackground(
            child: LayoutBuilder(
              builder: (context, viewport) => SingleChildScrollView(
                key: const PageStorageKey('home-scroll'),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: viewport.maxHeight),
                  child: Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            viewport.maxWidth < 600 ? 16 : 32,
                            viewport.maxWidth < 600 || viewport.maxHeight < 500
                                ? 80
                                : 64,
                            viewport.maxWidth < 600 ? 16 : 32,
                            viewport.maxWidth < 600 ? 40 : 96,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 896),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                HomeEntrance(
                                  key: const ValueKey('home-hero-entrance'),
                                  order: 0,
                                  child: HomeHero(
                                    dark: dark,
                                    muted: muted,
                                    width: viewport.maxWidth,
                                    compact:
                                        viewport.maxWidth < 600 ||
                                        viewport.maxHeight < 500,
                                  ),
                                ),
                                SizedBox(
                                  height:
                                      viewport.maxWidth < 600 ||
                                          viewport.maxHeight < 500
                                      ? 24
                                      : 48,
                                ),
                                if (state.loading)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 16),
                                    child: LinearProgressIndicator(
                                      minHeight: 2,
                                    ),
                                  ),
                                if (state.offline || state.error != null)
                                  HomeStatus(
                                    offline: state.offline,
                                    error: state.error,
                                    muted: muted,
                                    onRefresh: state.refresh,
                                  ),
                                HomeEntrance(
                                  key: const ValueKey('home-course-entrance'),
                                  order: 1,
                                  child: HomeCoursePanel(
                                    course: state.selectedCourse,
                                    courses: state.courses,
                                    loading: state.loading,
                                    muted: muted,
                                    onSelectCourse: state.selectCourse,
                                    onNavigate: (path) => navigateAcademic(
                                      context,
                                      state.context,
                                      path,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: viewport.maxWidth < 600 ? 20 : 32,
                                ),
                                HomeEntrance(
                                  key: const ValueKey('home-calendar-entrance'),
                                  order: 2,
                                  child: HomeCalendarCard(
                                    muted: muted,
                                    onNavigate: (path) => navigateAcademic(
                                      context,
                                      state.context,
                                      path,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: viewport.maxWidth < 600 ? 28 : 48,
                                ),
                                HomeEntrance(
                                  key: const ValueKey('home-footer-entrance'),
                                  order: 3,
                                  child: HomeFooter(
                                    muted: muted,
                                    onFeedback: onFeedback,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: HomeUtilities(
                          themeMode: state.themeMode,
                          onSettings: () => navigateAcademic(
                            context,
                            state.context,
                            '/configuracoes',
                          ),
                          onTheme: state.cycleTheme,
                          onAdmin: () => navigateAcademic(
                            context,
                            state.context,
                            '/admin',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
