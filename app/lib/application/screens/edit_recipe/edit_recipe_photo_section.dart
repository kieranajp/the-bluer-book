import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/edit_recipe_provider.dart';
import '../../widgets/striped_placeholder.dart';
import '../../styles/text_styles.dart';
import '../../styles/spacing.dart';

class EditRecipePhotoSection extends StatelessWidget {
  final EditRecipeState editState;
  final EditRecipeNotifier notifier;

  const EditRecipePhotoSection({
    super.key,
    required this.editState,
    required this.notifier,
  });

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    notifier.setPhoto(bytes, picked.name);
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = editState.pendingPhotoBytes != null || (editState.imageUrl != null && editState.imageUrl!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photo', style: TextStyles.sectionHeading(context)),
        const SizedBox(height: Spacing.s),
        GestureDetector(
          onTap: _pickImage,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (editState.pendingPhotoBytes != null)
                    Image.memory(
                      editState.pendingPhotoBytes!,
                      fit: BoxFit.cover,
                    )
                  else if (editState.imageUrl != null && editState.imageUrl!.isNotEmpty)
                    Image.network(
                      editState.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const StripedPlaceholder(
                        icon: Icons.broken_image_outlined,
                      ),
                    )
                  else
                    StripedPlaceholder(
                      icon: Icons.add_a_photo_outlined,
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: Spacing.xs,
                        horizontal: Spacing.s,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            hasImage ? Icons.edit : Icons.add_a_photo_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasImage ? 'Change photo' : 'Add photo',
                            style: TextStyles.caption(context)
                                .copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (hasImage)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: notifier.removePhoto,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
