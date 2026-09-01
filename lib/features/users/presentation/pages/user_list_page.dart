import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agrimotion/core/theme/colors.dart';
import 'package:agrimotion/core/services/user_service.dart';
import 'package:agrimotion/features/auth/domain/user_model.dart';
import 'package:agrimotion/core/services/cache_service.dart';
import 'package:intl/intl.dart';

/// Digital cadre management page at `/admin/users`.
class UserListPage extends ConsumerStatefulWidget {
  const UserListPage({super.key});

  @override
  ConsumerState<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends ConsumerState<UserListPage> {
  String _searchQuery = '';
  String _selectedRoleFilter = 'ALL'; // 'ALL', 'ADMIN', 'KADER_DIGITAL', 'OPERATOR'
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final cacheService = ref.read(cacheServiceProvider);
    final cachedUsers = cacheService.getCacheData('users_list');
    
    if (cachedUsers != null && cachedUsers is List) {
      if (mounted) {
        setState(() {
          _users = cachedUsers.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
    }

    try {
      final users = await ref.read(userServiceProvider).getUsers();
      final jsonList = users.map((e) => e.toJson()).toList();
      await cacheService.setCacheData('users_list', jsonList);
      
      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_users.isEmpty) {
             _errorMessage = e.toString();
          }
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddUserDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => _UserFormDialog(
        onSave: (name, email, role, password) async {
          try {
            await ref.read(userServiceProvider).createUser(
              name: name,
              email: email,
              password: password,
              role: role,
            );
            _fetchUsers(); // Refresh
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Kader "$name" berhasil ditambahkan.'),
                  backgroundColor: AppColors.primaryEmerald,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Gagal menambahkan kader: $e'),
                  backgroundColor: AppColors.dangerRose,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showUnimplementedMessage(String actionName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fitur "$actionName" belum didukung oleh server.'),
        backgroundColor: AppColors.warningAmber,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: _buildBody(context, isDark),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark) {
    if (_isLoading && _users.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryEmerald),
      );
    }
    
    if (_errorMessage != null && _users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.dangerRose),
            const SizedBox(height: 16),
            Text('Gagal memuat data pengguna',
                style: TextStyle(
                    color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _fetchUsers(),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primaryEmerald),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    final int totalKader = _users.length;
    final int adminCount = _users.where((u) => u.isAdmin).length;
    final int kaderCount = _users.where((u) => u.isKaderDigital).length;
    final int operatorCount = _users.where((u) => u.isOperator).length;

    final filteredUsers = _users.where((user) {
      if (_selectedRoleFilter != 'ALL' && user.role.toUpperCase() != _selectedRoleFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = user.name.toLowerCase().contains(q);
        final matchEmail = user.email.toLowerCase().contains(q);
        return matchName || matchEmail;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, isDark),
          const SizedBox(height: 20),
          _buildStatsRow(
            context,
            isDark,
            totalKader,
            kaderCount,
            adminCount,
            operatorCount,
          ),
          const SizedBox(height: 24),
          _buildToolbar(context, isDark),
          const SizedBox(height: 16),
          _buildUserListContent(context, filteredUsers, isDark),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 600;

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.badge_rounded,
                    color: AppColors.primaryEmerald,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Manajemen Kader Digital',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Kelola akun dan hak akses kader pertanian digital serta operator telemetri.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
              ),
            ),
          ],
        );

        final addButton = FilledButton.icon(
          onPressed: _openAddUserDialog,
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          label: const Text('Tambah Kader'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryEmerald,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: addButton),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            addButton,
          ],
        );
      },
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    bool isDark,
    int totalKader,
    int kaderCount,
    int adminCount,
    int operatorCount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isWrap = width < 800;

        final stat1 = _buildStatCard(
          title: 'Total Pengguna',
          value: '$totalKader',
          subtitle: 'Semua Akun Terdaftar',
          icon: Icons.people_alt_rounded,
          color: AppColors.primaryEmerald,
          isDark: isDark,
        );

        final stat2 = _buildStatCard(
          title: 'Kader Digital',
          value: '$kaderCount',
          subtitle: 'Pendamping Petani',
          icon: Icons.school_rounded,
          color: const Color(0xFF0284C7),
          isDark: isDark,
        );

        final stat3 = _buildStatCard(
          title: 'Administrator',
          value: '$adminCount',
          subtitle: 'Akses Penuh Manajemen',
          icon: Icons.admin_panel_settings_rounded,
          color: const Color(0xFF7C3AED),
          isDark: isDark,
        );

        final stat4 = _buildStatCard(
          title: 'Operator',
          value: '$operatorCount',
          subtitle: 'Irigasi & Sensor',
          icon: Icons.build_circle_rounded,
          color: const Color(0xFFD97706),
          isDark: isDark,
        );

        if (isWrap) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: stat1),
                  const SizedBox(width: 12),
                  Expanded(child: stat2),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: stat3),
                  const SizedBox(width: 12),
                  Expanded(child: stat4),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: stat1),
            const SizedBox(width: 14),
            Expanded(child: stat2),
            const SizedBox(width: 14),
            Expanded(child: stat3),
            const SizedBox(width: 14),
            Expanded(child: stat4),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textDarkSecondary.withValues(alpha: 0.7) : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 600;

