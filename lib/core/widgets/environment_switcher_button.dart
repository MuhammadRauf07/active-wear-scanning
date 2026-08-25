import 'package:flutter/material.dart';
import 'package:active_wear_scanning/core/config/app_config.dart';

class EnvironmentSwitcherButton extends StatefulWidget {
  final VoidCallback? onEnvironmentChanged;

  const EnvironmentSwitcherButton({super.key, this.onEnvironmentChanged});

  @override
  State<EnvironmentSwitcherButton> createState() => _EnvironmentSwitcherButtonState();
}

class _EnvironmentSwitcherButtonState extends State<EnvironmentSwitcherButton> {
  void _showEnvironmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.dns_rounded, color: Color(0xFF0D47A1)),
              SizedBox(width: 8),
              Text(
                'Select Environment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppEnvironment.values.map((env) {
              final isSelected = AppConfig.currentEnvironment == env;
              final isProd = env == AppEnvironment.prod;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? (isProd ? Colors.green : Colors.amber.shade800)
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  color: isSelected
                      ? (isProd ? Colors.green.shade50 : Colors.amber.shade50)
                      : Colors.transparent,
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isSelected
                        ? (isProd ? Colors.green : Colors.amber.shade800)
                        : Colors.grey,
                  ),
                  title: Text(
                    env.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? (isProd ? Colors.green.shade900 : Colors.amber.shade900)
                          : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    env.url,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () {
                    if (!isSelected) {
                      AppConfig.setEnvironment(env);
                      setState(() {});
                      widget.onEnvironmentChanged?.call();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Switched to ${env.label} (${env.url})'),
                          backgroundColor: isProd ? Colors.green : Colors.amber.shade800,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                    Navigator.of(dialogContext).pop();
                  },
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Easily hidden in future by setting AppConfig.enableEnvironmentSwitcher = false
    if (!AppConfig.enableEnvironmentSwitcher) {
      return const SizedBox.shrink();
    }

    final current = AppConfig.currentEnvironment;
    final isProd = current == AppEnvironment.prod;

    return InkWell(
      onTap: () => _showEnvironmentDialog(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isProd ? Colors.green.shade50 : Colors.amber.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isProd ? Colors.green.shade400 : Colors.amber.shade600,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isProd ? Colors.green : Colors.amber.shade800,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              current.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isProd ? Colors.green.shade800 : Colors.amber.shade900,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: isProd ? Colors.green.shade800 : Colors.amber.shade900,
            ),
          ],
        ),
      ),
    );
  }
}
