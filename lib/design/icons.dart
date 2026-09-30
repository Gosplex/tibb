// Tibb's icon vocabulary (design system §2.6). One meaning per icon.
// Material Symbols (rounded), built into Flutter. Replaces phosphor_flutter,
// which no longer compiles on current Flutter (IconData is now a final class).
import 'package:flutter/material.dart';

abstract final class TibbIcons {
  static const IconData box = Icons.inventory_2_outlined;
  static const IconData lock = Icons.lock_outline_rounded;
  static const IconData lockFill = Icons.lock_rounded;
  static const IconData lockOpen = Icons.lock_open_rounded;
  static const IconData bridge = Icons.laptop_rounded;
  static const IconData bridgeFill = Icons.laptop_chromebook_rounded;
  static const IconData clipboard = Icons.content_paste_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData archive = Icons.inbox_outlined;
  static const IconData archiveAction = Icons.archive_outlined;
  static const IconData unarchive = Icons.unarchive_outlined;
  static const IconData pin = Icons.push_pin_outlined;
  static const IconData pinFill = Icons.push_pin_rounded;
  static const IconData note = Icons.edit_note_rounded;
  static const IconData mic = Icons.mic_none_rounded;
  static const IconData micFill = Icons.mic_rounded;
  static const IconData attach = Icons.attach_file_rounded;
  static const IconData exportIcon = Icons.ios_share_rounded;
  static const IconData importIcon = Icons.download_rounded;
  static const IconData fromComputer = Icons.desktop_windows_outlined;
  static const IconData pro = Icons.auto_awesome_rounded;
  static const IconData caretDown = Icons.keyboard_arrow_down_rounded;
  static const IconData caretRight = Icons.chevron_right_rounded;
  static const IconData send = Icons.arrow_upward_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData checkCircle = Icons.check_circle_rounded;
  static const IconData warning = Icons.error_outline_rounded;
  static const IconData info = Icons.info_outline_rounded;
  static const IconData eye = Icons.visibility_outlined;
  static const IconData eyeOff = Icons.visibility_off_outlined;
  static const IconData file = Icons.insert_drive_file_outlined;
  static const IconData filePdf = Icons.picture_as_pdf_outlined;
  static const IconData fileZip = Icons.folder_zip_outlined;
  static const IconData fileAudio = Icons.audio_file_outlined;
  static const IconData link = Icons.link_rounded;
  static const IconData image = Icons.image_outlined;
  static const IconData camera = Icons.photo_camera_outlined;
  static const IconData play = Icons.play_arrow_rounded;
  static const IconData pause = Icons.pause_rounded;
  static const IconData more = Icons.more_horiz_rounded;
  static const IconData trash = Icons.delete_outline_rounded;
  static const IconData copy = Icons.content_copy_rounded;
  static const IconData share = Icons.share_rounded;
  static const IconData settings = Icons.settings_outlined;
  static const IconData plus = Icons.add_rounded;
  static const IconData wifi = Icons.wifi_rounded;
  static const IconData edit = Icons.edit_outlined;
  static const IconData shield = Icons.verified_user_outlined;
  static const IconData chat = Icons.chat_bubble_outline_rounded;
  static const IconData palette = Icons.palette_outlined;
  static const IconData key = Icons.key_rounded;
}