        final searchField = TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Cari nama, email, atau no. telp...',
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textDarkSecondary : AppColors.textTertiary,
            ),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            filled: true,
            fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.primaryEmerald,
                width: 1.5,
              ),
            ),
          ),
        );

        final roleDropdown = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedRoleFilter,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
              ),
              dropdownColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('Semua Role')),
                DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                DropdownMenuItem(value: 'KADER_DIGITAL', child: Text('Kader Digital')),
                DropdownMenuItem(value: 'OPERATOR', child: Text('Operator')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedRoleFilter = val);
              },
            ),
          ),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 10),
              roleDropdown,
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 2, child: searchField),
            const SizedBox(width: 12),
            Expanded(flex: 1, child: roleDropdown),
          ],
        );
      },
    );
  }

  Widget _buildUserListContent(
    BuildContext context,
    List<UserModel> filteredUsers,
    bool isDark,
  ) {
    if (filteredUsers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 48,
              color: isDark ? AppColors.textDarkSecondary : AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'Tidak Ada Kader Ditemukan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Coba sesuaikan kata kunci pencarian atau reset filter role.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedRoleFilter = 'ALL';
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset Pencarian'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 950;

        if (isDesktop) {
          return _buildDesktopDataTable(filteredUsers, isDark);
        } else {
          return _buildMobileCardList(filteredUsers, isDark);
        }
      },
    );
  }

  Widget _buildDesktopDataTable(List<UserModel> users, bool isDark) {
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 950),
          child: DataTable(
            horizontalMargin: 20,
            columnSpacing: 24,
            headingRowColor: WidgetStateProperty.all(
              isDark ? AppColors.elevatedDark.withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
            ),
            headingTextStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
            columns: const [
              DataColumn(label: Text('NAMA LENGKAP')),
              DataColumn(label: Text('EMAIL')),
              DataColumn(label: Text('ROLE')),
              DataColumn(label: Text('TGL. REGISTRASI')),
              DataColumn(label: Text('AKSI')),
            ],
            rows: users.map((user) {
              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      children: [
                        _buildUserAvatar(user),
                        const SizedBox(width: 12),
                        Text(
                          user.name,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  DataCell(_buildRoleBadge(user.role)),
                  DataCell(
                    Text(
                      dateFormat.format(user.createdAt),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit Profil Kader',
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          color: AppColors.primaryEmerald,
                          onPressed: () => _showUnimplementedMessage('Edit Kader'),
                        ),
                        IconButton(
                          tooltip: 'Reset Kata Sandi',
                          icon: const Icon(Icons.lock_reset_rounded, size: 18),
                          color: AppColors.infoBlue,
                          onPressed: () => _showUnimplementedMessage('Reset Sandi'),
                        ),
                        IconButton(
                          tooltip: 'Nonaktifkan Akun',
                          icon: const Icon(Icons.block_rounded, size: 18),
                          color: AppColors.dangerRose,
                          onPressed: () => _showUnimplementedMessage('Nonaktifkan Akun'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCardList(List<UserModel> users, bool isDark) {
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = users[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserAvatar(user),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.elevatedDark.withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildMobileDetailRow(Icons.email_outlined, 'Email', user.email, isDark),
                    const SizedBox(height: 6),
                    _buildMobileDetailRow(
                        Icons.calendar_today_outlined,
                        'Registrasi',
                        dateFormat.format(user.createdAt),
                        isDark),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildRoleBadge(user.role),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: AppColors.primaryEmerald,
                        onPressed: () => _showUnimplementedMessage('Edit Kader'),
                      ),
                      IconButton(
                        tooltip: 'Hapus',
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: AppColors.dangerRose,
                        onPressed: () => _showUnimplementedMessage('Hapus Akun'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileDetailRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark ? AppColors.textDarkSecondary : AppColors.textTertiary,
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserAvatar(UserModel user) {
    final String initial = user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : 'U';

    Color avatarColor = AppColors.secondary;
    if (user.isAdmin) {
      avatarColor = const Color(0xFF7C3AED);
    } else if (user.isOperator) {
      avatarColor = AppColors.warningAmber;
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: avatarColor.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: TextStyle(
          color: avatarColor,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    String label;
    IconData icon;

    switch (role.toUpperCase()) {
      case UserModel.roleAdmin:
        badgeColor = const Color(0xFF7C3AED); // Purple
        label = 'ADMIN';
        icon = Icons.admin_panel_settings_rounded;
        break;
      case UserModel.roleKaderDigital:
        badgeColor = const Color(0xFF0284C7); // Blue
        label = 'KADER DIGITAL';
        icon = Icons.school_rounded;
        break;
      case UserModel.roleOperator:
        badgeColor = const Color(0xFFD97706); // Amber
        label = 'OPERATOR';
        icon = Icons.build_circle_rounded;
        break;
      default:
        badgeColor = AppColors.textSecondary;
        label = role.toUpperCase();
        icon = Icons.person_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  final Future<void> Function(
      String name, String email, String role, String password) onSave;

  const _UserFormDialog({required this.onSave});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  String _selectedRole = UserModel.roleKaderDigital;
  bool _obscurePassword = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await widget.onSave(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _selectedRole,
        _passwordController.text,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryEmerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: AppColors.primaryEmerald,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Tambah Kader Digital Baru',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Nama Lengkap
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap *',
                    hintText: 'Contoh: I Putu Widya Artana',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama lengkap wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Email *',
                    hintText: 'nama@agrimotion.id',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Alamat email wajib diisi';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Masukkan format email yang valid';
                    }
                    return null;
                  },
                ),


                // Role Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Peran / Role *',
                    prefixIcon: Icon(Icons.security_rounded, size: 20),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: UserModel.roleKaderDigital,
                      child: Text('Kader Digital (Pendamping Petani)'),
                    ),
                    DropdownMenuItem(
                      value: UserModel.roleOperator,
                      child: Text('Operator (Irigasi & Sensor Lapangan)'),
                    ),
                    DropdownMenuItem(
                      value: UserModel.roleAdmin,
                      child: Text('Administrator (Akses Sistem Penuh)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRole = val);
                  },
                ),
                const SizedBox(height: 14),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Kata Sandi Awal *',
                    hintText: 'Minimal 8 karakter',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Kata sandi minimal 6 karakter';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _submitForm,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryEmerald,
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded, size: 16),
          label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Data'),
        ),
      ],
    );
  }
}
