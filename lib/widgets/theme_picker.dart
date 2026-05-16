import 'package:flutter/material.dart';

import '../services/theme_service.dart';

class ThemePickerButton extends StatelessWidget {
  const ThemePickerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeChoice>(
      valueListenable: ThemeService.selectedTheme,
      builder: (context, selected, _) {
        return PopupMenuButton<AppThemeChoice>(
          tooltip: "Choose theme",
          icon: Icon(ThemeService.icon(selected)),
          onSelected: (choice) {
            ThemeService.selectedTheme.value = choice;
          },
          itemBuilder: (context) {
            return AppThemeChoice.values.map((choice) {
              return PopupMenuItem<AppThemeChoice>(
                value: choice,
                child: Row(
                  children: [
                    Icon(ThemeService.icon(choice), size: 20),
                    const SizedBox(width: 10),
                    Text(ThemeService.label(choice)),
                    if (choice == selected) ...[
                      const Spacer(),
                      const Icon(Icons.check, size: 18),
                    ],
                  ],
                ),
              );
            }).toList();
          },
        );
      },
    );
  }
}
