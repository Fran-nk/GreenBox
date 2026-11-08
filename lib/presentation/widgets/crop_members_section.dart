import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/models/device_member.dart';
import '../../domain/repositories/greenbox_repository.dart';

/// Small card listing who can see the selected crop: its administrator (the
/// person who registered it) and its guests. The administrator can remove
/// guests. Give it a key per device so it reloads when the crop changes.
class CropMembersSection extends StatefulWidget {
  final GreenBoxRepository repository;
  final String deviceId;

  const CropMembersSection({
    super.key,
    required this.repository,
    required this.deviceId,
  });

  @override
  State<CropMembersSection> createState() => _CropMembersSectionState();
}

class _CropMembersSectionState extends State<CropMembersSection> {
  List<DeviceMember>? _members;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final members = await widget.repository.getDeviceMembers(widget.deviceId);
      if (mounted) setState(() => _members = members);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  bool get _iAmOwner => _members?.any((m) => m.isOwner && m.isMe) ?? false;

  Future<void> _remove(DeviceMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Quitar invitado?'),
        content: Text('${member.email} dejará de ver este cultivo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('QUITAR', style: TextStyle(color: AppColors.alertRed)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.repository.removeDeviceMember(widget.deviceId, member.userId);
      if (mounted) setState(() => _members = _members!.where((m) => m.userId != member.userId).toList());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _members;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group_outlined, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text('Administradores', style: AppTextStyles.chartFilter.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          if (_failed)
            Text('No se pudieron cargar los miembros.', style: AppTextStyles.chartLabel)
          else if (members == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            )
          else ...[
            for (final m in members) _buildRow(m),
            const SizedBox(height: 4),
            Text(
              'Para compartir este cultivo, la otra persona debe configurar este mismo GreenBox desde su cuenta.',
              style: AppTextStyles.chartLabel,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(DeviceMember m) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: Text(
              m.isMe ? '${m.email} (tú)' : m.email,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.chartFilter.copyWith(color: AppColors.textPrimary),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: m.isOwner ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(m.isOwner ? 'Administrador' : 'Invitado', style: AppTextStyles.chartLabel),
          ),
          if (_iAmOwner && !m.isOwner)
            IconButton(
              tooltip: 'Quitar',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
              onPressed: () => _remove(m),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}
